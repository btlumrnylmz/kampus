"""
Backend configuration.
"""
import os
from pathlib import Path

# Paths
BASE_DIR = Path(__file__).parent
DATA_DIR = BASE_DIR / "data"
KNOWLEDGE_BASE_PATH = DATA_DIR / "campus_knowledge.json"
FAISS_INDEX_PATH = DATA_DIR / "campus.faiss"
EMBEDDINGS_PATH = DATA_DIR / "embeddings.npy"

# TF-IDF fallback training data path
_default_train_path = BASE_DIR.parent / "train_examples.txt"
TRAIN_DATA_PATH = Path(os.getenv("TRAIN_DATA_PATH", str(_default_train_path)))

# Retrieval settings
EMBEDDING_MODEL = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
TOP_K_RESULTS = 5

# Mode-specific thresholds
# FAISS uses cosine similarity of embeddings (typically 0.3-0.8 for good matches)
SIMILARITY_THRESHOLD = float(os.getenv("FAISS_THRESHOLD", "0.30"))
# TF-IDF uses cosine similarity of term vectors (typically 0.1-0.4 for good matches)
TFIDF_THRESHOLD = float(os.getenv("TFIDF_THRESHOLD", "0.15"))

# Evidence threshold for calling model (mode-specific, see main.py)
# These are separate from search thresholds - used to decide if we have enough evidence
FAISS_EVIDENCE_THRESHOLD = float(os.getenv("FAISS_EVIDENCE_THRESHOLD", "0.50"))
TFIDF_EVIDENCE_THRESHOLD = float(os.getenv("TFIDF_EVIDENCE_THRESHOLD", "0.15"))

# Campus guardrails
CAMPUS_TOPICS = [
    "kütüphane", "library", "merkez kütüphane", "central library",
    "mühendislik", "engineering", "mühendislik fakültesi",
    "fen", "science", "fen fakültesi",
    "rektörlük", "rectorate", "rektör",
    "yemekhane", "cafeteria", "kantin", "yemek",
    "spor", "sports", "spor merkezi", "gym",
    "kampüs", "campus", "üniversite", "university",
    "fakülte", "faculty", "bölüm", "department",
    "derslik", "classroom", "amfi", "amphitheater",
    "laboratuvar", "lab", "laboratory",
    "yurt", "dormitory", "konaklama",
    "otopark", "parking", "park",
    "sağlık", "health", "revir", "infirmary",
    "banka", "bank", "atm",
    "kayıt", "registration", "öğrenci işleri",
    "mezuniyet", "graduation", "diploma",
    "ders", "course", "sınav", "exam",
    "hoca", "professor", "öğretim üyesi",
    "van", "yüzüncü yıl", "yyu",
]

# Off-topic rejection phrases
OFF_TOPIC_KEYWORDS = [
    "politik", "siyaset", "seçim", "parti",
    "din", "ibadet", "cami", "kilise",
    "kumar", "bahis", "şans oyunu",
    "silah", "weapon", "bomb", "bomba",
    "illegal", "yasadışı", "uyuşturucu", "drug",
]

# Model settings (Phase 3)
MODEL_PATH = os.getenv("GPT2_MODEL_PATH", None)  # Will be set in Phase 3
MAX_NEW_TOKENS = 150
TEMPERATURE = 0.7

# Server settings
HOST = os.getenv("RAG_HOST", "0.0.0.0")
PORT = int(os.getenv("RAG_PORT", "8000"))

