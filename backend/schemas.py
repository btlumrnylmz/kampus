"""
Pydantic schemas for RAG API.
"""
from typing import List, Optional
from pydantic import BaseModel, Field


# ============================================================
# Request Schemas
# ============================================================

class SearchRequest(BaseModel):
    """Request for /rag/search endpoint."""
    query: str = Field(..., min_length=1, max_length=500, description="Search query")
    top_k: int = Field(default=5, ge=1, le=20, description="Maximum results to return")
    min_score: float = Field(default=0.3, ge=0.0, le=1.0, description="Minimum similarity score")


class AnswerRequest(BaseModel):
    """Request for /rag/answer endpoint."""
    query: str = Field(..., min_length=1, max_length=500, description="User question")
    building_id: Optional[str] = Field(default=None, description="Related building ID for context")


# ============================================================
# Response Schemas
# ============================================================

class RetrievalResultSchema(BaseModel):
    """A single retrieval result."""
    doc_id: str
    title: str
    content: str
    building_id: Optional[str]
    score: float
    tags: List[str]


class SearchResponse(BaseModel):
    """Response for /rag/search endpoint."""
    status: str  # "ok" or "error"
    query: str
    results: List[RetrievalResultSchema]
    total_found: int
    message: Optional[str] = None


class MetaInfo(BaseModel):
    """Metadata about the response."""
    retriever_mode: str = "none"
    threshold_used: float = 0.0
    top_score: float = 0.0
    latency_ms: Optional[int] = None


class AnswerResponse(BaseModel):
    """Response for /rag/answer endpoint."""
    status: str  # "ok", "no_answer", "rejected", "error"
    query: str
    answer: Optional[str] = None
    sources: List[str] = Field(default_factory=list)
    context_used: Optional[str] = None
    confidence: float = 0.0
    message: Optional[str] = None
    model_used: bool = False  # True when actual model generates answer
    meta: Optional[MetaInfo] = None  # Retrieval metadata


class HealthResponse(BaseModel):
    """Response for /health endpoint."""
    status: str
    retriever_ready: bool
    retriever_mode: str = "none"  # "faiss", "tfidf", or "none"
    model_ready: bool
    documents_loaded: int
    version: str = "1.0.0"

