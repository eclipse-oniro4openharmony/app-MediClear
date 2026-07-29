// Use 127.0.0.1 only for a local emulator on the same computer.
// For a physical phone, use the computer's Wi-Fi/LAN IPv4 address.
export const MEDICLEAR_BACKEND_BASE_URL: string = 'http://192.168.123.131:18080';

export const MEDICLEAR_BACKEND_HEALTH_URL: string = `${MEDICLEAR_BACKEND_BASE_URL}/health`;

export function buildRplDocumentExtractUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/documents/rpl`;
}

export function buildDocumentChunksUrl(documentId: number): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/documents/${documentId}/chunks`;
}

export function buildDocumentSearchUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/search`;
}

export function buildMedicineChatUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/chat`;
}

export function buildLatestDocumentByProductUrl(productId: string): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/documents/by-product/${productId}`;
}
