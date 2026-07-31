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

const patientContextSchema = z.object({
  sex: z.string().optional().default(''),
  age: z.string().optional().default(''),
  weightKg: z.string().optional().default(''),
  currentSymptoms: z.string().optional().default(''),
  allergyHistory: z.string().optional().default(''),
  specialStatus: z.string().optional().default('')
}).default({});

const chatSchema = z.object({
  question: z.string().min(1).max(1000),
  documentId: z.number().int().positive(),
  medicineName: z.string().optional().default(''),
  patientContext: patientContextSchema,
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
    const selectedChunks = selectKnowledgeChunks(allChunks, input.question, input.patientContext, input.limit);

    const contextText = selectedChunks
      .map((chunk) => {
        const sectionLabel = chunk.section_title || chunk.section_type || '';
        return `Page ${chunk.page_number ?? 'unknown'}${sectionLabel ? `, section ${sectionLabel}` : ''}:\n${chunk.chunk_text}`;
      })
      .join('\n\n---\n\n');
    const dosageFacts = extractDosageFacts(selectedChunks);
    const answer = await askDeepSeekWithKnowledgeBase({
      question: input.question,
      medicineName: input.medicineName || document.medicine_name,
      contextText,
      dosageFacts,
      patientContext: input.patientContext
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

function selectKnowledgeChunks(allChunks, question, patientContext, limit) {
  const selected = [];
  const prioritySections = [
    'how_to_take',
    'before_use',
    'side_effects',
    'storage',
    'contents',
    'what_is_it'
  ];

  for (const sectionType of prioritySections) {
    for (const chunk of allChunks) {
      if (chunk.section_type === sectionType && !selected.includes(chunk)) {
        selected.push(chunk);
      }
    }
  }

  for (const chunk of allChunks) {
    if ((chunk.section_type === null || chunk.section_type === undefined) && !selected.includes(chunk)) {
      selected.push(chunk);
    }
  }

  for (const chunk of allChunks) {
    if (selected.includes(chunk)) {
      continue;
    }
    selected.push(chunk);
  }

  return fitChunksToContext(selected, 18000);
}

function extractDosageFacts(chunks) {
  const howToTakeText = chunks
    .filter((chunk) => chunk.section_type === 'how_to_take')
    .map((chunk) => chunk.chunk_text)
    .join(' ')
    .replace(/\s+/g, ' ')
    .trim();

  if (howToTakeText.length === 0) {
    return '';
  }

  const facts = [];
  const recommendedDose = firstMatch(howToTakeText, [
    /(\d+\s*(?:do|-|–)?\s*\d*\s*(?:kapsułki|kapsułek|tabletki|tabletek|tablet|capsules?|drops?|ml)(?:\s*\([^)]*\))?)/i,
    /(?:recommended dose|dose)[^.:;]*[:.]?\s*([^.;]{0,120}(?:capsules?|tablets?|drops?|ml)[^.;]{0,120})/i
  ]);
  const frequency = firstMatch(howToTakeText, [
    /(\d+\s*(?:do|-|–)?\s*\d+\s*razy\s+na\s+dobę)/i,
    /(\d+\s*(?:to|-|–)?\s*\d+\s*times\s+(?:a|per)\s+day)/i,
    /(every\s+\d+\s*(?:-|–|to)?\s*\d*\s*hours?)/i
  ]);
  const timing = firstMatch(howToTakeText, [
    /(bezpośrednio przed,\s*w trakcie lub po posiłkach[^.]*\.?)/i,
    /(before,\s*during,?\s*or after meals[^.]*\.?)/i,
    /(with meals[^.]*\.?)/i,
    /(after meals[^.]*\.?)/i,
    /(before meals[^.]*\.?)/i
  ]);
  const duration = firstMatch(howToTakeText, [
    /(należy przyjmować tak długo jak występują dolegliwości[^.]*\.?)/i,
    /(take[^.]{0,80}as long as symptoms[^.]*\.?)/i
  ]);

  pushFact(facts, 'Dose per intake', recommendedDose);
  pushFact(facts, 'Frequency', frequency);
  pushFact(facts, 'Timing', timing);
  pushFact(facts, 'Duration', duration);

  const sourcePassage = extractDosageSourcePassage(howToTakeText);
  if (sourcePassage.length > 0) {
    facts.push(`Source dosage passage: ${sourcePassage}`);
  }

  return facts.join('\n');
}

function firstMatch(text, patterns) {
  for (const pattern of patterns) {
    const match = text.match(pattern);
    if (match?.[1]) {
      return match[1].trim();
    }
  }
  return '';
}

function pushFact(facts, label, value) {
  if (value.length > 0) {
    facts.push(`${label}: ${formatExtractedFactValue(value)}`);
  } else {
    facts.push(`${label}: Not found in the provided leaflet context`);
  }
}

function formatExtractedFactValue(value) {
  const translated = value
    .replace(/kapsułki|kapsułek/gi, 'capsules')
    .replace(/tabletki|tabletek/gi, 'tablets')
    .replace(/co odpowiada/gi, 'equivalent to')
    .replace(/symetykonu/gi, 'simethicone')
    .replace(/razy na dobę/gi, 'times daily')
    .replace(/(\d+)\s+do\s+(\d+)\s+times daily/gi, '$1 to $2 times daily')
    .replace(/bezpośrednio przed,\s*w trakcie lub po posiłkach/gi, 'immediately before, during, or after meals')
    .replace(/w razie konieczności,\s*również przed snem/gi, 'if needed, also before bedtime')
    .replace(/należy przyjmować tak długo jak występują dolegliwości/gi, 'take as long as symptoms persist');

  return translated === value ? value : `${value} [English: ${translated}]`;
}

function extractDosageSourcePassage(text) {
  const startSignals = ['Dawkowanie', 'Recommended dose', 'Zalecana dawka'];
  const endSignals = ['Sposób podawania', 'Method of administration', 'Zastosowanie większej', 'Pominięcie'];
  let start = -1;
  for (const signal of startSignals) {
    const index = text.toLowerCase().indexOf(signal.toLowerCase());
    if (index >= 0 && (start < 0 || index < start)) {
      start = index;
    }
  }
  if (start < 0) {
    start = 0;
  }

  let end = -1;
  for (const signal of endSignals) {
    const index = text.toLowerCase().indexOf(signal.toLowerCase(), start + 20);
    if (index > start && (end < 0 || index < end)) {
      end = index;
    }
  }
  const passage = text.slice(start, end > start ? end : Math.min(text.length, start + 900)).trim();
  return passage.length > 900 ? passage.slice(0, 900) : passage;
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



