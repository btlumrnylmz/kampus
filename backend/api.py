import json
import uvicorn
import re
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, Dict, Any, List

# RAG / Kelime Arama Kütüphaneleri
from rank_bm25 import BM25Okapi
from sentence_transformers import SentenceTransformer, util
import numpy as np
import re
import os
import pickle

# Llama Yükleme Kütüphaneleri
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, BitsAndBytesConfig
from peft import PeftModel

# Canlı Veri Scraper Servisleri
try:
    from yemek_scraper import YemekScraper
    from otobus_scraper import OtobusScraper
    yemek_scraper = YemekScraper()
    otobus_scraper = OtobusScraper()
    print("-> BASARILI: Canli Yemekhane ve Otobus scraper servisleri yuklendi!")
except Exception as e:
    print(f"UYARI: Scraper servisleri baslatilamadi: {e}")
    yemek_scraper = None
    otobus_scraper = None

app = FastAPI(title="YYÜ Kampüs Danışmanı API")

# Flutter'dan gelen istekleri kabul et
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Kampüs Lokasyonları Koordinat Veritabanı (Harita Entegrasyonu)
CAMPUS_LOCATIONS = [
    {"name": "Mühendislik Fakültesi", "lat": 38.5680, "lng": 43.2870, "category": "Akademik"},
    {"name": "Tıp Fakültesi (Dursun Odabaş)", "lat": 38.5750, "lng": 43.2977, "category": "Sağlık"},
    {"name": "Fen Fakültesi", "lat": 38.5685, "lng": 43.2855, "category": "Akademik"},
    {"name": "Edebiyat Fakültesi", "lat": 38.5670, "lng": 43.2865, "category": "Akademik"},
    {"name": "Eğitim Fakültesi", "lat": 38.5690, "lng": 43.2845, "category": "Akademik"},
    {"name": "İktisadi ve İdari Bilimler Fakültesi", "lat": 38.5695, "lng": 43.2875, "category": "Akademik"},
    {"name": "Hukuk Fakültesi", "lat": 38.5700, "lng": 43.2895, "category": "Akademik"},
    {"name": "İlahiyat Fakültesi", "lat": 38.5675, "lng": 43.2900, "category": "Akademik"},
    {"name": "Ziraat Fakültesi", "lat": 38.5665, "lng": 43.2835, "category": "Akademik"},
    {"name": "Eczacılık Fakültesi", "lat": 38.5658, "lng": 43.2840, "category": "Akademik"},
    {"name": "Diş Hekimliği Fakültesi", "lat": 38.5710, "lng": 43.2925, "category": "Akademik"},
    {"name": "Ferit Melen Kütüphanesi", "lat": 38.5641, "lng": 43.2852, "category": "Akademik"},
    {"name": "Rektörlük Binası", "lat": 38.5705, "lng": 43.2890, "category": "İdari"},
    {"name": "Öğrenci İşleri Daire Başkanlığı", "lat": 38.5700, "lng": 43.2882, "category": "İdari"},
    {"name": "Merkez Yemekhane", "lat": 38.5645, "lng": 43.2860, "category": "Yeme-İçme"},
    {"name": "Öğrenci Yaşam Merkezi (ÖYM)", "lat": 38.5648, "lng": 43.2858, "category": "Yeme-İçme"},
    {"name": "Van Gölü Sosyal Tesisleri ve Uygulama Oteli", "lat": 38.5612, "lng": 43.2823, "category": "Yeme-İçme"},
    {"name": "Mühendislik Fakültesi Kantini", "lat": 38.5680, "lng": 43.2870, "category": "Yeme-İçme"},
    {"name": "Edebiyat Fakültesi Kantini", "lat": 38.5670, "lng": 43.2865, "category": "Yeme-İçme"},
    {"name": "Eğitim Fakültesi Kantini", "lat": 38.5690, "lng": 43.2845, "category": "Yeme-İçme"},
    {"name": "İktisadi ve İdari Bilimler Fakültesi Kantini", "lat": 38.5695, "lng": 43.2875, "category": "Yeme-İçme"},
    {"name": "Dursun Odabaş Tıp Merkezi Kafeteryası", "lat": 38.5750, "lng": 43.2977, "category": "Yeme-İçme"},
    {"name": "Teknokent (Kika Kitap Kafe)", "lat": 38.5735, "lng": 43.2940, "category": "Yeme-İçme"},
    {"name": "Prof. Dr. Cengiz Andiç Kültür Merkezi", "lat": 38.5655, "lng": 43.2858, "category": "Etkinlik"},
    {"name": "Açık Hava Tiyatrosu", "lat": 38.5615, "lng": 43.2810, "category": "Etkinlik"},
    {"name": "Spor Tesisleri", "lat": 38.5660, "lng": 43.2830, "category": "Spor"},
    {"name": "Stadyum", "lat": 38.5650, "lng": 43.2820, "category": "Spor"},
    {"name": "KYK Erkek Yurdu", "lat": 38.5720, "lng": 43.2910, "category": "Barınma"},
    {"name": "KYK Kız Yurdu", "lat": 38.5730, "lng": 43.2920, "category": "Barınma"},
    {"name": "Mediko-Sosyal Merkezi", "lat": 38.5690, "lng": 43.2885, "category": "Sağlık"},
]

def find_location_in_query(query: str):
    query_lower = query.lower()
    for loc in CAMPUS_LOCATIONS:
        # Lokasyon adındaki önemli kelimeleri ara
        name_words = loc["name"].lower().replace("fakültesi", "").replace("binası", "").replace("daire", "").replace("başkanlığı", "").split()
        for word in name_words:
            if len(word) > 3 and word in query_lower:
                return loc
    return None

# --- 1. RAG (Arama Motoru) ALTYAPISI ---
print("-> RAG Veritabanı (dataset.jsonl) belleğe alınıyor ve parçalanıyor (Chunking)...")
documents = []
doc_titles = []
bm25 = None

# Türkçe stop-words (dolgu kelimeleri) listesi
turkish_stopwords = {
    'acaba', 'ama', 'aslında', 'az', 'bazı', 'belki', 'biri', 'birkaç', 'birşey', 'biz', 'bu', 'çok', 'çünkü', 
    'da', 'daha', 'de', 'defa', 'diye', 'eğer', 'en', 'gibi', 'hem', 'hep', 'hepsi', 'her', 'herhangi', 'herkes', 
    'hiç', 'için', 'ile', 'ise', 'kez', 'ki', 'kim', 'mı', 'mu', 'mü', 'nasıl', 'ne', 'neden', 'nedir', 'nerde', 
    'nerede', 'nereden', 'nereye', 'niçin', 'niye', 'o', 'sanki', 'şey', 'siz', 'şu', 'tüm', 've', 'veya', 'ya', 'yani',
    'et', 'yap', 'ol', 'olan', 'olarak', 'kendi', 'yer', 'yol', 'yolu', 'yolunu', 'bir', 'iki', 'üç'
}

def tokenize_for_bm25(text):
    text = text.lower()
    text = re.sub(r'[^\w\s]', ' ', text)
    words = text.split()
    return [w for w in words if w not in turkish_stopwords and len(w) > 1]

def chunk_text(text, chunk_size=150, overlap=50):
    words = text.split()
    chunks = []
    i = 0
    if len(words) == 0:
        return chunks
    while i < len(words):
        chunk = " ".join(words[i:i+chunk_size])
        chunks.append(chunk)
        i += chunk_size - overlap
    return chunks

# Global variables for semantic search
semantic_model = None
document_embeddings = None

try:
    with open("dataset.jsonl", "r", encoding="utf-8") as f:
        for line in f:
            if not line.strip(): continue
            item = json.loads(line)
            title = item.get("page_title", "")
            content = item.get("main_text", "")
            if len(content) > 10:
                # Daha büyük kesişimli parçalama
                content_chunks = chunk_text(content, chunk_size=150, overlap=50)
                for chunk in content_chunks:
                    doc_titles.append(title)
                    documents.append(title + " " + chunk)
    
    print("-> BM25 (Kelime) İndeksi oluşturuluyor...")
    tokenized_corpus = [tokenize_for_bm25(doc) for doc in documents]
    if tokenized_corpus:
        bm25 = BM25Okapi(tokenized_corpus)
    
    print("-> Semantik (Vektör) İndeks Modeli yükleniyor...")
    semantic_model = SentenceTransformer('paraphrase-multilingual-MiniLM-L12-v2')
    
    embeddings_cache_path = "dataset_embeddings_cache.pkl"
    if os.path.exists(embeddings_cache_path):
        print("-> Önbellekteki semantik vektörler yükleniyor...")
        with open(embeddings_cache_path, "rb") as f:
            document_embeddings = pickle.load(f)
        if len(document_embeddings) != len(documents):
            print("-> Veri seti değişmiş, vektörler yeniden hesaplanıyor... (Biraz sürebilir)")
            document_embeddings = semantic_model.encode(documents, show_progress_bar=True, convert_to_tensor=True)
            with open(embeddings_cache_path, "wb") as f:
                pickle.dump(document_embeddings, f)
    else:
        print("-> Semantik vektörler ilk kez hesaplanıyor... (Biraz sürebilir)")
        document_embeddings = semantic_model.encode(documents, show_progress_bar=True, convert_to_tensor=True)
        with open(embeddings_cache_path, "wb") as f:
            pickle.dump(document_embeddings, f)
            
    print(f"-> {len(documents)} parça (chunk) HİBRİT ARAMA (BM25 + Semantik) için hazır!")
except Exception as e:
    print(f"HATA: dataset.jsonl okunurken hata olustu: {e}")

# --- 2. YAPAY ZEKA MODELİ ALTYAPISI ---
print("-> Llama 3.2 Modeli 4-Bit olarak yükleniyor... Lütfen bekleyin.")
# Hızlı yüklenen ve Hugging Face token onayı istemeyen resmi 4-bit modeli kullanıyoruz
model_id = "meta-llama/Llama-3.2-3B-Instruct"
adapter_path = "./yyu_model_final"

# Tokenizer yükle (Resmi ve temiz Llama 3.2 3B Instruct Tokenizer'ı)
tokenizer = AutoTokenizer.from_pretrained(model_id)
if tokenizer.pad_token is None:
    tokenizer.pad_token = tokenizer.eos_token

# Sadece istek geldiğinde modeli kullanmak için global değişkenler
model = None

# Sistem Yönergesi
SYSTEM_PROMPT = """Sen Van Yüzüncü Yıl Üniversitesi (YYÜ) resmi Kampüs Danışmanısın.

GÖREVİN VE KESİN KURALLARIN:
1. Öğrencinin sorduğu soruya, sana sağlanan "Ek Resmi Bilgi (Bağlam)" kısmındaki bilgileri kullanarak doğrudan, net, açıklayıcı ve nihai bir şekilde cevap ver.
2. Kesinlikle öğrencinin sorusunu kendi kendine tekrar etme. "Sormak istedim", "bana sorabilirsiniz", "yardımcı olmak isterim", "sorunuz var mı?" gibi geçiştirici veya kaçamak cümleler kurma. Doğrudan bilgi ver!
3. Tamamen Türkçe, son derece akıcı, doğal, samimi ve yardımsever bir ton kullan.
4. Cevabını en fazla 2-3 cümle ile sınırla, kısa ve öz konuş.
5. Türkçe dil kurallarına kesinlikle uy, başka hiçbir dilden kelime kullanma."""

def load_model():
    global model
    if model is None:
        try:
            # 1. Ana modeli 4-bit (VRAM dostu) yükle
            bnb_config = BitsAndBytesConfig(
                load_in_4bit=True,
                bnb_4bit_quant_type="nf4",
                bnb_4bit_compute_dtype=torch.bfloat16,
            )
            base_model = AutoModelForCausalLM.from_pretrained(
                model_id,
                quantization_config=bnb_config,
                device_map={"": 0} # GPU'ya zorla
            )
            
            # 2. Eğittiğimiz LoRA ağırlıklarını (kampüs bilgisi) modelin üstüne giydir
            # DİKKAT: Kullanıcının projesi gereği BİRİNCİL ÖNCELİK eğitilmiş modelin kullanılmasıdır.
            if os.path.exists(adapter_path) and os.listdir(adapter_path):
                print("-> Eğitilmiş YYÜ Kampüs Beyni (LoRA) entegre ediliyor...")
                model = PeftModel.from_pretrained(base_model, adapter_path)
                print("-> BASARILI: Model kendi hafızasıyla (Fine-Tuned) yüklendi!")
            else:
                print("-> UYARI: Eğitilmiş LoRA bulunamadı, ham base_model kullanılıyor!")
                model = base_model
                
            model.eval()
        except Exception as e:
            print(f"HATA: Model yuklenirken hata: {e}")

# --- 3. API MODELLERİ (Flutter İletişimi) ---
class ChatMessageItem(BaseModel):
    role: str
    content: str

class ChatRequest(BaseModel):
    message: str
    history: Optional[List[ChatMessageItem]] = []

def retrieve_best_context(query, history=None, top_k=1, threshold=0.25):
    """Gelen soruyu dataset içinde TF-IDF veya canlı scraper servislerinde arar ve alakalı metinleri döndürür"""
    query_lower = query.lower()
    

    
    # 1. CANLI YEMEK MENÜSÜ ENTEGRASYONU
    if any(k in query_lower for k in ["yemek", "menü", "menu", "yemekhane", "bugün ne var"]):
        if yemek_scraper:
            try:
                today_menu = yemek_scraper.get_today_menu()
                if today_menu:
                    meals_text = ", ".join([f"{m['name']} ({m['calories']} kcal)" for m in today_menu['meals']])
                    menu_text = (
                        f"Tarih: {today_menu['date']} ({today_menu['weekday']})\n"
                        f"Bugünün Yemek Listesi: {meals_text}\n"
                        f"Toplam Kalori: {today_menu['total_calories']} kcal"
                    )
                    return "Canlı Yemekhane Menüsü", f"[Resmi Yemekhane Canlı Verisi]: {menu_text}"
                else:
                    return "Yemekhane Menüsü", "[Resmi Yemekhane Verisi]: Bugün için yemekhane menüsü henüz yayınlanmadı veya resmi sitede bulunmuyor."
            except Exception as e:
                print(f"Yemek scraper hatası: {e}")

    # 2. CANLI OTOBÜS SAATLERİ ENTEGRASYONU
    if any(k in query_lower for k in ["otobüs", "otobus", "sefer", "saatleri", "saati", "ulaşım", "dolmuş", "540", "541", "542", "543", "641", "e-1", "bf-100", "bk-400"]):
        if otobus_scraper:
            try:
                # Belirli bir hat sorgulanıyor mu?
                matched_route = None
                for route_code in ["540", "541", "542", "543", "641", "E-1", "BF-100", "BK-400"]:
                    if route_code.lower() in query_lower:
                        matched_route = route_code
                        break
                
                if matched_route:
                    schedule_text = otobus_scraper.format_schedule_text(matched_route)
                    return f"Canlı Otobüs Saatleri ({matched_route})", f"[Resmi Otobüs Saatleri Canlı Verisi]:\n{schedule_text}"
                else:
                    # Genel yaklaşan otobüsler (merkez veya YYÜ)
                    from_yyu = any(k in query_lower for k in ["gider", "kalkan", "dönüş", "merkez", "kampüsten"])
                    schedule_text = otobus_scraper.format_schedule_text(from_yyu=from_yyu)
                    return "Canlı Otobüs Saatleri", f"[Resmi Otobüs Saatleri Canlı Verisi]:\n{schedule_text}"
            except Exception as e:
                print(f"Otobüs scraper hatası: {e}")

    # 3. STATİK DATASET HİBRİT ARAMA (BM25 + Semantic)
    if not documents or bm25 is None or semantic_model is None:
        return "", ""
    
    # --- A. BM25 SKORLARI ---
    tokenized_query = tokenize_for_bm25(query)
    if not tokenized_query:
        return "", ""
    bm25_scores = bm25.get_scores(tokenized_query)
    
    # Normalize BM25 scores (0-1)
    bm25_max = np.max(bm25_scores) if np.max(bm25_scores) > 0 else 1.0
    bm25_norm = bm25_scores / bm25_max
    
    # --- B. SEMANTİK SKORLAR ---
    query_embedding = semantic_model.encode(query, convert_to_tensor=True)
    semantic_scores = util.cos_sim(query_embedding, document_embeddings)[0].cpu().numpy()
    
    # Normalize Semantic scores (already 0-1 but we ensure it)
    semantic_norm = np.clip(semantic_scores, 0, 1)
    
    # --- C. HİBRİT SKOR (Ağırlıklı Toplam) ---
    # %40 BM25 (Kelime), %60 Semantic (Anlam) ağırlığı
    hybrid_scores = (0.4 * bm25_norm) + (0.6 * semantic_norm)
    
    # En yüksek skorlu top_k sonucu al
    top_indices = np.argsort(hybrid_scores)[::-1][:top_k]
    best_score = hybrid_scores[top_indices[0]]
    
    # Birden fazla ilgili kaynağı birleştir
    combined_title = doc_titles[top_indices[0]]
    combined_text_parts = []
    
    # Hibrit eşik değeri (0-1 arası, örn: 0.2 çok düşük, 0.4 iyi bir eşleşme)
    threshold = 0.35 
    for idx in top_indices:
        if hybrid_scores[idx] >= threshold:
            text = documents[idx]
            combined_text_parts.append(f"[{doc_titles[idx]}]: {text}")
            
    # Yol tarifi, nerede, konum, yer, nasıl gidilir sorgularını yakalayıp bağlama zenginleştirme ekliyoruz:
    if any(k in query_lower for k in ["yol tarifi", "nasıl gidilir", "nerede", "yerini", "konumu", "nasıl ulaşırım"]):
        road_guide = (
            "\n\n[Kampüs İçi Yol Tarifi Rehberi]:\n"
            "Van Yüzüncü Yıl Üniversitesi'nin Mühendislik Fakültesi, Ziraat Fakültesi, Fen Fakültesi, İİBF ve diğer tüm fakülteleri "
            "ana yerleşke olan Zeve Kampüsü içerisindedir. Şehir merkezinden (Beşyol meydanından) kalkan belediye otobüsleri veya "
            "kampüs minibüsleri ile kampüse geldikten sonra, kampüs girişindeki ana caddeden düz devam ederek ve kampüs içi yönlendirme "
            "tabelalarını takip ederek tüm fakülte binalarına yürüyerek veya ring araçlarıyla kolayca ulaşabilirsiniz."
        )
        if best_score < threshold:
            return "Kampüs İçi Yol Tarifi", road_guide
        else:
            combined_text = "\n\n".join(combined_text_parts) + road_guide
            return combined_title, combined_text

    if best_score < threshold:
        return "", ""
    
    combined_text = "\n\n".join(combined_text_parts)
    return combined_title, combined_text

# --- 4. ENDPOINTLER ---
@app.post("/chat")
async def chat_endpoint(request: ChatRequest):
    # Eğer model RAM'de yoksa yükle (ilk istekte birkaç saniye sürer)
    load_model()
    if model is None:
        raise HTTPException(status_code=500, detail="Yapay zeka modeli başlatılamadı.")
        
    user_query = request.message
    chat_history = request.history or []
    
    # Yardımcı iç fonksiyon: Cevap dönmeden önce konumu otomatik ekler
    def send_response(response_text: str, confidence: float, matched_question: str, data: dict = None):
        return {
            "success": True,
            "response": response_text,
            "confidence": confidence,
            "matched_question": matched_question,
            "location": find_location_in_query(user_query),
            "data": data
        }
    
    # --- 0. DOĞRUDAN BYPASS KATMANI (100% Perfect Turkish & Zero Latency & Zero Halüsinasyon) ---
    query_lower = user_query.lower()
    has_greeting = any(re.search(rf'\b{re.escape(g)}\b', query_lower) for g in ["merhaba", "selam", "sa", "s.a.", "günaydın", "iyi günler", "mrb", "hi", "hello"])
    greeting_prefix = "Merhaba! " if has_greeting else ""


    # H. Yemekhane Menüsü (Canlı Scraper + Doğrudan Bypass)
    if any(k in query_lower for k in ["yemek", "menü", "menu", "yemekhane", "bugün ne var"]):
        if yemek_scraper:
            try:
                today_menu = yemek_scraper.get_today_menu()
                if today_menu:
                    meals_text = ", ".join([f"{m['name']} ({m['calories']} kcal)" for m in today_menu['meals']])
                    response_text = (
                        f"{greeting_prefix}Bugün ({today_menu['date']}, {today_menu['weekday']}) yemekhanede şu leziz menü yer almaktadır:\n\n"
                        f"🍽️ {meals_text}\n"
                        f"🔥 Toplam Kalori: {today_menu['total_calories']} kcal\n\n"
                        f"Şimdiden afiyet olsun!"
                    )
                    # Flutter tarafındaki _MealList widget'ını tetiklemek için raw datayı gönderiyoruz
                    return send_response(response_text, 1.0, "Canlı Yemekhane Menüsü", data=[today_menu])
                else:
                    response_text = (
                        f"{greeting_prefix}Van Yüzüncü Yıl Üniversitesi resmi yemekhane menüsü bugün için henüz yayınlanmamıştır veya şu anda üniversitenin resmi web sitesinde güncel liste bulunmamaktadır. "
                        f"Menüler genellikle hafta içi her gün sabah saatlerinde güncellenmektedir."
                    )
                return send_response(response_text, 1.0, "Canlı Yemekhane Menüsü")
            except Exception as e:
                print(f"Yemekhane bypass hatası: {e}")

    # I. Canlı Otobüs Seferleri (Canlı Scraper + Doğrudan Bypass)
    elif any(k in query_lower for k in ["otobüs", "otobus", "sefer", "saatleri", "saati", "dolmuş", "540", "541", "542", "543", "641", "e-1", "bf-100", "bk-400"]):
        if otobus_scraper:
            try:
                matched_route = None
                for route_code in ["540", "541", "542", "543", "641", "E-1", "BF-100", "BK-400"]:
                    if route_code.lower() in query_lower:
                        matched_route = route_code
                        break
                
                if matched_route:
                    schedule_text = otobus_scraper.format_schedule_text(matched_route)
                    response_text = f"{greeting_prefix}Resmi canlı otobüs saatleri ({matched_route} hattı) şu şekildedir:\n\n{schedule_text}"
                    
                    bus_data = {
                        "type": f"bus_{matched_route}",
                        "route": matched_route,
                        "direction": "YYÜ'ye Giden", # Basitleştirilmiş
                        "buses": [{"time": "Belirtilmemiş", "status": "Yolda", "remaining": "Bilinmiyor"}] # Scraper tam veri dönmüyorsa boş geçmeyelim
                    }
                    return send_response(response_text, 1.0, "Canlı Otobüs Saatleri", data=bus_data)
                else:
                    from_yyu = any(k in query_lower for k in ["gider", "kalkan", "dönüş", "merkez", "kampüsten"])
                    schedule_text = otobus_scraper.format_schedule_text(from_yyu=from_yyu)
                    response_text = f"{greeting_prefix}Resmi canlı otobüs kalkış saatleri şu şekildedir:\n\n{schedule_text}"
                    return send_response(response_text, 1.0, "Canlı Otobüs Saatleri")
            except Exception as e:
                print(f"Otobüs bypass hatası: {e}")




    
    # Çok kısa veya zamir içeren sorularda önceki bağlamı RAG aramasına dahil et (Coreference Resolution basit versiyonu)
    search_query = user_query
    if len(user_query.split()) <= 3 and chat_history:
        # Son kullanıcı sorusunu da aramaya dahil edelim ki konu bütünlüğü kopmasın
        last_user_msg = next((m.content for m in reversed(chat_history) if m.role == "user"), "")
    # ======= RAG + EĞİTİLMİŞ MODEL (Tek Geçerli Akış) =======
    matched_title, retrieved_text = retrieve_best_context(search_query)
    
    # RAG bağlamını uzatıyoruz (Eskiden timeout için kısmıştık ama artık süre sorunumuz yok)
    if retrieved_text:
        clean_context = re.sub(r'\[.*?\]:\s*', '', retrieved_text)
        clean_context = re.sub(r'\s+', ' ', clean_context).strip()
        # Modeli doyuracak kadar bilgi (yaklaşık 1000 karakter) verelim
        if len(clean_context) > 1000:
            clean_context = clean_context[:1000]
        context_text = f"Bilgi: {clean_context}"
    else:
        context_text = "Bu konuda veritabanında bilgi bulunamadı."
    
    # Model yüklü mü kontrol et
    load_model()
    if model is None:
        # Model yüklenemezse genel rehber dön
        general_response = (
            f"{greeting_prefix}Van Yüzüncü Yıl Üniversitesi (YYÜ) Kampüs Danışmanıyım. "
            "Sorduğunuz soruya dair veritabanımızda özel bir eşleşme bulamadım. "
            "Detaylı bilgi için yyu.edu.tr adresini ziyaret edebilirsiniz."
        )
        return send_response(general_response, 0.5, "Genel Kampüs Rehberi")
    
    # EĞİTİM VERİSİNDEKİ ORİJİNAL SİSTEM YÖNERGESİ + RAG BAĞLAMI
    # Model sadece kısa sorularla eğitildiği için bağlamı (RAG) User mesajına koyarsak çöküyor.
    # Bu yüzden bağlamı System mesajının sonuna ekliyoruz.
    original_system_prompt = (
        "Siz Van Yüzüncü Yıl Üniversitesi (YYÜ) resmi Kampüs Danışmanı yapay zeka asistanısınız. "
        "Öğrencilerle son derece samimi, güler yüzlü, nazik ve Türkçe karakterleri mükemmel kullanarak sohbet edin. "
        "Sorulan sorulara resmi web sitesi verilerine dayanarak, doğrudan ve bir insan gibi doğal cümlelerle cevap verin. "
        "Eğer konuyla ilgili resmi bilginiz yoksa bunu uydurmak yerine kibarca yönlendirme yapın."
        f"\n\nİşte soruyu cevaplarken kullanman gereken GÜNCEL BİLGİ:\n{context_text}"
    )
    
    messages = [
        {"role": "system", "content": original_system_prompt},
        {"role": "user", "content": user_query}  # Tıpkı eğitimdeki gibi sadece soru
    ]
    
    prompt = tokenizer.apply_chat_template(messages, tokenize=False, add_generation_prompt=True)
    inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
    
    terminators = [
        tokenizer.eos_token_id,
        tokenizer.convert_tokens_to_ids("<|eot_id|>")
    ]
    
    import time
    token_count = inputs['input_ids'].shape[1]
    print(f"-> [LLM MOD] Token sayısı: {token_count}, generate başlıyor...")
    start_gen = time.time()
    
    with torch.no_grad():
        outputs = model.generate(
            **inputs,
            max_new_tokens=400,
            do_sample=True,
            temperature=0.3,         # Sonsuz döngüye (loop) girmemesi için hafif varyans eklendi
            top_p=0.9,
            repetition_penalty=1.2,  # Tekrar döngüsünü kırmak için güçlendirilmiş ceza
            eos_token_id=terminators,
            pad_token_id=tokenizer.pad_token_id
        )
    
    gen_time = time.time() - start_gen
    print(f"-> [LLM MOD] Generate BİTTİ! Süre: {gen_time:.2f} saniye")
    
    input_length = inputs["input_ids"].shape[1]
    generated_tokens = outputs[0][input_length:]
    response_text = tokenizer.decode(generated_tokens, skip_special_tokens=True).strip()
    
    # Boş veya çok kısa cevap kontrolü
    if len(response_text) < 10:
        if matched_title:
            response_text = f"{matched_title} hakkında detaylı bilgi için yyu.edu.tr adresini ziyaret edebilirsiniz."
        else:
            response_text = "Bu konuda size yardımcı olmak isterim. Lütfen sorunuzu biraz daha detaylandırır mısınız?"
    
    response_text = f"{greeting_prefix}{response_text}"
    
    # Modelin cevabı başarıyla üretildi, şimdi temizleme aşamasına geçiliyor...
    
    # Türkçe olmayan kelimeleri ve dil kaçamaklarını temizleme fonksiyonu
    def clean_turkish_response(text: str) -> str:
        import re
        text = re.sub(r'&amp;|&[a-z]+;', '', text)
        text = re.sub(r'[\u3000-\u9fff\u4e00-\u9faf]', '', text)  # CJK temizle
        
        # Llama'nın bazen yaptığı yaygın İngilizce/İspanyolca/yabancı dil kaçamaklarını düzelt
        corrections = {
            r'\brelacionlı\b': 'ilgili',
            r'\brelacionli\b': 'ilgili',
            r'\brelacionado\b': 'ilgili',
            r'\brelacionados\b': 'ilgili',
            r'\brelacion\b': 'ilişki',
            r'\brelación\b': 'ilişki',
            r'\brelational\b': 'ilişkisel',
            r'\brelation\b': 'ilişki',
            r'\blocated\b': 'yer alan',
            r'\brequired\b': 'gereklidir',
            r'\bafterwards\b': 'daha sonra',
            r'\baddress\'i\b': 'adresi',
            r'\baddress\b': 'adres',
            r'\binformation\b': 'bilgi',
            r'\bcampusumun\b': 'kampüsümüzün',
            r'\bcampusumuz\b': 'kampüsümüz',
            r'\bcampusümüz\b': 'kampüsümüz',
            r'\bcampus\b': 'kampüs',
            r'\brealizar\b': 'gerçekleştirilen',
            r'\brealizado\b': 'gerçekleştirilen',
            r'\bthank ediyorsunuz\b': 'teşekkür ediyoruz',
            r'\bthank ediyoruz\b': 'teşekkür ediyoruz',
            r'\bthank ediyor\b': 'teşekkür ediyor',
            r'\bwithininda\b': 'bünyesinde',
            r'\bourselvesdir\b': 'biziz',
            r'\bourselves\b': 'biz',
            r'\bheadquarters\'inin\b': 'merkezinin',
            r'\bheadquarters\b': 'merkez',
            r'\bherekiyoruz\b': 'bekliyoruz',
            r'\bhere\b': 'burada',
            r'\bwelcoming\b': 'hoş geldiniz',
            r'\bchoices\'ine\b': 'tercihlerine',
            r'\bchoices\b': 'tercihleri',
            r'\bchoice\b': 'tercih',
            r'\bprocessin\b': 'sürecin',
            r'\bprocess\b': 'süreç',
            r'\bour\b': 'bizim',
            r'\blocationu\b': 'konumu',
            r'\blocation\b': 'konum',
            r'\bin the city of Van\'dadır\b': 'Van şehrindedir',
            r'\bin the city of\b': 'şehrinde',
            r'\bcity of\b': 'şehri',
            r'\bcity\b': 'şehir',
            r'\busername\b': 'kullanıcı adı',
            r'\bpassword\b': 'şifre',
            r'\bpasswords\b': 'şifreler',
            r'\bpassword\'ları\b': 'şifreleri',
            r'\bpasswordları\b': 'şifreleri',
            r'\binformationa\b': 'bilgiye',
            r'\binformation\b': 'bilgi',
            r'\bairin\b': 'girin',
            r'\bparticipating\b': 'anlaşmalı',
            r'\bourselvesde\b': 'kampüsümüzde',
            r'\bourselvesda\b': 'kampüsümüzde',
            r'\binformación\b': 'bilgi',
            r'\binformacion\b': 'bilgi',
            r'\bopen\b': 'açık',
            r'\bclosed\b': 'kapalı',
            r'\busage\b': 'kullanımı',
            r'\bdetailed\b': 'detaylı',
            r'\binternational relations\b': 'uluslararası ilişkiler',
            r'\binternational\b': 'uluslararası',
            r'\brelations\b': 'ilişkiler',
            r'\bestudiantes\b': 'öğrenciler',
            r'\bestudiante\b': 'öğrenci',
            r'\beurope\'daki\b': 'Avrupa\'daki',
            r'\beurope\'de\b': 'Avrupa\'da',
            r'\beurope\b': 'Avrupa',
            r'\beuropa\'daki\b': 'Avrupa\'daki',
            r'\beuropa\'da\b': 'Avrupa\'da',
            r'\beuropa\b': 'Avrupa',
            r'\byearly\b': 'yıllık',
            r'\bcoordination office\b': 'Uluslararası İlişkiler Ofisi',
            r'\bcoordination\b': 'Koordinasyonu',
            r'\boffice\b': 'Ofisi',
        }
        
        for pattern, replacement in corrections.items():
            text = re.sub(pattern, replacement, text, flags=re.IGNORECASE)
            
        # Bazı garip karakter dizilimlerini ve kalıpları düzelt
        text = text.replace("yer alan'tur", "yer almaktadır")
        text = text.replace("Fakülte ourselves yer alan'tur", "Fakültemiz kampüsümüzde yer almaktadır")
        text = text.replace("ne yazık ki çok geliyorsun", "memnuniyetle yardımcı olabilirim")
        text = text.replace("Van-Yurt University'se", "Van Yüzüncü Yıl Üniversitesi'ne")
        text = text.replace("Van-Yurt University", "Van Yüzüncü Yıl Üniversitesi")
        text = text.replace("İyilikli bir iş olarak", "Ek bir bilgi olarak")
        text = text.replace("iyilikli bir iş olarak", "ek bir bilgi olarak")
        text = text.replace("sorununuzda bulunmak istedim", "yardımcı olmak isterim")
        text = text.replace("sorunuzda bulunmak istedim", "yardımcı olmak isterim")
        text = text.replace("Kampüs kampüsümüzde", "Kampüsümüzde")
        text = text.replace("kampüs kampüsümüzde", "kampüsümüzde")
        
        # Eğer model kullanıcıya sorusunu tekrar sorduysa (yani ilk 120 karakter içinde soru işareti varsa), o kısmı temizle:
        q_index = text.find('?')
        if 0 < q_index < 120 and q_index < len(text) - 1:
            text = text[q_index + 1:].strip()
            if text and text[0].islower():
                text = text[0].upper() + text[1:]
        
        # Eğer kullanıcı kendisi selamlaşmadıysa, modelin her söze otomatik "Merhaba!" veya "Selam!" ile başlamasını önle:
        query_lower = user_query.lower()
        has_greeting = any(re.search(rf'\b{re.escape(g)}\b', query_lower) for g in ["merhaba", "selam", "sa", "s.a.", "günaydın", "iyi günler", "mrb", "hi", "hello"])
        if not has_greeting:
            text = re.sub(r'^(merhabalar|merhaba|selamlar|selam)\s*[!,.-]*\s*', '', text, flags=re.IGNORECASE)
            if text and text[0].islower():
                text = text[0].upper() + text[1:]
                
        text = re.sub(r'\s{2,}', ' ', text).strip()
        return text

    response_text = clean_turkish_response(response_text)
    
    # İNGİLİZCE DİL KAYMASI KONTROLÜ (Fail-Safe Shield)
    english_words = {"the", "and", "are", "is", "of", "to", "in", "for", "on", "with", "at", "by", "from", "that", "this", "it", "you", "we", "our", "been", "have", "has", "was", "were", "be"}
    response_words = set(re.findall(r'\b[a-zA-Z]+\b', response_text.lower()))
    if len(response_words.intersection(english_words)) >= 2:
        print("⚠️ UYARI: Dil kayması tespit edildi, fail-safe devreye girdi!")
        if matched_title:
            response_text = f"Van Yüzüncü Yıl Üniversitesi bünyesindeki {matched_title} hakkında resmi kayıtlarımızda yer alan bilgileri sizinle paylaşıyorum. Detaylar ve güncel süreçler için ilgili birimin resmi web sayfasını ziyaret edebilir veya öğrenci işlerine danışabilirsiniz."
        else:
            response_text = "Van Yüzüncü Yıl Üniversitesi Zeve Kampüsü hakkında sorduğunuz soruya dair en güncel ve doğru bilgilere resmi web sitemiz (yyu.edu.tr) üzerinden ulaşabilir veya ilgili akademik birimin öğrenci işleri ofisinden destek alabilirsiniz."
    
    # AKILLI HİBRİT GERİ ÇEKİLME KATMANI (Hybrid RAG Fallback)
    # Eğer model boş veya sadece "bana sorabilirsiniz", "yardımcı olmak isterim" gibi geçiştirici cümleler ürettiyse,
    # doğrudan resmi veritabanındaki mükemmel tanımları sunarak %100 doğruluk ve zenginlik sağlıyoruz:
    response_lower = response_text.lower()
    if any(k in response_lower for k in ["bana sorabilirsiniz", "bana sorun", "sorunuzu sorabilirsiniz", "yardımcı olabilirim", "istiyorsanız sorun"]):
        query_lower = user_query.lower()
        if "erasmus" in query_lower:
            response_text = "Erasmus+ programı, Van Yüzüncü Yıl Üniversitesi öğrencilerinin Avrupa'daki anlaşmalı üniversitelerde 1 veya 2 dönem boyunca eğitim görmelerine veya yurt dışında staj yapmalarına olanak sağlayan resmi bir uluslararası değişim programıdır. Başvurular ve dil yeterlilik sınavları her yıl Uluslararası İlişkiler Koordinatörlüğü tarafından düzenlenir."
        elif "obs" in query_lower or "öğrenci bilgi" in query_lower:
            response_text = "Öğrenci Bilgi Sistemi'ne (OBS) giriş yapmak için obs.yyu.edu.tr adresine gitmeniz gerekmektedir. Sisteme e-Devlet Kapısı üzerinden veya öğrenci numaranız ve şifrenizle doğrudan giriş sağlayabilirsiniz."
        elif "yurt" in query_lower or "barınma" in query_lower:
            response_text = "Van Yüzüncü Yıl Üniversitesi Zeve Kampüsü içerisinde KYK'ya bağlı Melikşah, Aişe Sıddıka ve Van KYK yurtları yer almaktadır. Yurt başvuruları her eğitim yılı başında e-Devlet üzerinden Gençlik ve Spor Bakanlığı takvimine göre resmi olarak gerçekleştirilir."
        elif "spor" in query_lower:
            response_text = "Van Yüzüncü Yıl Üniversitesi Zeve Kampüsü içerisinde kapalı spor salonu, açık ve kapalı halı sahalar, basketbol ve voleybol sahaları, tenis kortları, fitness salonu ve bisiklet yolları yer almaktadır. Spor tesislerimiz tüm öğrencilerimizin ve personelimizin kullanımına açıktır."
    
    if len(response_text) < 10:
        response_text = "Merhaba! Bu konuda size yardımcı olmak isterim. Lütfen sorunuzu biraz daha belirtir misiniz?"
    
    return send_response(response_text, 1.0, matched_title if matched_title else "Genel bilgi")

@app.get("/health")
async def health_check():
    return {"status": "ok", "message": "YYU Kampüs Danışmanı API Aktif"}

@app.get("/info")
async def get_info():
    return {
        "model": "meta-llama/Llama-3.2-3B-Instruct (Fine-Tuned)",
        "rag_status": "active (BM25Okapi + Chunking)",
        "dataset_chunks": len(documents)
    }

if __name__ == "__main__":
    print("API Sunucusu baslatiliyor... Flutter ile baglanabilirsiniz.")
    uvicorn.run("api:app", host="0.0.0.0", port=5001, reload=False)
