# 🎓 YYÜ Kampüs Danışmanı

Van Yüzüncü Yıl Üniversitesi öğrencileri için yapay zeka destekli akıllı kampüs asistanı.

![Python](https://img.shields.io/badge/Python-3.10+-blue?logo=python)
![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![FastAPI](https://img.shields.io/badge/FastAPI-0.115-009688?logo=fastapi)
![LLaMA](https://img.shields.io/badge/LLaMA_3.2-3B_LoRA-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## 📖 Proje Hakkında

YYÜ Kampüs Danışmanı, Van Yüzüncü Yıl Üniversitesi öğrencilerinin kampüs yaşamı hakkında her türlü soruyu **doğal dilde** sorabilecekleri, **Türkçe yapay zeka** destekli bir chatbot uygulamasıdır.

### ✨ Temel Özellikler

- 🤖 **Fine-Tuned LLaMA 3.2 3B** — Kampüs verileriyle eğitilmiş LoRA adaptörü
- 🔍 **Hibrit RAG Arama** — BM25 (kelime) + Semantik (anlam) vektör araması
- 🍽️ **Canlı Yemekhane Menüsü** — Günlük menü web scraping ile otomatik çekilir
- 🚌 **Canlı Otobüs Saatleri** — Belediye hat sefer saatleri anlık sorgulanır
- 🗺️ **Kampüs Haritası** — OpenStreetMap tabanlı interaktif harita ve yol tarifi
- 🎤 **Sesli Asistan** — Konuşarak soru sorma ve sesli cevap alma (TTS/STT)
- 🌙 **Karanlık/Açık Mod** — Kullanıcı tercihli tema desteği
- 💬 **Sohbet Geçmişi** — Mesajlar cihaz üzerinde saklanır

## 🏗️ Mimari

```
┌──────────────────┐     HTTP/REST      ┌──────────────────────┐
│   Flutter App    │ ◄──────────────► │   FastAPI Backend     │
│   (Mobil/Web)    │                    │                      │
│                  │                    │  ┌── RAG Engine ──┐  │
│  • Chat UI       │                    │  │ BM25 + Semantic│  │
│  • Harita (OSM)  │                    │  └────────────────┘  │
│  • TTS / STT     │                    │  ┌── LLaMA 3.2 ──┐  │
│  • Tema Yönetimi │                    │  │ + LoRA Adapter │  │
│                  │                    │  └────────────────┘  │
│                  │                    │  ┌── Scrapers ────┐  │
│                  │                    │  │ Yemek │ Otobüs │  │
│                  │                    │  └────────────────┘  │
└──────────────────┘                    └──────────────────────┘
```

## 📁 Proje Yapısı

```
KAMPUS/
├── backend/
│   ├── api.py                  # FastAPI ana sunucu
│   ├── yemek_scraper.py        # Yemekhane menüsü web scraper
│   ├── otobus_scraper.py       # Otobüs seferleri web scraper
│   ├── yyu_scraper.py          # YYÜ web sitesi scraper
│   ├── train.py                # Model eğitim scripti
│   ├── prepare_data.py         # Veri hazırlama scripti
│   ├── requirements.txt        # Python bağımlılıkları
│   ├── dataset.jsonl           # RAG veri seti (gitignore'da)
│   └── yyu_model_final/        # LoRA ağırlıkları (gitignore'da)
│
├── frontend/
│   ├── lib/
│   │   ├── main.dart                  # Ana uygulama ve chat ekranı
│   │   ├── local_chatbot_service.dart # API iletişim servisi
│   │   ├── campus_map_screen.dart     # Kampüs haritası ekranı
│   │   ├── campus_locations.dart      # Kampüs lokasyon verileri
│   │   ├── splash_screen.dart         # Açılış ekranı
│   │   ├── theme_config.dart          # Tema yapılandırması
│   │   └── chat_storage_service.dart  # Sohbet kaydetme servisi
│   ├── assets/images/                 # Logo ve görseller
│   └── pubspec.yaml                   # Flutter bağımlılıkları
│
├── .gitignore
└── README.md
```

## 🚀 Kurulum ve Çalıştırma

### Gereksinimler

- **Python** 3.10+
- **Flutter** 3.x (SDK)
- **CUDA** destekli GPU (model çalıştırma için, minimum 6GB VRAM)

### 1. Backend Kurulumu

```bash
cd backend

# Sanal ortam oluştur (önerilir)
python -m venv venv
venv\Scripts\activate  # Windows
# source venv/bin/activate  # Linux/macOS

# Bağımlılıkları kur
pip install -r requirements.txt

# API sunucusunu başlat
python api.py
```

> ⚠️ **Not:** İlk çalıştırmada LLaMA 3.2 3B modeli Hugging Face'den otomatik indirilir (~6GB). `dataset.jsonl` ve eğitilmiş LoRA ağırlıkları (`yyu_model_final/`) GitHub'a dahil değildir, bunları ayrıca temin etmeniz gerekir.

### 2. Frontend Kurulumu

```bash
cd frontend

# Bağımlılıkları yükle
flutter pub get

# Uygulamayı çalıştır (Android emülatör veya fiziksel cihaz)
flutter run

# Web üzerinde çalıştırmak için:
flutter run -d chrome
```

### 3. API Bağlantısı

Frontend, varsayılan olarak `http://localhost:5001` adresindeki backend API'ye bağlanır.  
Android emülatörde çalıştırıyorsanız `10.0.2.2:5001` kullanmanız gerekebilir.  
`frontend/lib/local_chatbot_service.dart` dosyasından `baseUrl` değerini değiştirebilirsiniz.

## 🛠️ Kullanılan Teknolojiler

| Katman | Teknoloji | Açıklama |
|--------|-----------|----------|
| **Frontend** | Flutter / Dart | Mobil & Web UI |
| **Backend** | FastAPI / Python | REST API sunucusu |
| **Yapay Zeka** | LLaMA 3.2 3B + LoRA | Fine-tuned dil modeli |
| **Arama** | BM25 + Sentence-Transformers | Hibrit RAG sistemi |
| **Harita** | Flutter Map + OpenStreetMap | İnteraktif kampüs haritası |
| **Scraping** | BeautifulSoup4 | Canlı veri çekimi |
| **Ses** | flutter_tts + speech_to_text | Sesli asistan |

## 📸 Ekran Görüntüleri

> Ekran görüntüleri eklenecek.

## 👩‍💻 Geliştirici

**Betül** — Van Yüzüncü Yıl Üniversitesi, Bilgisayar Mühendisliği

## 📄 Lisans

Bu proje akademik amaçlarla geliştirilmiştir.
