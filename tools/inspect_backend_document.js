const baseUrl = 'http://127.0.0.1:18080';
const documentId = Number.parseInt(process.argv[2] ?? '4', 10);
const query = process.argv.slice(3).join(' ') || 'Możliwe działania niepożądane adverse side effects';

const documentResponse = await fetch(`${baseUrl}/api/documents/${documentId}`);
console.log('document', documentResponse.status, await documentResponse.text());

const chunksResponse = await fetch(`${baseUrl}/api/documents/${documentId}/chunks`);
const chunksJson = await chunksResponse.json();
console.log('chunks', chunksResponse.status, chunksJson.chunks.length);
for (const chunk of chunksJson.chunks) {
  const preview = chunk.chunk_text.slice(0, 260).replace(/\s+/g, ' ');
  const section = chunk.section_title || chunk.section_type || 'none';
  console.log(`#${chunk.chunk_index} p${chunk.page_number} ${section}: ${preview}`);
}

const searchResponse = await fetch(`${baseUrl}/api/search`, {
  method: 'POST',
  headers: { 'content-type': 'application/json' },
  body: JSON.stringify({ documentId, query, limit: 12 })
});
console.log('search', searchResponse.status, await searchResponse.text());
