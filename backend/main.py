"""
RAG Backend API for Campus Navigation Assistant.

Phase 1: Retrieval + Guardrails (no model yet)
Phase 2: Flutter integration
Phase 3: Model inference
"""
from contextlib import asynccontextmanager
from typing import List

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware

from config import HOST, PORT, FAISS_EVIDENCE_THRESHOLD, TFIDF_EVIDENCE_THRESHOLD
from schemas import (
    SearchRequest,
    SearchResponse,
    AnswerRequest,
    AnswerResponse,
    HealthResponse,
    RetrievalResultSchema,
    MetaInfo,
)
from retrieval import get_retriever, initialize_retriever, RetrievalResult
from guardrails import apply_guardrails, format_rejection_message
from model_infer import is_model_available, load_model, generate_answer


# ============================================================
# Application Lifespan
# ============================================================

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application startup and shutdown."""
    print("=" * 60)
    print("RAG Backend Starting...")
    print("=" * 60)

    # Initialize retriever
    retriever_ok = initialize_retriever()
    if retriever_ok:
        print("[Startup] Retriever initialized successfully")
    else:
        print("[Startup] WARNING: Retriever initialization failed")

    # Try to load model (Phase 3 - will fail gracefully)
    model_ok = load_model()
    if model_ok:
        print("[Startup] Model loaded successfully")
    else:
        print("[Startup] Model not loaded (Phase 3 pending)")

    print("=" * 60)
    print(f"Server ready at http://{HOST}:{PORT}")
    print("=" * 60)

    yield

    print("Shutting down...")


# ============================================================
# FastAPI App
# ============================================================

app = FastAPI(
    title="Campus RAG API",
    description="Retrieval-Augmented Generation API for Campus Navigation",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS for Flutter web
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# Endpoints
# ============================================================

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint."""
    retriever = get_retriever()
    return HealthResponse(
        status="ok",
        retriever_ready=retriever._initialized,
        retriever_mode=retriever.mode if retriever._initialized else "none",
        model_ready=is_model_available(),
        documents_loaded=len(retriever.documents) if retriever._initialized else 0,
    )


@app.post("/rag/search", response_model=SearchResponse)
async def search(request: SearchRequest):
    """
    Search the knowledge base for relevant documents.

    Returns matching documents with similarity scores.
    """
    try:
        # Apply guardrails
        guardrail = apply_guardrails(request.query)
        if not guardrail.is_allowed:
            return SearchResponse(
                status="rejected",
                query=request.query,
                results=[],
                total_found=0,
                message=format_rejection_message(guardrail),
            )

        # Perform retrieval
        retriever = get_retriever()
        if not retriever._initialized:
            return SearchResponse(
                status="no_answer",
                query=request.query,
                results=[],
                total_found=0,
                message="Retriever not initialized. Please check server logs.",
            )

        results = retriever.search(
            query=request.query,
            top_k=request.top_k,
            min_score=request.min_score,
        )

        # Sanity check log
        top_score = max(r.score for r in results) if results else 0.0
        query_short = request.query[:50] + "..." if len(request.query) > 50 else request.query
        print(f"[Search] query='{query_short}' mode={retriever.mode} top_score={top_score:.3f} results={len(results)}")

        # Convert to response schema
        result_schemas = [
            RetrievalResultSchema(
                doc_id=r.doc_id,
                title=r.title,
                content=r.content,
                building_id=r.building_id,
                score=r.score,
                tags=r.tags,
            )
            for r in results
        ]

        return SearchResponse(
            status="ok",
            query=request.query,
            results=result_schemas,
            total_found=len(results),
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Search error: {e}")
        return SearchResponse(
            status="error",
            query=request.query,
            results=[],
            total_found=0,
            message=str(e),
        )


@app.post("/rag/answer", response_model=AnswerResponse)
async def answer(request: AnswerRequest):
    """
    Answer a question using RAG.

    Phase 1: Returns context-based answer or no_answer
    Phase 3: Will use fine-tuned model for generation
    """
    try:
        # Apply guardrails
        guardrail = apply_guardrails(request.query)
        if not guardrail.is_allowed:
            return AnswerResponse(
                status="rejected",
                query=request.query,
                message=format_rejection_message(guardrail),
                confidence=guardrail.confidence,
            )

        # Perform retrieval
        retriever = get_retriever()
        if not retriever._initialized:
            return AnswerResponse(
                status="no_answer",
                query=request.query,
                message="Retriever not initialized. Please check server logs.",
                sources=[],
                confidence=0.0,
            )

        context, source_ids, top_score = retriever.get_context_for_query(request.query)

        # Mode-specific evidence threshold
        retriever_mode = retriever.mode
        if retriever_mode == "tfidf":
            evidence_threshold = TFIDF_EVIDENCE_THRESHOLD
        else:
            evidence_threshold = FAISS_EVIDENCE_THRESHOLD

        # Build meta info
        meta = MetaInfo(
            retriever_mode=retriever_mode,
            threshold_used=evidence_threshold,
            top_score=top_score,
        )

        # Sanity check log
        query_short = request.query[:50] + "..." if len(request.query) > 50 else request.query
        print(f"[Answer] query='{query_short}' mode={retriever_mode} top_score={top_score:.3f} threshold={evidence_threshold:.2f}")

        # No relevant context found
        if not context:
            print(f"[Answer] No context found, returning no_answer")
            return AnswerResponse(
                status="no_answer",
                query=request.query,
                message="Bu soru için bilgi tabanında yeterli bilgi bulunamadı.",
                sources=[],
                confidence=0.0,
                meta=meta,
            )

        # Retrieval-first: Check evidence threshold before calling model
        if top_score < evidence_threshold:
            print(f"[Answer] Insufficient evidence: top_score={top_score:.3f} < threshold={evidence_threshold:.2f}")
            return AnswerResponse(
                status="no_answer",
                query=request.query,
                message=f"Yeterli kanıt bulunamadı (skor: {top_score:.2f} < eşik: {evidence_threshold:.2f}).",
                sources=source_ids,
                context_used=context,
                confidence=top_score,
                model_used=False,
                meta=meta,
            )

        # Check if model is available (Phase 3)
        if is_model_available():
            print(f"[Answer] Evidence sufficient, calling model...")
            # Use model for generation
            inference_result = generate_answer(
                query=request.query,
                context=context,
                source_ids=source_ids,
            )

            if not inference_result.is_placeholder:
                # Check if JSON parse was successful
                if inference_result.answer is not None and inference_result.answer.strip():
                    return AnswerResponse(
                        status="ok",
                        query=request.query,
                        answer=inference_result.answer,
                        sources=inference_result.sources,  # Use validated sources
                        context_used=context,
                        confidence=guardrail.confidence,
                        model_used=True,
                        meta=meta,
                    )
                else:
                    # JSON parse failed -> return no_answer (safe)
                    print("[Answer] Model output JSON parse failed, returning no_answer")
                    return AnswerResponse(
                        status="no_answer",
                        query=request.query,
                        message="Model cevabı işlenemedi. Bağlam bilgisi aşağıda.",
                        sources=source_ids,
                        context_used=context,
                        confidence=guardrail.confidence * 0.5,
                        model_used=True,
                        meta=meta,
                    )

        # Phase 1/2: Return context as answer (retrieval-first)
        # The client will display the retrieved information
        return AnswerResponse(
            status="ok",
            query=request.query,
            answer=None,  # No generated answer yet
            sources=source_ids,
            context_used=context,
            confidence=guardrail.confidence,
            model_used=False,
            message="Bağlam bulundu, model çıktısı bekleniyor.",
            meta=meta,
        )

    except HTTPException:
        raise
    except Exception as e:
        print(f"Answer error: {e}")
        return AnswerResponse(
            status="error",
            query=request.query,
            message=str(e),
        )


# ============================================================
# Run Server
# ============================================================

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host=HOST,
        port=PORT,
        reload=True,
    )

