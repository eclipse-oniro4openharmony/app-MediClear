// Use 127.0.0.1 only for a local emulator on the same computer.
// For a physical phone, use the computer's Wi-Fi/LAN IPv4 address.
export const MEDICLEAR_BACKEND_BASE_URL: string = 'http://192.168.123.131:18080';

export const MEDICLEAR_BACKEND_HEALTH_URL: string = `${MEDICLEAR_BACKEND_BASE_URL}/health`;

export function buildAuthRegisterUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/auth/register`;
}

export function buildAuthVerifyEmailUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/auth/verify-email`;
}

export function buildAuthLoginUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/auth/login`;
}

export function buildAuthRefreshUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/auth/refresh`;
}

export function buildAuthLogoutUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/auth/logout`;
}

export function buildAuthForgotPasswordUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/auth/forgot-password`;
}

export function buildAuthResetPasswordUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/auth/reset-password`;
}

export function buildRplDocumentExtractUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/documents/rpl`;
}

export function buildMedicineOcrUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/ocr`;
}

export function buildDocumentChunksUrl(documentId: number): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/documents/${documentId}/chunks`;
}

export function buildDocumentFactsUrl(documentId: number): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/documents/${documentId}/facts`;
}

export function buildDocumentSearchUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/search`;
}

export function buildMedicineChatUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/chat`;
}

export function buildReminderPlanUrl(): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/reminders/plan`;
}

export function buildLatestDocumentByProductUrl(productId: string): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/documents/by-product/${productId}`;
}

export function buildLatestLeafletByProductUrl(productId: string): string {
  return `${MEDICLEAR_BACKEND_BASE_URL}/api/documents/by-product/${productId}?documentType=leaflet`;
}
