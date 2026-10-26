# MediClear Backend

This backend keeps PDF processing and PDF-derived knowledge-base data outside the MediClear mobile app.

The first backend capability is PDF knowledge-base preparation. It downloads official leaflet PDFs, extracts readable text, splits that text into chunks, stores the chunks in MongoDB, and does not persist the source PDF.

The backend also provides `POST /api/ocr` for medicine-image OCR. It accepts an `application/octet-stream` image body and forwards it as Base64 JSON to the private PaddleOCR service in Docker Compose. PaddleOCR uses the PP-OCRv6 medium pipeline on CPU by default. Photos are processed in memory and are not stored by the backend.

## Runtime Flow

```text
MediClear app finds RPL productId / leaflet URL
        ↓
POST /api/documents/rpl
        ↓
Service downloads PDF into memory
        ↓
pdfjs-dist extracts embedded PDF text
        ↓
MongoDB stores document metadata + text chunks + text index
        ↓
PDF buffer is discarded
```

Medicine image OCR follows this flow:

```text
MediClear app resizes and JPEG-encodes the photo
        ↓
POST /api/ocr to MediClear backend
        ↓
Backend forwards Base64 JSON over the private Compose network
        ↓
PaddleX Serving runs the PP-OCRv6 OCR pipeline
        ↓
Backend returns recognized text; image data is not persisted
```

## Start With Docker

Copy the example environment file if you want to customize ports or MongoDB settings:

```bash
cp .env.example .env
```

Configure the chat model in `backend/.env` if chat completion is needed. The OCR service is included in Compose and requires no API key.

Set a stable `AUTH_TOKEN_SECRET` with at least 32 random characters and configure the `SMTP_*` values before enabling user registration. For local-only testing, set `NODE_ENV=development` and `AUTH_EMAIL_MODE=console`; verification codes will be written to backend logs instead of sent by email. Do not use console email mode in production.

For the current DeepSeek setup:

```text
LLM_API_KEY=sk-your-key-here
LLM_BASE_URL=https://api.deepseek.com
LLM_MODEL=deepseek-chat
```

For a local Llama model, use any OpenAI-compatible local server. Because this backend runs in Docker, use `host.docker.internal` instead of `localhost`.

Ollama example:

```text
LLM_API_KEY=
LLM_BASE_URL=http://host.docker.internal:11434/v1
LLM_MODEL=llama3.2:3b
```

LM Studio example:

```text
LLM_API_KEY=
LLM_BASE_URL=http://host.docker.internal:1234/v1
LLM_MODEL=local-model
```

```bash
cd backend
docker compose up --build
```

The service runs on:

```text
http://localhost:18080
```

MongoDB data is stored in the Docker volume `mediclear_mongo_data`.
PP-OCRv6 model files are cached in the Docker volume `paddleocr_model_cache`. On the first start, PaddleOCR downloads its model files; later starts reuse the volume. The PaddleOCR container is only reachable on the internal Compose network and its port is not published to the host.

The database is text-search oriented:

- `documents` stores PDF source metadata.
- `document_chunks` stores extracted leaflet text chunks.
- MongoDB text indexes on `document_chunks.chunkText` and `document_chunks.sectionTitle` are used by `/api/search`.

## Phone App Configuration

This follows the same pattern as the SpeechPacer backend:

- Backend listens inside the container on `0.0.0.0:8080`.
- Docker publishes the service on your computer at `0.0.0.0:18080`.
- The mobile app must call an address that is reachable from the phone.

Use these URLs:

```text
Emulator on the same computer:
http://127.0.0.1:18080

Physical phone on the same Wi-Fi:
http://<YOUR_COMPUTER_LAN_IP>:18080
```

On Windows, find your LAN IP with:

```powershell
ipconfig
```

Use the IPv4 address of the Wi-Fi adapter, for example:

```text
http://192.168.123.131:18080
```

Do not use `127.0.0.1` from a physical phone. On the phone, `127.0.0.1` means the phone itself, not your computer.

If the phone cannot connect:

- Make sure the computer and phone are on the same Wi-Fi.
- Make sure Docker Desktop is running.
- Allow inbound traffic for port `18080` in Windows Firewall.
- Check that the container is running with `docker compose ps`.

## API

### Health

```http
GET /health
```

### Medicine Photo OCR

```http
POST /api/ocr
Content-Type: application/octet-stream
X-File-Type: image/jpeg

<JPEG image bytes>
```

The response is `{ "text": "..." }`. The backend converts the image body to Base64 for PaddleX's `POST /ocr` API and returns only recognized text to the app.

### Authentication

Authentication endpoints:

- `POST /api/auth/register` — create a pending account and send an email verification code.
- `POST /api/auth/verify-email` — verify an email address with its six-digit code.
- `POST /api/auth/login` — return a short-lived access token and refresh token.
- `POST /api/auth/refresh` — rotate a refresh token and return a new access/refresh token pair.
- `POST /api/auth/logout` — revoke a refresh token.
- `POST /api/auth/forgot-password` — send a password reset code without revealing whether an account exists.
- `POST /api/auth/reset-password` — change a password using the emailed code and revoke existing refresh sessions.

All other `/api/*` routes require `Authorization: Bearer <access-token>`. `/health` remains public. User accounts and refresh sessions are stored in MongoDB; access tokens expire after 15 minutes and refresh tokens expire after 30 days.

### Extract RPL Leaflet

```http
POST /api/documents/rpl
Content-Type: application/json

{
  "productId": "18874",
  "medicineName": "Espumisan",
  "documentType": "leaflet"
}
```

### Extract Any PDF URL

```http
POST /api/documents/extract-url
Content-Type: application/json

{
  "url": "https://rejestry.ezdrowie.gov.pl/api/rpl/medicinal-products/18874/leaflet",
  "productId": "18874",
  "medicineName": "Espumisan",
  "documentType": "leaflet"
}
```

### Get Chunks

```http
GET /api/documents/1/chunks
```

### Search Chunks

```http
POST /api/search
Content-Type: application/json

{
  "documentId": 1,
  "query": "dosage side effects",
  "limit": 8
}
```

### Medicine Chat

```http
POST /api/chat
Content-Type: application/json

{
  "documentId": 1,
  "medicineName": "Espumisan 40 mg",
  "question": "How should I take this medicine?"
}
```

The server retrieves relevant leaflet chunks from MongoDB, gives the configured LLM a restricted MediClear assistant identity, and answers only from the current medicine knowledge base.

Answers may include concise Markdown for readability, including bold labels, bullet lists, and numbered steps. The mobile Chat page renders assistant Markdown with `@luvi/lv-markdown-in`.

## Data Policy

The service stores:

- source URL
- source SHA-256 hash
- document status
- text preview
- text chunks
- MongoDB text index for those chunks

The service does not store:

- downloaded PDF files
- uploaded mobile photos
- AI chat answers

The LLM API key, if needed, stays in `backend/.env`; it is not stored in the mobile app. Local Llama/Ollama/LM Studio setups can leave `LLM_API_KEY` empty.
