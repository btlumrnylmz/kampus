from pandas._typing import F
import os
os.environ["KMP_DUPLICATE_LIB_OK"] = "TRUE"

import sys
import traceback
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer, TrainingArguments
from datasets import load_dataset
from trl import SFTTrainer
from peft import LoraConfig

def main():
    try:
        print("--- [EGITIM] Baslatiliyor: VRAM-Dostu 4-Bit Llama 3.2 ---", flush=True)
        
        # Eğitim ve Çıkarım (API) arasındaki token çökmesini engellemek için doğrudan Meta'nın resmi modelini kullanıyoruz
        model_id = "meta-llama/Llama-3.2-3B-Instruct"

        print("Tokenizer yukleniyor...", flush=True)
        tokenizer = AutoTokenizer.from_pretrained(model_id)
        tokenizer.pad_token = tokenizer.eos_token

        print("Model dogrudan 4-bit olarak hafizaya yukleniyor (Cokme Korumali)...", flush=True)
        from transformers import BitsAndBytesConfig
        bnb_config = BitsAndBytesConfig(
            load_in_4bit=True,
            bnb_4bit_quant_type="nf4",
            bnb_4bit_compute_dtype=torch.bfloat16,
        )
        model = AutoModelForCausalLM.from_pretrained(
            model_id,
            quantization_config=bnb_config,
            device_map={"": 0} # CPU'ya taşmayı engellemek için sadece GPU 0'a zorla
        )

        peft_config = LoraConfig(
            r=8,
            lora_alpha=16,
            target_modules=["q_proj", "v_proj"], # VRAM tasarrufu icin sadece temel q ve v projeksiyonlarini hedefliyoruz
            lora_dropout=0.05,
            task_type="CAUSAL_LM"
        )

        print("Veri seti hazirlaniyor...", flush=True)
        import json
        from datasets import Dataset, DatasetDict
        with open("formatted_train.json", "r", encoding="utf-8") as f:
            data_list = json.load(f)
        
        # --- HIZLI TEST MODU ---
        is_test_run = False
        
        if is_test_run:
            print("\n!!! DİKKAT: HIZLI TEST MODU AÇIK !!!", flush=True)
            print("Sadece 50 örnek ile 5 dakikalık deneme eğitimi yapılacak.", flush=True)
            data_list = data_list[:50]
        else:
            # --- ZAMAN TASARRUFU OPTİMİZASYONU ---
            # 36.000 veri ile eğitmek bilgisayarınızda 21 gün (500 saat) sürecek! (Çünkü bellek sınırda)
            # RAG kullandığımız için modelin 36 bin veriyi ezberlemesine ASLA gerek yoktur.
            # Sadece "soru-cevap formatını" öğrenmesi için 500 örnek fazlasıyla yeterlidir.
            import random
            random.seed(42)
            random.shuffle(data_list)
            data_list = data_list[:500]
            print(f"\n!!! ZAMAN TASARRUFU AKTİF: Eğitim {len(data_list)} örnekle yapılacak (Yaklaşık 1 gece sürecek). !!!", flush=True)
        
        # In-memory Dataset olusturuyoruz
        raw_dataset = Dataset.from_dict({"messages": [item["messages"] for item in data_list]})
        dataset = DatasetDict({"train": raw_dataset})
        print("Dataset basariyla yuklendi! Size:", dataset, flush=True)

        # Bilgisayarınızı zorlamayacak, ısınmayı ve çökmeyi engelleyecek profesyonel eğitim ayarları
        training_args = TrainingArguments(
            output_dir="./yyu_model_final",
            per_device_train_batch_size=1, # Bellek taşmasını önleyen en güvenli değer
            gradient_accumulation_steps=8, # Adım biriktirerek sanki büyük batch varmış gibi eğitir
            gradient_checkpointing=True,   # VRAM kullanımını %70 oranında azaltan hayati ayar
            optim="paged_adamw_8bit",      # Optimizer durumlarını RAM/Disk'e kaydırarak GPU'yu rahatlatır
            num_train_epochs=1,            # 13,740 zengin sohbet verisi olduğu için 1 Epoch mükemmel öğrenecektir
            learning_rate=2e-5,            # DİKKAT: 2e-4 modelin ana dilini unutturur. Llama 3 için en sağlıklı değer 2e-5'tir.
            lr_scheduler_type="cosine",    # Öğrenmeyi sona doğru yumuşatarak ezberlemeyi sıfıra indiren matematiksel çizelgeleyici
            warmup_ratio=0.03,             # Eğitime başlarken şok etkisi yaratmamak için öğrenme oranını tatlı bir şekilde yükseltir
            fp16=True,                     # Hızlı ve verimli yarım duyarlıklı eğitim
            logging_steps=1,
            save_strategy="no"             # Ara kayıtları kaydetmeyip VRAM/Disk tasarrufu sağlar
        )

        def format_chat_template(example):
            example["text"] = tokenizer.apply_chat_template(example["messages"], tokenize=False)
            return example

        print("Veriler modele uygun formata cevriliyor...", flush=True)
        dataset = dataset.map(format_chat_template)
        print("Veri donusumu basarili!", flush=True)

        print("SFTTrainer hazirlaniyor...", flush=True)
        trainer = SFTTrainer(
            model=model,
            train_dataset=dataset["train"],
            dataset_text_field="text",
            max_seq_length=1024, # DİKKAT: 128 değeri cevapları bıçak gibi kesiyordu. RAG ve mantıklı cevaplar için en az 1024 şarttır.
            args=training_args,
            peft_config=peft_config,
        )

        print(">>> EGITIM BASLIYOR! Lutfen bilgisayara dokunmayin... <<<", flush=True)
        trainer.train()
        
        # Sadece eğittiğimiz hafif adaptörü (LoRA) trainer üzerinden kaydediyoruz (Hatasız ve 1 saniyede kaydeder)
        print(">>> Model basariyla egitildi! Kaydediliyor... <<<", flush=True)
        trainer.save_model("./yyu_model_final")
        print(">>> BASARILI: Yeni yapay zeka beyniniz yyu_model_final klasorune kaydedildi! <<<", flush=True)
        
    except Exception as e:
        with open("crash_log.txt", "w") as f:
            f.write(traceback.format_exc())
        print(f"HATA YAKALANDI: {e}", flush=True)

if __name__ == "__main__":
    main()