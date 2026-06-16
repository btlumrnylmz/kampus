# VAN YÜZÜNCÜ YIL ÜNİVERSİTESİ
## MÜHENDİSLİK FAKÜLTESİ
### BİLGİSAYAR MÜHENDİSLİĞİ BÖLÜMÜ

**Yüzüncü Yıl Üniversitesi Kampüs Chatbotu**  
(Campus Chatbot for Van Yüzüncü Yıl University)

**LİSANS BİTİRME PROJESİ RAPORU**

**Hazırlayan:** Betül Ümran YILMAZ  
**Danışman:** Dr. Öğr. Üyesi Taner UÇKAN  
**Yıl:** 2026

---

## İÇİNDEKİLER
1. Giriş
2. Araştırmanın Amacı
3. Kuramsal Temeller ve İlgili Araştırmalar
4. Materyal ve Metot
5. Sistem Mimarisi
6. Veri Seti ve Model Eğitimi (Fine-Tuning)
7. Karşılaşılan Problemler ve Geliştirilen Çözümler
8. Sonuç

---

## 1. GİRİŞ
Günümüzde yapay zeka teknolojilerinin hızla gelişmesiyle birlikte, chatbot sistemleri eğitim kurumlarında öğrencilere hızlı ve etkili bilgi sağlama amacıyla yaygın olarak kullanılmaya başlanmıştır. Üniversite kampüslerinde öğrencilerin sıkça sorduğu sorulara anında yanıt verebilen, sesli etkileşim destekli chatbot sistemleri, hem öğrenci memnuniyetini artırmakta hem de idari birimlerin iş yükünü azaltmaktadır.

Bu proje kapsamında, Van Yüzüncü Yıl Üniversitesi (YYÜ) için özel olarak tasarlanmış, sesli giriş ve çıkış özelliklerine sahip, kendi dil modeli ile eğitilmiş bir kampüs danışmanlığı chatbotu geliştirilmiştir. Sistem, Flutter framework'ü kullanılarak mobil platformlar için geliştirilmiş olup, öğrencilerin kampüs hakkındaki sorularına Türkçe dilinde doğal bir şekilde yanıt verebilmektedir.

## 2. ARAŞTIRMANIN AMACI
Bu projenin temel amacı, YYÜ öğrencilerinin kampüs hakkındaki sorularına hızlı ve doğru yanıtlar verebilen, sesli etkileşim destekli bir chatbot sistemi geliştirmektir. Projenin spesifik amaçları şunlardır:
1. Flutter framework'ü kullanarak mobil uygulama (Android/iOS) geliştirmek. *(Arayüz görselleri eklenecektir)*
2. Türkçe dilinde çalışan, YYÜ web sitesinden toplanan verilerle eğitilmiş (Fine-Tuned) bir yapay zeka modeli oluşturmak.
3. Sesli giriş (speech-to-text) ve sesli çıkış (text-to-speech) özelliklerini entegre etmek.
4. Web scraping ile YYÜ web sitesinden veri seti hazırlamak ve modeli LoRA fine-tuning ile eğitmek.
5. Canlı veri pluginleri (yemekhane menüsü, otobüs güzergahları) ile anlık bilgi sağlamak.
6. 4GB VRAM gibi kısıtlı donanım kaynaklarında Büyük Dil Modellerini (LLM) optimize ederek çalıştırmak.

## 3. MATERYAL VE METOT

### 3.1. Kullanılan Teknolojiler
* **Mobil Framework:** Flutter (Dart)
* **Sesli Etkileşim:** `speech_to_text` ve `flutter_tts`
* **Backend API:** Python (FastAPI / Uvicorn)
* **Ana Dil Modeli:** Meta Llama 3.2 3B Instruct
* **Model Eğitimi:** LoRA (PEFT), 4-bit Quantization (BitsAndBytes), Unsloth
* **Arama Motoru (RAG):** TF-IDF (BM25Okapi) ve Semantic Search (MiniLM-L12-v2)
* **Veri Toplama:** Python Selenium & BeautifulSoup

### 3.2. Sistem Mimarisi
Sistem dört ana bileşenden oluşmaktadır:
1. **Mobil Uygulama (Flutter):** Kullanıcı arayüzü, sesli giriş/çıkış ve sohbet ekranı.
2. **API Servisi (FastAPI):** Flutter uygulamasından gelen istekleri karşılayan, LLaMA modelini ve veri kazıma scriptlerini asenkron olarak yöneten sunucu.
3. **Hibrit RAG Motoru:** Kullanıcının sorusunu analiz ederek `dataset.jsonl` veritabanından hem kelime bazlı (BM25) hem de anlamsal (Cosine Similarity) olarak en uygun bağlamı süzen sistem.
4. **Canlı Veri Kazıyıcılar:** YYÜ Otobüs saatleri ve Yemekhane menüsü gibi günlük değişen verileri anlık olarak çeken otonom modüller.

## 4. MODEL EĞİTİMİ VE İTERASYONLAR
Proje süresince 4GB VRAM kısıtlaması altında optimum kaliteyi yakalamak için çeşitli modeller denenmiştir:

1. **GPT-2 Small Turkish:** Türkçe karakter encoding sorunları ve düşük yanıt kalitesi nedeniyle terk edilmiştir.
2. **BERT Turkish:** Sadece soru-cevap eşleştirmesinde başarılı olmuş, üretken (generative) yanıt yeteneği olmadığı için elenmiştir.
3. **TinyLlama 1.1B:** İngilizce ağırlıklı mimarisi sebebiyle Türkçe sorularda ciddi halüsinasyonlar (uydurma) tespit edilmiştir.
4. **Llama 3.2 3B Instruct (Nihai Model):** Meta'nın güncel mimarisi kullanılarak, 4-bit QLoRA quantizasyon tekniği ile 4GB VRAM'e sığdırılmış ve `dataset.jsonl` verileriyle eğitilmiştir. RAG mimarisi ile entegre edildiğinde akademik kalitede, halüsinasyonsuz ve Türkçe dil bilgisi kurallarına uygun yanıtlar üretmeyi başarmıştır.

## 5. KARŞILAŞILAN PROBLEMLER VE GELİŞTİRİLEN ÇÖZÜMLER

Proje geliştirme aşamasında özellikle dil modelinin donanımsal sınırları ve metin üretim mantığından kaynaklanan çeşitli akademik problemler tespit edilmiş ve çözülmüştür:

**1. Özel İsimlerin Bozulması (N-Gram Problemi):**
* **Problem:** Modelin sonsuz döngüye (repetition loop) girmesini engellemek için başlangıçta `no_repeat_ngram_size=3` filtresi uygulanmıştır. Ancak bu filtre, "Van Yüzüncü Yıl" gibi 3 kelimelik özel isimlerin aynı cevap içinde ikinci kez yazılmasını donanımsal olarak yasaklamış, bu da modelin yasağı delmek için "Van Yüzücü Yıl" gibi hatalı (typo) isimler uydurmasına yol açmıştır.
* **Çözüm:** N-Gram filtresi tamamen kaldırılarak yerine `temperature=0.3` ve `repetition_penalty=1.1` gibi daha organik varyans (sampling) parametreleri getirilmiş, böylece hem döngüler kırılmış hem de kurum isimlerinin hatasız yazılması sağlanmıştır.

**2. Veri Okuma Kapasitesi (Context Window) Sınırı:**
* **Problem:** İlk aşamalarda frontend tarafındaki HTTP zaman aşımlarını (Timeout) engellemek adına RAG sisteminin okuduğu belge uzunluğu 200 karakterle sınırlandırılmıştır. Bu durum, modelin eksik bilgiyle cevap üretmesine ve ulaşım gibi sorularda halüsinasyonlara sebep olmuştur.
* **Çözüm:** Flutter tarafında zaman aşımı sınırı 300 saniyeye çıkarılmış, API tarafında ise okuma sınırı 1000 karaktere yükseltilmiştir. Bu sayede model belgelerin tamamını okuyup, cümlenin ortasında kesilmeyen tam kapsamlı yanıtlar (örneğin Burs ve Erasmus bilgilerini maddeler halinde) üretmeye başlamıştır.

## 6. SONUÇ
Bu projede, Van Yüzüncü Yıl Üniversitesi öğrencileri için yapay zeka destekli, tamamen lokal çalışan ve kurumsal verilerle entegre bir kampüs danışman chatbotu başarıyla geliştirilmiştir. 

Proje; Flutter ile çoklu platform destekli modern bir mobil uygulama sunmuş, sesli giriş/çıkış entegrasyonu sağlamış ve 500 sayfalık kurumsal veriyi başarılı bir hibrit RAG mimarisiyle harmanlamıştır. Sınırlı donanım kaynaklarına (8GB RAM, 4GB VRAM) rağmen 3 Milyar parametreli bir modelin (Llama 3.2 3B) başarılı bir şekilde çalıştırılabileceği, optimize edilebileceği ve canlı veri entegrasyonlarıyla desteklenebileceği kanıtlanmıştır. Geliştirilen bu sistem, öğrenci memnuniyetini artırırken, düşük donanımlı cihazlarda yerel LLM kullanımının fizibilitesini akademik düzeyde ispatlamaktadır.

*(ÖĞRENCİ NOTU: Raporun bu kısmından sonrasına mobil uygulamanın ekran görüntüleri, RAG arama süreçlerinin terminal logları ve canlı yemekhane test sonuçlarının görselleri eklenecektir.)*
