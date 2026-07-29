import { MongoClient } from 'mongodb';
import { config } from './config.js';

let client;
let database;

function documents() {
  return database.collection('documents');
}

function chunks() {
  return database.collection('document_chunks');
}

function counters() {
  return database.collection('counters');
}

export async function initializeDatabase() {
  client = new MongoClient(config.mongoUrl);
  await client.connect();
  database = client.db(config.mongoDbName);

  await documents().createIndex({ sourceUrl: 1, sourceHash: 1 }, { unique: true });
  await documents().createIndex({ productId: 1, updatedAt: -1 });
  await documents().createIndex({ id: 1 }, { unique: true });

  await chunks().createIndex({ documentId: 1, chunkIndex: 1 }, { unique: true });
  await chunks().createIndex({
    chunkText: 'text',
    sectionTitle: 'text'
  }, {
    default_language: 'none',
    name: 'chunk_text_index'
  });
}

export async function closeDatabase() {
  if (client) {
    await client.close();
  }
}

async function nextSequence(name) {
  const result = await counters().findOneAndUpdate(
    { _id: name },
    { $inc: { seq: 1 } },
    { upsert: true, returnDocument: 'after' }
  );

  if (result && typeof result.seq === 'number') {
    return result.seq;
  }
  if (result?.value && typeof result.value.seq === 'number') {
    return result.value.seq;
  }
  throw new Error(`Could not allocate sequence: ${name}`);
}

function toApiDocument(document) {
  if (!document) {
    return null;
  }

  return {
    id: document.id,
    product_id: document.productId ?? '',
    medicine_name: document.medicineName ?? '',
    document_type: document.documentType,
    source_url: document.sourceUrl,
    source_hash: document.sourceHash,
    source_size: document.sourceSize,
    extraction_method: document.extractionMethod,
    status: document.status,
    text_length: document.textLength,
    preview: document.preview,
    error_message: document.errorMessage ?? null,
    created_at: document.createdAt?.toISOString?.() ?? '',
    updated_at: document.updatedAt?.toISOString?.() ?? ''
  };
}

function toApiChunk(chunk) {
  return {
    id: chunk.id,
    document_id: chunk.documentId,
    chunk_index: chunk.chunkIndex,
    page_number: chunk.pageNumber ?? null,
    section_type: chunk.sectionType ?? null,
    section_title: chunk.sectionTitle ?? null,
    chunk_text: chunk.chunkText,
    rank: chunk.score ?? null,
    created_at: chunk.createdAt?.toISOString?.() ?? ''
  };
}

export async function upsertDocumentWithChunks(document, documentChunks) {
  const now = new Date();
  const existing = await documents().findOne({
    sourceUrl: document.sourceUrl,
    sourceHash: document.sourceHash
  });

  const documentId = existing?.id ?? await nextSequence('documents');
  const documentRecord = {
    id: documentId,
    productId: document.productId,
    medicineName: document.medicineName,
    documentType: document.documentType,
    sourceUrl: document.sourceUrl,
    sourceHash: document.sourceHash,
    sourceSize: document.sourceSize,
    extractionMethod: document.extractionMethod,
    status: document.status,
    textLength: document.textLength,
    preview: document.preview,
    errorMessage: document.errorMessage,
    createdAt: existing?.createdAt ?? now,
    updatedAt: now
  };

  await documents().updateOne(
    { id: documentId },
    { $set: documentRecord },
    { upsert: true }
  );

  await chunks().deleteMany({ documentId });
  if (documentChunks.length > 0) {
    await chunks().insertMany(documentChunks.map((chunk) => ({
      id: `${documentId}:${chunk.chunkIndex}`,
      documentId,
      chunkIndex: chunk.chunkIndex,
      pageNumber: chunk.pageNumber ?? null,
      sectionType: chunk.sectionType ?? null,
      sectionTitle: chunk.sectionTitle ?? null,
      chunkText: chunk.chunkText,
      createdAt: now
    })));
  }

  return toApiDocument(await documents().findOne({ id: documentId }));
}

export async function getDocument(id) {
  return toApiDocument(await documents().findOne({ id }));
}

export async function getLatestDocumentByProductId(productId) {
  return toApiDocument(await documents()
    .find({ productId })
    .sort({ updatedAt: -1 })
    .limit(1)
    .next());
}

export async function getChunks(documentId) {
  const results = await chunks()
    .find({ documentId })
    .sort({ chunkIndex: 1 })
    .toArray();
  return results.map(toApiChunk);
}

export async function searchChunks(query, documentId, limit) {
  const filter = {
    $text: {
      $search: query
    }
  };

  if (documentId) {
    filter.documentId = documentId;
  }

  const results = await chunks()
    .find(filter, {
      projection: {
        score: { $meta: 'textScore' }
      }
    })
    .sort({ score: { $meta: 'textScore' }, documentId: -1, chunkIndex: 1 })
    .limit(limit)
    .toArray();

  return results.map(toApiChunk);
}
