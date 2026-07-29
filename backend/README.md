# MediClear Backend

This backend keeps PDF processing and PDF-derived knowledge-base data outside the MediClear mobile app.

The first backend capability is PDF knowledge-base preparation. It downloads official leaflet PDFs, extracts readable text, splits that text into chunks, stores the chunks in MongoDB, and does not persist the source PDF.

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

## Start With Docker

Copy the example environment file if you want to customize ports or MongoDB settings:

```bash
cp .env.example .env
```

Set the DeepSeek key in `backend/.env`:

```text
DEEPSEEK_API_KEY=sk-your-key-here
DEEPSEEK_BASE_URL=https://api.deepseek.com
DEEPSEEK_MODEL=deepseek-chat
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

The server retrieves relevant leaflet chunks from MongoDB, gives DeepSeek a restricted MediClear assistant identity, and answers only from the current medicine knowledge base.

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

The DeepSeek API key stays in `backend/.env`; it is not stored in the mobile app.
