# RAG Backend for Campus Navigation

Retrieval-Augmented Generation backend for the campus navigation assistant.

## Phase Status

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1 | ✅ Complete | Backend skeleton + FAISS retrieval + guardrails + endpoints |
| Phase 2 | ✅ Complete | Flutter HTTP integration with feature flag |
| Phase 3 | ⏳ Pending | Model inference (waiting for model path) |

## Quick Start

### 1. Create Virtual Environment

```bash
cd backend
python -m venv venv

# Windows
venv\Scripts\activate

# Linux/Mac
source venv/bin/activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

Note: The first run will download the embedding model (~500MB).

### 3. Run the Server

```bash
python main.py
```

Or with uvicorn directly:

```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### 4. Test the API

Health check:
```bash
curl http://localhost:8000/health
```

Search:
```bash
curl -X POST http://localhost:8000/rag/search \
  -H "Content-Type: application/json" \
  -d '{"query": "Kütüphane nerede?"}'
```

Answer:
```bash
curl -X POST http://localhost:8000/rag/answer \
  -H "Content-Type: application/json" \
  -d '{"query": "Merkez kütüphane çalışma saatleri nedir?"}'
```

## API Endpoints

### `GET /health`
Returns server status, retriever readiness, and document count.

### `POST /rag/search`
Search the knowledge base.

Request:
```json
{
  "query": "kütüphane nerede",
  "top_k": 5,
  "min_score": 0.3
}
```

Response:
```json
{
  "status": "ok",
  "query": "kütüphane nerede",
  "results": [
    {
      "doc_id": "central_library_location",
      "title": "Merkez Kütüphane Konumu",
      "content": "...",
      "building_id": "central_library",
      "score": 0.85,
      "tags": ["konum", "yol", "navigasyon"]
    }
  ],
  "total_found": 1
}
```

### `POST /rag/answer`
Get an answer for a question.

Request:
```json
{
  "query": "Kütüphane kaçta açılıyor?",
  "building_id": "central_library"
}
```

Response (Phase 1/2 - no model):
```json
{
  "status": "ok",
  "query": "Kütüphane kaçta açılıyor?",
  "answer": null,
  "sources": ["central_library_info"],
  "context_used": "...",
  "confidence": 0.85,
  "model_used": false,
  "message": "Bağlam bulundu. Model entegrasyonu Phase 3'te eklenecek."
}
```

Response (Phase 3 - with model):
```json
{
  "status": "ok",
  "query": "Kütüphane kaçta açılıyor?",
  "answer": "Merkez Kütüphane hafta içi 08:00-22:00 saatleri arasında açıktır.",
  "sources": ["central_library_info"],
  "context_used": "...",
  "confidence": 0.85,
  "model_used": true
}
```

## Flutter Integration

To enable the real backend in Flutter:

1. Start the backend server
2. Edit `lib/core/constants/app_config.dart`:

```dart
static const bool useRealRagBackend = true;
```

3. Run Flutter app

## Campus Guardrails

The backend includes topic filtering:

**Allowed Topics:**
- Campus buildings (kütüphane, mühendislik, fen, etc.)
- University services (kayıt, yemekhane, spor)
- Navigation queries (nerede, nasıl gidilir)

**Rejected Topics:**
- Political content
- Religious content
- Illegal activities
- Off-topic questions

## Phase 3: Model Integration

When you have the fine-tuned GPT-2 model:

1. Set the environment variable:
```bash
export GPT2_MODEL_PATH=/path/to/your/model
```

2. Uncomment the model loading code in `model_infer.py`

3. Install additional dependencies:
```bash
pip install transformers torch
```

4. Restart the server

## Project Structure

```
backend/
├── main.py              # FastAPI application
├── config.py            # Configuration
├── schemas.py           # Pydantic models
├── retrieval.py         # FAISS retrieval
├── guardrails.py        # Topic filtering
├── model_infer.py       # Model inference (Phase 3)
├── requirements.txt     # Dependencies
├── README.md            # This file
└── data/
    ├── campus_knowledge.json  # Knowledge base
    ├── campus.faiss           # FAISS index (auto-generated)
    └── embeddings.npy         # Cached embeddings (auto-generated)
```









