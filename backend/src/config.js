function env(name) {
  const value = process.env[name];
  return value && value.trim().length > 0 ? value : undefined;
}

export const config = {
  host: env('HOST') ?? '0.0.0.0',
  port: Number.parseInt(env('PORT') ?? '8080', 10),
  mongoUrl: env('MONGO_URL') ?? 'mongodb://localhost:27017',
  mongoDbName: env('MONGO_DB_NAME') ?? 'mediclear',
  pdfTextMinLength: Number.parseInt(env('PDF_TEXT_MIN_LENGTH') ?? '300', 10),
  chunkSize: Number.parseInt(env('CHUNK_SIZE') ?? '1200', 10),
  chunkOverlap: Number.parseInt(env('CHUNK_OVERLAP') ?? '160', 10),
  llmApiKey: env('LLM_API_KEY') ?? env('DEEPSEEK_API_KEY') ?? '',
  llmBaseUrl: env('LLM_BASE_URL') ?? env('DEEPSEEK_BASE_URL') ?? 'https://api.deepseek.com',
  llmModel: env('LLM_MODEL') ?? env('DEEPSEEK_MODEL') ?? 'deepseek-chat'
};
