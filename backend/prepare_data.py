import json
import os
import random

print("-> Sohbet formatında Veri Augmentasyon Scripti başlatıldı...")

if not os.path.exists('dataset.jsonl'):
    print("HATA: 'dataset.jsonl' dosyasi bu klasorde bulunamadi!")
    exit()

SYSTEM_PROMPT = (
    "Siz Van Yüzüncü Yıl Üniversitesi (YYÜ) resmi Kampüs Danışmanı yapay zeka asistanısınız. "
    "Öğrencilerle son derece samimi, güler yüzlü, nazik ve Türkçe karakterleri mükemmel kullanarak sohbet edin. "
    "Sorulan sorulara resmi web sitesi verilerine dayanarak, doğrudan ve bir insan gibi doğal cümlelerle cevap verin. "
    "Eğer konuyla ilgili resmi bilginiz yoksa bunu uydurmak yerine kibarca yönlendirme yapın."
)

formatted_data = []
gecersiz_satir = 0

# Soru şablonu üretici
def generate_conversational_pairs(title, content, url):
    pairs = []
    
    # 1. Şablon: Resmi ve doğrudan bilgi alma
    q1 = random.choice([
        f"Van Yüzüncü Yıl Üniversitesi {title} hakkında bilgi alabilir miyim?",
        f"Kampüste {title} ile ilgili detaylar nelerdir?",
        f"{title} hakkında güncel bir bilgi verir misin?"
    ])
    a1 = (
        f"Elbette, yardımcı olayım! Van Yüzüncü Yıl Üniversitesi resmi kayıtlarına göre "
        f"'{title}' konusuyla ilgili detaylar şu şekildedir:\n\n{content}\n\n"
        f"Umarım bu bilgi sizin için faydalı olur! Başka bir sorunuz varsa seve seve cevaplarım."
    )
    pairs.append((q1, a1))

    # 2. Şablon: Samimi / Sohbet havası
    q2 = random.choice([
        f"Merhaba! Bana {title} konusunda yardımcı olur musunuz? Nasıl işliyor süreç?",
        f"Selam, {title} hakkında bir sorum olacaktı. Bilgi verebilir misiniz?",
        f"İyi günler, YYÜ'de {title} konusu hakkında nasıl bilgi edinebilirim?"
    ])
    a2 = (
        f"Merhaba! Tabii ki, YYÜ Kampüs Danışmanı olarak size seve seve yardımcı olurum. "
        f"'{title}' ile ilgili güncel süreç ve detaylar şu şekildedir:\n\n{content}\n\n"
        f"Kampüsle ilgili merak ettiğiniz başka bir konu olursa buradayım!"
    )
    pairs.append((q2, a2))

    # 3. Şablon: Kısa ve doğrudan doğal soru (Arama motoru tarzı)
    # Başlığa göre soruyu şekillendiriyoruz
    clean_title = title.lower()
    if any(x in clean_title for x in ["nerede", "ulaşım", "yer", "adres"]):
        q3 = f"{title}?"
    elif any(x in clean_title for x in ["nasıl", "başvuru", "kayıt"]):
        q3 = f"{title} nasıl yapılır?"
    else:
        q3 = f"{title} nedir?"
        
    a3 = (
        f"Van Yüzüncü Yıl Üniversitesi bünyesinde yer alan '{title}' hakkında "
        f"güncel ve resmi bilgiler şu şekildedir:\n\n{content}\n\n"
        f"Detaylı inceleme için şu resmi sayfayı da ziyaret edebilirsiniz: {url}"
    )
    pairs.append((q3, a3))
    
    return pairs

try:
    with open('dataset.jsonl', 'r', encoding='utf-8') as f:
        for line_idx, line in enumerate(f, 1):
            if not line.strip():
                continue
            
            item = json.loads(line)
            title = item.get('page_title', '').strip()
            content = item.get('main_text', '').strip()
            url = item.get('url', '').strip()
            
            if len(content) < 15 or not title:
                gecersiz_satir += 1
                continue
                
            # Her bir web sayfası içeriğinden 3 farklı doğal sohbet çifti üretiyoruz
            conversational_pairs = generate_conversational_pairs(title, content, url)
            
            for q, a in conversational_pairs:
                chat_item = {
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": q},
                        {"role": "assistant", "content": a}
                    ]
                }
                formatted_data.append(chat_item)

    print(f"-> Toplam {line_idx} web sayfası incelendi.")
    print(f"-> Çok kısa/gereksiz olan {gecersiz_satir} sayfa elendi.")
    print(f"-> Augmentasyon sonrasında {len(formatted_data)} adet doğal sohbet verisi üretildi!")
    print("-> Veriler 'formatted_train.json' dosyasına yazılıyor...")

    with open('formatted_train.json', 'w', encoding='utf-8') as out_f:
        json.dump(formatted_data, out_f, ensure_ascii=False, indent=4)
        
    print("BASARILI: Verileriniz yuksek kaliteli sohbet formatina donusturuldu!")

except Exception as e:
    print(f"HATA OLUSTU: {str(e)}")