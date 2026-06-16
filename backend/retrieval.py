"""
Retrieval system for campus knowledge base.
Supports FAISS (primary) and TF-IDF (fallback) modes.
"""
import json
import re
import numpy as np
from pathlib import Path
from typing import List, Optional, Tuple
from dataclasses import dataclass

# TF-IDF is always available (scikit-learn)
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.metrics.pairwise import cosine_similarity

# FAISS and sentence-transformers are optional
FAISS_AVAILABLE = False
try:
    import faiss
    from sentence_transformers import SentenceTransformer
    FAISS_AVAILABLE = True
except ImportError:
    print("[Retrieval] FAISS/ST not available, using TFIDF fallback.")

from config import (
    KNOWLEDGE_BASE_PATH,
    FAISS_INDEX_PATH,
    EMBEDDINGS_PATH,
    EMBEDDING_MODEL,
    TOP_K_RESULTS,
    SIMILARITY_THRESHOLD,
    TRAIN_DATA_PATH,
    TFIDF_THRESHOLD,
)


# ============================================================
# Helper: Text Normalization for Turkish
# ============================================================

# Turkish -> ASCII transliteration map
TURKISH_TO_ASCII = str.maketrans({
    'ğ': 'g', 'Ğ': 'G',
    'ü': 'u', 'Ü': 'U',
    'ş': 's', 'Ş': 'S',
    'ı': 'i', 'İ': 'I',
    'ö': 'o', 'Ö': 'O',
    'ç': 'c', 'Ç': 'C',
})


def turkish_to_ascii(s: str) -> str:
    """Convert Turkish special characters to ASCII equivalents."""
    return s.translate(TURKISH_TO_ASCII)


# ANCHOR_TERMS: Specific campus entity terms that MUST match if present in query.
# If query contains any of these, returned docs MUST also contain at least one.
# Stored in Turkish form; we'll match both Turkish and ASCII versions.
ANCHOR_TERMS = frozenset({
    "kütüphane", "merkez kütüphane",
    "kantin", "kafeterya", "yemekhane",
    "rektörlük", "rektör",
    "mühendislik", "mühendislik fakültesi",
    "fen", "fen fakültesi",
    "spor", "spor merkezi",
    "hastane", "sağlık", "revir",
    "öğrenci işleri", "öğrenci",
    "ring", "servis", "otobüs",
    "otopark", "park",
    "atm", "banka",
    "yurt", "konaklama",
    "laboratuvar", "lab",
    "derslik", "amfi",
})

# Build ASCII versions for matching queries without Turkish chars
ANCHOR_TERMS_ASCII = frozenset(turkish_to_ascii(term) for term in ANCHOR_TERMS)

# Turkish question boilerplate / stop tokens (NOT entity terms)
# These are removed during tokenization to focus on meaningful terms.
STOP_TOKENS = frozenset({
    # Question words
    "nedir", "nerede", "nereden", "nereye", "nasıl", "kaçta", "kaç",
    "ne", "kim", "hangi", "hangisi",
    # Time/schedule boilerplate
    "saat", "saatleri", "saati", "çalışma", "çalışıyor", "açık", "kapalı",
    "gün", "günleri", "hafta", "haftalık",
    # Existence/state
    "var", "yok", "olan", "olur", "oluyor", "olarak",
    # Question particles
    "mi", "mı", "mu", "mü", "mü",
    # Conjunctions/prepositions
    "için", "ile", "ve", "ya", "veya", "da", "de", "den", "dan",
    # Demonstratives/articles
    "bir", "bu", "şu", "o", "ise", "gibi",
    # Common verbs/actions (non-entity)
    "ver", "söyle", "anlat", "açıkla", "göster", "bul",
    "genellikle", "hakkında", "bilgi", "bilgisi",
})


def turkish_normalize(s: str) -> str:
    """
    Normalize text for Turkish TF-IDF tokenization.
    - Lowercase with Turkish letters preserved (ğüşıöç)
    - Remove punctuation but keep letters and digits
    - Collapse whitespace
    """
    if not s:
        return ""
    # Lowercase (handles Turkish İ->i, I->ı correctly in Python 3)
    s = s.lower()
    # Keep only word chars, spaces, and Turkish letters
    # \w covers basic alphanumerics, we add Turkish letters explicitly
    s = re.sub(r'[^\w\sğüşıöç]', ' ', s, flags=re.UNICODE)
    # Collapse whitespace
    s = re.sub(r'\s+', ' ', s).strip()
    return s


def turkish_normalize_ascii(s: str) -> str:
    """
    Normalize Turkish text to ASCII for TF-IDF matching.
    This ensures "kütüphane" and "kutuphane" match as the same token.
    """
    return turkish_to_ascii(turkish_normalize(s))


def turkish_tokenize(s: str) -> List[str]:
    """
    Tokenize Turkish text with stop word removal and ASCII normalization.
    - Normalizes input to ASCII (kütüphane -> kutuphane)
    - Splits by whitespace
    - Removes tokens < 3 chars
    - Removes Turkish stop/boilerplate tokens (in ASCII form)
    """
    # Convert to ASCII for consistent matching
    normalized = turkish_normalize_ascii(s)
    tokens = normalized.split()
    # Stop tokens are in Turkish; convert to ASCII for comparison
    stop_tokens_ascii = frozenset(turkish_to_ascii(t) for t in STOP_TOKENS)
    # Filter: length >= 3 and not a stop token
    return [t for t in tokens if len(t) >= 3 and t not in stop_tokens_ascii]


def _extract_anchor_terms(text: str) -> List[str]:
    """
    Extract anchor terms (campus entity terms) present in text.
    Matches both Turkish (kütüphane) and ASCII (kutuphane) versions.
    Returns list of matching anchor terms found (canonical Turkish form).
    """
    normalized = turkish_normalize(text)
    normalized_ascii = turkish_to_ascii(normalized)
    found = []
    
    for anchor in ANCHOR_TERMS:
        anchor_ascii = turkish_to_ascii(anchor)
        # Match if Turkish or ASCII version is in the text
        if anchor in normalized or anchor_ascii in normalized_ascii:
            found.append(anchor)  # Return canonical Turkish form
    return found


def _extract_focus_keywords(query: str) -> List[str]:
    """
    Extract focus keywords from query (non-stop tokens).
    Used for secondary filtering when no anchor terms match.
    """
    return turkish_tokenize(query)


# ============================================================
# Helper: Robust Text Reading (Windows + Turkish)
# ============================================================

def _read_text_robust(path: Path) -> Tuple[str, str]:
    """
    Read text file with robust encoding handling for Turkish on Windows.
    
    Tries:
    1. UTF-8 with BOM (utf-8-sig) - standard for UTF-8 files with BOM
    2. CP1254 (Turkish Windows codepage) with error replacement
    
    Returns:
        Tuple of (content, encoding_used)
    """
    raw = path.read_bytes()
    
    # Try UTF-8 with BOM first (handles most properly saved files)
    try:
        return raw.decode("utf-8-sig"), "utf-8-sig"
    except UnicodeDecodeError:
        pass
    
    # Try plain UTF-8 without BOM
    try:
        return raw.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        pass
    
    # Fallback to Turkish Windows codepage with replacement
    return raw.decode("cp1254", errors="replace"), "cp1254"


@dataclass
class RetrievalResult:
    """A single retrieval result."""
    doc_id: str
    title: str
    content: str
    building_id: Optional[str]
    score: float
    tags: List[str]


class CampusRetriever:
    """
    Retrieval system supporting FAISS (embeddings) or TF-IDF (fallback).
    """

    def __init__(self):
        # Common fields
        self.documents: List[dict] = []
        self._initialized = False
        self._mode: str = "none"  # "faiss", "tfidf", or "none"

        # FAISS mode fields
        self.model: Optional['SentenceTransformer'] = None
        self.index: Optional['faiss.Index'] = None
        self.embeddings: Optional[np.ndarray] = None

        # TF-IDF mode fields
        self._tfidf_vectorizer: Optional[TfidfVectorizer] = None
        self._tfidf_matrix: Optional[np.ndarray] = None
        self._tfidf_docs: List[dict] = []  # {source_id, text, title}

    @property
    def mode(self) -> str:
        """Get the current retriever mode."""
        return self._mode

    def initialize(self) -> bool:
        """Initialize the retriever. Uses FAISS if available, else TF-IDF fallback."""
        if FAISS_AVAILABLE:
            return self._initialize_faiss()
        else:
            return self._initialize_tfidf()

    # ============================================================
    # FAISS Mode
    # ============================================================

    def _initialize_faiss(self) -> bool:
        """Initialize with FAISS + sentence-transformers."""
        try:
            # Load embedding model
            print(f"[Retriever] Loading embedding model: {EMBEDDING_MODEL}")
            self.model = SentenceTransformer(EMBEDDING_MODEL)

            # Load knowledge base
            if not KNOWLEDGE_BASE_PATH.exists():
                print(f"[Retriever] Knowledge base not found: {KNOWLEDGE_BASE_PATH}")
                return False

            with open(KNOWLEDGE_BASE_PATH, 'r', encoding='utf-8') as f:
                data = json.load(f)
                self.documents = data.get('documents', [])

            if not self.documents:
                print("[Retriever] No documents in knowledge base")
                return False

            print(f"[Retriever] Loaded {len(self.documents)} documents")

            # Check for cached index
            if FAISS_INDEX_PATH.exists() and EMBEDDINGS_PATH.exists():
                print("[Retriever] Loading cached FAISS index...")
                self._load_cached_index()
            else:
                print("[Retriever] Building FAISS index from scratch...")
                self._build_faiss_index()

            self._initialized = True
            self._mode = "faiss"
            print(f"[Retriever] FAISS active. documents={len(self.documents)} threshold={SIMILARITY_THRESHOLD}")
            return True

        except Exception as e:
            print(f"[Retriever] Failed to initialize FAISS: {e}")
            print("[Retriever] Falling back to TF-IDF...")
            return self._initialize_tfidf()

    def _build_faiss_index(self):
        """Build FAISS index from documents."""
        texts = [
            f"{doc['title']}. {doc['content']}"
            for doc in self.documents
        ]

        print(f"[Retriever] Encoding {len(texts)} documents...")
        self.embeddings = self.model.encode(
            texts,
            show_progress_bar=True,
            convert_to_numpy=True,
        )

        # Normalize embeddings for cosine similarity
        faiss.normalize_L2(self.embeddings)

        # Build FAISS index
        dimension = self.embeddings.shape[1]
        self.index = faiss.IndexFlatIP(dimension)
        self.index.add(self.embeddings)

        # Cache for faster startup
        self._save_cached_index()

    def _save_cached_index(self):
        """Save FAISS index and embeddings to disk."""
        try:
            FAISS_INDEX_PATH.parent.mkdir(parents=True, exist_ok=True)
            faiss.write_index(self.index, str(FAISS_INDEX_PATH))
            np.save(EMBEDDINGS_PATH, self.embeddings)
            print("[Retriever] Cached FAISS index and embeddings")
        except Exception as e:
            print(f"[Retriever] Failed to cache index: {e}")

    def _load_cached_index(self):
        """Load FAISS index and embeddings from disk."""
        self.index = faiss.read_index(str(FAISS_INDEX_PATH))
        self.embeddings = np.load(EMBEDDINGS_PATH)

    # ============================================================
    # TF-IDF Fallback Mode
    # ============================================================

    def _initialize_tfidf(self) -> bool:
        """Initialize with TF-IDF fallback using Turkish-aware tokenizer."""
        try:
            # Try to load from training data file
            docs = []

            if TRAIN_DATA_PATH.exists():
                print(f"[Retriever] Loading training data: {TRAIN_DATA_PATH}")
                docs = self._parse_train_data(TRAIN_DATA_PATH)
            else:
                print(f"[Retriever] Training data not found: {TRAIN_DATA_PATH}")
                # Try to load from knowledge base JSON
                if KNOWLEDGE_BASE_PATH.exists():
                    print(f"[Retriever] Falling back to knowledge base: {KNOWLEDGE_BASE_PATH}")
                    docs = self._load_knowledge_base_as_tfidf()

            if not docs:
                print("[Retriever] No documents available for TF-IDF")
                return False

            self._tfidf_docs = docs
            self.documents = docs  # For compatibility with len(retriever.documents)

            # Build TF-IDF index with:
            # 1) Custom Turkish tokenizer (removes stop words)
            # 2) Custom preprocessor (Turkish normalization)
            # 3) Title weighting (repeat title 3x)
            texts = []
            for doc in docs:
                title = doc.get('title', '')
                content = doc.get('content', doc.get('text', ''))
                # Weight title heavily by repeating it
                weighted_text = f"{title} {title} {title} {content}"
                texts.append(weighted_text)
            
            # Use custom Turkish tokenizer with ASCII normalization
            # This ensures "kütüphane" and "kutuphane" match as the same token
            self._tfidf_vectorizer = TfidfVectorizer(
                tokenizer=turkish_tokenize,
                preprocessor=turkish_normalize_ascii,
                token_pattern=None,  # Required when using custom tokenizer
                ngram_range=(1, 2),
                max_features=10000,
            )
            self._tfidf_matrix = self._tfidf_vectorizer.fit_transform(texts)

            self._initialized = True
            self._mode = "tfidf"
            print(f"[Retriever] TFIDF active. chunks={len(docs)} path={TRAIN_DATA_PATH} threshold={TFIDF_THRESHOLD}")
            return True

        except Exception as e:
            print(f"[Retriever] Failed to initialize TF-IDF: {e}")
            import traceback
            traceback.print_exc()
            return False

    def _parse_train_data(self, path: Path) -> List[dict]:
        """
        Parse training data file with robust encoding handling.
        Supports Soru:/Cevap: format or raw text chunking.
        """
        docs = []
        
        # Use robust text reading for Turkish on Windows
        content, encoding = _read_text_robust(path)
        
        # Log encoding info (first line preview only, no full dump)
        first_line = content.split('\n')[0][:80] if content else ""
        print(f"[Retriever] Loaded training data encoding={encoding} first_line_len={len(first_line)}")

        # Check if file has Soru:/Cevap: format
        if 'Soru:' in content and 'Cevap:' in content:
            docs = self._parse_qa_format(content)
        else:
            docs = self._chunk_raw_text(content)

        return docs

    def _parse_qa_format(self, content: str) -> List[dict]:
        """Parse Soru:/Cevap: formatted training data."""
        docs = []
        # Split by "Soru:" to get Q&A pairs
        pairs = re.split(r'\n\s*Soru:', content)

        for i, pair in enumerate(pairs):
            if not pair.strip():
                continue

            # Add back "Soru:" if not the first part
            if i > 0 or not pair.strip().startswith('Soru:'):
                pair = "Soru:" + pair

            # Find Cevap section
            match = re.search(r'Soru:\s*(.+?)\s*Cevap:\s*(.+)', pair, re.DOTALL)
            if match:
                question = match.group(1).strip()
                answer = match.group(2).strip()
                # Clean up answer (remove next Soru if accidentally captured)
                answer = re.split(r'\n\s*Soru:', answer)[0].strip()

                text = f"Soru: {question}\nCevap: {answer}"
                source_id = f"train_{i:05d}"

                docs.append({
                    'source_id': source_id,
                    'id': source_id,
                    'title': question[:50] + "..." if len(question) > 50 else question,
                    'text': text,
                    'content': answer,
                    'building_id': None,
                    'tags': ['train'],
                })

        print(f"[Retriever] Parsed {len(docs)} Q&A pairs from training data")
        return docs

    def _chunk_raw_text(self, content: str, chunk_size: int = 900) -> List[dict]:
        """Chunk raw text into ~900 character chunks."""
        docs = []
        # Split by paragraphs first
        paragraphs = content.split('\n\n')
        current_chunk = ""
        chunk_idx = 0

        for para in paragraphs:
            para = para.strip()
            if not para:
                continue

            if len(current_chunk) + len(para) > chunk_size:
                if current_chunk:
                    source_id = f"train_{chunk_idx:05d}"
                    docs.append({
                        'source_id': source_id,
                        'id': source_id,
                        'title': current_chunk[:50] + "...",
                        'text': current_chunk,
                        'content': current_chunk,
                        'building_id': None,
                        'tags': ['train'],
                    })
                    chunk_idx += 1
                current_chunk = para
            else:
                current_chunk = f"{current_chunk}\n\n{para}" if current_chunk else para

        # Add final chunk
        if current_chunk:
            source_id = f"train_{chunk_idx:05d}"
            docs.append({
                'source_id': source_id,
                'id': source_id,
                'title': current_chunk[:50] + "...",
                'text': current_chunk,
                'content': current_chunk,
                'building_id': None,
                'tags': ['train'],
            })

        print(f"[Retriever] Chunked into {len(docs)} text chunks")
        return docs

    def _load_knowledge_base_as_tfidf(self) -> List[dict]:
        """Load knowledge base JSON and convert to TF-IDF format."""
        docs = []
        try:
            with open(KNOWLEDGE_BASE_PATH, 'r', encoding='utf-8') as f:
                data = json.load(f)
                kb_docs = data.get('documents', [])

            for doc in kb_docs:
                docs.append({
                    'source_id': doc.get('id', f"kb_{len(docs):05d}"),
                    'id': doc.get('id', f"kb_{len(docs):05d}"),
                    'title': doc.get('title', ''),
                    'text': f"{doc.get('title', '')}. {doc.get('content', '')}",
                    'content': doc.get('content', ''),
                    'building_id': doc.get('building_id'),
                    'tags': doc.get('tags', []),
                })

            print(f"[Retriever] Loaded {len(docs)} documents from knowledge base")
        except Exception as e:
            print(f"[Retriever] Error loading knowledge base: {e}")

        return docs

    # ============================================================
    # Search (works for both modes)
    # ============================================================

    def search(
        self,
        query: str,
        top_k: int = TOP_K_RESULTS,
        min_score: Optional[float] = None,
    ) -> List[RetrievalResult]:
        """
        Search for relevant documents given a query.
        Uses appropriate threshold based on mode.
        """
        if not self._initialized:
            print("[Retriever] Not initialized")
            return []

        # Use mode-appropriate threshold
        if min_score is None:
            min_score = SIMILARITY_THRESHOLD if self._mode == "faiss" else TFIDF_THRESHOLD

        if self._mode == "faiss":
            return self._search_faiss(query, top_k, min_score)
        else:
            return self._search_tfidf(query, top_k, min_score)

    def _search_faiss(
        self,
        query: str,
        top_k: int,
        min_score: float,
    ) -> List[RetrievalResult]:
        """Search using FAISS embeddings."""
        try:
            # Encode query
            query_embedding = self.model.encode(
                [query],
                convert_to_numpy=True,
            )
            faiss.normalize_L2(query_embedding)

            # Search
            scores, indices = self.index.search(query_embedding, top_k)

            # Build results
            results = []
            for score, idx in zip(scores[0], indices[0]):
                if idx < 0 or score < min_score:
                    continue

                doc = self.documents[idx]
                results.append(RetrievalResult(
                    doc_id=doc.get('id', f"doc_{idx}"),
                    title=doc.get('title', ''),
                    content=doc.get('content', ''),
                    building_id=doc.get('building_id'),
                    score=float(score),
                    tags=doc.get('tags', []),
                ))

            return results

        except Exception as e:
            print(f"[Retriever] FAISS search error: {e}")
            return []

    def _search_tfidf(
        self,
        query: str,
        top_k: int,
        min_score: float,
    ) -> List[RetrievalResult]:
        """
        Search using TF-IDF similarity with ANCHOR TERM hard filtering.
        
        Hard filter rule:
        - If query contains anchor terms (e.g., "kütüphane"), 
          docs MUST contain at least one of those same anchor terms.
        - No overlap = score 0, rejected from results.
        """
        try:
            # Extract anchor terms from query (campus entity terms)
            query_anchors = _extract_anchor_terms(query)
            
            # Also extract focus keywords as fallback
            focus_keywords = _extract_focus_keywords(query)

            # Vectorize query (uses our custom tokenizer)
            query_vec = self._tfidf_vectorizer.transform([query])

            # Compute cosine similarity
            similarities = cosine_similarity(query_vec, self._tfidf_matrix).flatten()

            # Get top-k * 3 indices for filtering (we may reject many)
            top_indices = similarities.argsort()[::-1][:top_k * 3]

            # Build results with ANCHOR TERM hard filtering
            results = []
            kept_count = 0
            rejected_count = 0
            top_title = ""
            top_score_final = 0.0

            for idx in top_indices:
                base_score = similarities[idx]
                if base_score < 0.01:  # Skip near-zero scores
                    continue

                doc = self._tfidf_docs[idx]
                title = doc.get('title', '')
                content = doc.get('content', doc.get('text', ''))
                doc_text = f"{title} {content}"

                # === ANCHOR TERM HARD FILTER ===
                # If query has anchor terms, doc MUST have at least one of them
                if query_anchors:
                    doc_anchors = _extract_anchor_terms(doc_text)
                    anchor_overlap = set(query_anchors) & set(doc_anchors)
                    
                    if not anchor_overlap:
                        # HARD REJECT: doc doesn't mention the queried entity
                        rejected_count += 1
                        continue
                    
                    # Bonus for anchor match
                    score = min(base_score + 0.10, 1.0)
                else:
                    # No anchor terms in query, use focus keyword fallback
                    if focus_keywords:
                        doc_tokens = set(turkish_tokenize(doc_text))
                        has_overlap = any(kw in doc_tokens for kw in focus_keywords)
                        
                        if not has_overlap:
                            rejected_count += 1
                            continue
                        
                        score = min(base_score + 0.05, 1.0)
                    else:
                        # No filtering possible, use base score
                        score = base_score

                # Apply final threshold
                if score < min_score:
                    continue

                # Track top result for logging
                if not top_title:
                    top_title = title[:50]
                    top_score_final = score

                results.append(RetrievalResult(
                    doc_id=doc.get('id', doc.get('source_id', f"doc_{idx}")),
                    title=title,
                    content=content,
                    building_id=doc.get('building_id'),
                    score=float(score),
                    tags=doc.get('tags', []),
                ))
                kept_count += 1
                
                if kept_count >= top_k:
                    break

            # Debug log
            query_short = query[:50] + "..." if len(query) > 50 else query
            print(f"[TFIDF] query='{query_short}' anchors={query_anchors} focus={focus_keywords[:3]} "
                  f"top_title='{top_title}' top_score={top_score_final:.3f} kept={kept_count}/{top_k} rejected={rejected_count}")

            return results

        except Exception as e:
            print(f"[Retriever] TF-IDF search error: {e}")
            import traceback
            traceback.print_exc()
            return []

    def get_context_for_query(
        self,
        query: str,
        max_context_length: int = 1500,
    ) -> Tuple[str, List[str], float]:
        """
        Get formatted context for LLM prompt with inline source citations.

        Returns:
            Tuple of (context_text, source_ids, top_score)
        """
        results = self.search(query)

        if not results:
            return "", [], 0.0

        # Get top score for evidence threshold check
        top_score = max(r.score for r in results) if results else 0.0

        context_parts = []
        source_ids = []
        total_length = 0

        for result in results:
            # Format each result with inline source_id
            part = f"[{result.doc_id}] {result.title}: {result.content}\n"

            if total_length + len(part) > max_context_length:
                break

            context_parts.append(part)
            source_ids.append(result.doc_id)
            total_length += len(part)

        context = "\n".join(context_parts)
        return context, source_ids, top_score


# ============================================================
# Global Retriever Instance
# ============================================================

_retriever: Optional[CampusRetriever] = None


def get_retriever() -> CampusRetriever:
    """Get or create the global retriever instance."""
    global _retriever
    if _retriever is None:
        _retriever = CampusRetriever()
    return _retriever


def initialize_retriever() -> bool:
    """Initialize the global retriever."""
    retriever = get_retriever()
    return retriever.initialize()
