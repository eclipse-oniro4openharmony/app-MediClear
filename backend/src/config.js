export const config = {
  host: process.env.HOST ?? '0.0.0.0',
  port: Number.parseInt(process.env.PORT ?? '8080', 10),
  mongoUrl: process.env.MONGO_URL ?? 'mongodb://localhost:27017',
  mongoDbName: process.env.MONGO_DB_NAME ?? 'mediclear',
  pdfTextMinLength: Number.parseInt(process.env.PDF_TEXT_MIN_LENGTH ?? '300', 10),
  chunkSize: Number.parseInt(process.env.CHUNK_SIZE ?? '1200', 10),
  chunkOverlap: Number.parseInt(process.env.CHUNK_OVERLAP ?? '160', 10),
  deepseekApiKey: process.env.DEEPSEEK_API_KEY ?? '',
  deepseekBaseUrl: process.env.DEEPSEEK_BASE_URL ?? 'https://api.deepseek.com',
  deepseekModel: process.env.DEEPSEEK_MODEL ?? 'deepseek-chat'
};
