import express from 'express';
import { z } from 'zod';
import { config } from './config.js';
import {
  closeDatabase,
  getChunks,
  getDocument,
  getLatestDocumentByProductId,
  initializeDatabase,
  searchChunks,
  upsertDocumentWithChunks
} from './database.js';
import { askDeepSeekWithKnowledgeBase } from './deepseekClient.js';
import { extractPdfText, downloadPdf, sha256, splitIntoChunks } from './pdfTextExtractor.js';

const app = express();
app.use(express.json({ limit: '1mb' }));
app.use((request, response, next) => {
  const startedAt = Date.now();
  console.log(`[http] ${request.method} ${request.originalUrl} start`);
  response.on('finish', () => {
    console.log(`[http] ${request.method} ${request.originalUrl} ${response.statusCode} ${Date.now() - startedAt}ms`);
  });
  response.on('close', () => {
    if (!response.writableEnded) {
      console.warn(`[http] ${request.method} ${request.originalUrl} closed before response after ${Date.now() - startedAt}ms`);
    }
  });
  next();
});

const extractUrlSchema = z.object({
  url: z.string().url(),
  productId: z.string().optional(),
  medicineName: z.string().optional(),
  documentType: z.string().min(1).default('leaflet'),
  forceOcr: z.boolean().optional().default(false)
});

const rplSchema = z.object({
  productId: z.union([z.string(), z.number()]).transform((value) => String(value)),
  medicineName: z.string().optional(),
  documentType: z.enum(['leaflet', 'characteristic']).default('leaflet'),
  forceOcr: z.boolean().optional().default(false)
});

const searchSchema = z.object({
  query: z.string().min(1),
  documentId: z.number().int().positive().optional(),
  limit: z.number().int().positive().max(50).default(8)
});

const chatSchema = z.object({
  question: z.string().min(1).max(1000),
  documentId: z.number().int().positive(),
  medicineName: z.string().optional().default(''),
  limit: z.number().int().positive().max(12).default(6)
});

app.get('/health', (_request, response) => {
  response.json({
    ok: true,
    service: 'mediclear-backend'
  });
});

app.post('/api/debug/echo', (request, response) => {
  response.json({
    ok: true,
    body: request.body
  });
});

app.post('/api/documents/rpl', async (request, response, next) => {
  try {
    const input = rplSchema.parse(request.body);
    const document = await extractRplDocumentWithFallback(input);
    response.json(document);
  } catch (error) {
    next(error);
  }
});

app.post('/api/documents/extract-url', async (request, response, next) => {
  try {
    const input = extractUrlSchema.parse(request.body);
    const document = await extractAndStore(input);
    response.json(document);
  } catch (error) {
    next(error);
  }
});

app.get('/api/documents/by-product/:productId', async (request, response, next) => {
  try {
    const document = await getLatestDocumentByProductId(request.params.productId);
    if (!document) {
      response.status(404).json({ error: 'Document not found' });
      return;
    }

    response.json(document);
  } catch (error) {
    next(error);
  }
});

app.get('/api/documents/:id/chunks', async (request, response, next) => {
  try {
    const documentId = Number.parseInt(request.params.id, 10);
    response.json({
      documentId,
      chunks: await getChunks(documentId)
    });
  } catch (error) {
    next(error);
  }
});

app.get('/api/documents/:id', async (request, response, next) => {
  try {
    const document = await getDocument(Number.parseInt(request.params.id, 10));
    if (!document) {
      response.status(404).json({ error: 'Document not found' });
      return;
    }

    response.json(document);
  } catch (error) {
    next(error);
  }
});

app.post('/api/search', async (request, response, next) => {
  try {
    const input = searchSchema.parse(request.body);
    response.json({
      results: await searchChunks(input.query, input.documentId, input.limit)
    });
  } catch (error) {
    next(error);
  }
});

app.post('/api/chat', async (request, response, next) => {
  try {
    const input = chatSchema.parse(request.body);
    const document = await getDocument(input.documentId);
    if (!document) {
      response.status(404).json({ error: 'Knowledge base document not found' });
      return;
    }

    const allChunks = await getChunks(input.documentId);
    const selectedChunks = selectKnowledgeChunks(allChunks, input.question, input.limit);

    const contextText = selectedChunks
      .map((chunk) => {
        const sectionLabel = chunk.section_title || chunk.section_type || '';
        return `Page ${chunk.page_number ?? 'unknown'}${sectionLabel ? `, section ${sectionLabel}` : ''}:\n${chunk.chunk_text}`;
      })
      .join('\n\n---\n\n');

    const answer = await askDeepSeekWithKnowledgeBase({
      question: input.question,
      medicineName: input.medicineName || document.medicine_name,
      contextText
    });

    response.json({
      answer,
      documentId: input.documentId,
      medicineName: input.medicineName || document.medicine_name,
      citations: selectedChunks.map((chunk) => ({
        chunkIndex: chunk.chunk_index,
        pageNumber: chunk.page_number,
        sectionType: chunk.section_type,
        sectionTitle: chunk.section_title
      }))
    });
  } catch (error) {
    next(error);
  }
});

function selectKnowledgeChunks(allChunks, question, limit) {
  const intent = classifyMedicineQuestion(question);
  if (intent) {
    const sectionChunks = allChunks.filter((chunk) => chunk.section_type === intent);
    if (sectionChunks.length > 0) {
      return fitChunksToContext(sectionChunks, 18000);
    }
  }

  return fitChunksToContext(allChunks, 18000);
}

function classifyMedicineQuestion(question) {
  const lower = question.toLowerCase();
  if (lower.includes('take') || lower.includes('dose') || lower.includes('dosage') || lower.includes('how should') ||
    lower.includes('用法') || lower.includes('剂量') || lower.includes('怎么吃')) {
    return 'how_to_take';
  }

  if (lower.includes('side effect') || lower.includes('adverse') || lower.includes('reaction') ||
    lower.includes('副作用') || lower.includes('不良反应')) {
    return 'side_effects';
  }

  if (lower.includes('allerg') || lower.includes('contraindication') || lower.includes('warning') ||
    lower.includes('avoid') || lower.includes('禁忌') || lower.includes('过敏') || lower.includes('注意')) {
    return 'before_use';
  }

  if (lower.includes('store') || lower.includes('storage') || lower.includes('expire') ||
    lower.includes('保存') || lower.includes('储存') || lower.includes('过期')) {
    return 'storage';
  }

  return null;
}

function fitChunksToContext(chunks, maxCharacters) {
  const selected = [];
  let total = 0;
  for (const chunk of chunks) {
    const length = chunk.chunk_text.length;
    if (selected.length > 0 && total + length > maxCharacters) {
      break;
    }
    selected.push(chunk);
    total += length;
  }
  return selected;
}

async function extractAndStore(input) {
  console.log(`[extract] start documentType=${input.documentType ?? 'leaflet'} productId=${input.productId ?? ''} url=${input.url}`);
  const pdfBuffer = await downloadPdf(input.url);
  console.log(`[extract] downloaded bytes=${pdfBuffer.length}`);
  const sourceHash = sha256(pdfBuffer);

  const extracted = await extractPdfText(pdfBuffer);
  console.log(`[extract] extracted method=${extracted.method} pages=${extracted.pages.length} textLength=${extracted.text.length}`);

  const chunks = splitIntoChunks(extracted.pages);
  console.log(`[extract] split chunks=${chunks.length}`);
  const status = extracted.text.length >= config.pdfTextMinLength ? 'ready' : 'text_too_short';

  const document = await upsertDocumentWithChunks({
    productId: input.productId ?? null,
    medicineName: input.medicineName ?? null,
    documentType: input.documentType ?? 'leaflet',
    sourceUrl: input.url,
    sourceHash,
    sourceSize: pdfBuffer.length,
    extractionMethod: extracted.method,
    status,
    textLength: extracted.text.length,
    preview: extracted.text.slice(0, 600),
    errorMessage: null
  }, chunks);
  console.log(`[extract] stored documentId=${document.id} status=${document.status}`);
  return document;
}

async function extractRplDocumentWithFallback(input) {
  const preferredTypes = input.documentType === 'characteristic'
    ? ['characteristic', 'leaflet']
    : ['leaflet', 'characteristic'];
  const errors = [];

  for (const documentType of preferredTypes) {
    const url = `https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/${input.productId}/${documentType}`;
    try {
      return await extractAndStore({
        url,
        productId: input.productId,
        medicineName: input.medicineName,
        documentType,
        forceOcr: input.forceOcr
      });
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      errors.push(`${documentType}: ${message}`);
      if (!message.includes('HTTP 404')) {
        throw error;
      }
      console.warn(`[extract] ${documentType} unavailable for productId=${input.productId}; trying fallback`);
    }
  }

  const notFound = new Error(`No RPL PDF document is available for productId=${input.productId}. ${errors.join(' | ')}`);
  notFound.statusCode = 404;
  throw notFound;
}

app.use((error, _request, response, _next) => {
  console.error('[error]', error);
  if (error instanceof z.ZodError) {
    response.status(400).json({
      error: 'Invalid request',
      details: error.errors
    });
    return;
  }

  response.status(error.statusCode ?? 500).json({
    error: error instanceof Error ? error.message : 'Unknown server error'
  });
});

await initializeDatabase();

const server = app.listen(config.port, config.host, () => {
  console.log(`MediClear backend listening on http://${config.host}:${config.port}`);
});

async function shutdown() {
  server.close();
  await closeDatabase();
  process.exit(0);
}

process.on('SIGINT', () => {
  void shutdown();
});

process.on('SIGTERM', () => {
  void shutdown();
});
