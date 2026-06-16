"""
YYÜ (Van Yüzüncü Yıl Üniversitesi) Web Scraper
================================================
Amaç   : yyu.edu.tr sitesini recursive olarak tarayıp RAG/Llama eğitimi
         için dataset.jsonl dosyasına kaydetmek.
Araçlar: Python · Selenium · BeautifulSoup · ChromeDriver
"""

import json
import logging
import random
import time
from collections import deque
from urllib.parse import urljoin, urlparse

from bs4 import BeautifulSoup
from selenium import webdriver
from selenium.common.exceptions import (
    TimeoutException,
    WebDriverException,
)
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from selenium.webdriver.common.by import By
from selenium.webdriver.support import expected_conditions as EC
from selenium.webdriver.support.ui import WebDriverWait
from webdriver_manager.chrome import ChromeDriverManager

# ─────────────────────────────────────────────
#  Yapılandırma
# ─────────────────────────────────────────────
START_URLS = [
    "https://www.yyu.edu.tr/",
    "https://www.yyu.edu.tr/Birimler/10", # Mühendislik Fakültesi
    "https://www.yyu.edu.tr/Birimler/14", # Tıp Fakültesi
    "https://www.yyu.edu.tr/Birimler/12", # Diş Hekimliği Fakültesi
    "https://www.yyu.edu.tr/Birimler/11", # Fen Fakültesi
    "https://www.yyu.edu.tr/Birimler/13", # Su Ürünleri Fakültesi
    "https://www.yyu.edu.tr/Birimler/24", # Turizm Fakültesi
    "https://www.yyu.edu.tr/Birimler/ziraat", # Ziraat Fakültesi
    "https://www.yyu.edu.tr/Birimler/16", # Ziraat Fakültesi (Alt ID)
    "https://www.yyu.edu.tr/Birimler/ebe", # Eğitim Bilimleri Enstitüsü
    "https://www.yyu.edu.tr/Birimler/32", # Fen Bilimleri Enstitüsü
    "https://www.yyu.edu.tr/Birimler/saglikbilimleri", # Sağlık Bilimleri Enstitüsü
    "https://www.yyu.edu.tr/Birimler/34", # Sosyal Bilimler Enstitüsü
]
ALLOWED_DOMAIN  = "yyu.edu.tr"
OUTPUT_FILE     = "dataset.jsonl"
LOG_FILE        = "scraper.log"
MAX_PAGES       = 8000          # Maksimum sayfa sınırı (0 = sınırsız)
PAGE_LOAD_WAIT  = 20            # Saniye, WebDriverWait için
SLEEP_MIN       = 2             # Sayfa geçişleri arasındaki min bekleme
SLEEP_MAX       = 5             # Sayfa geçişleri arasındaki max bekleme

# Gürültü temizliğinde kaldırılacak HTML tag'leri
NOISE_TAGS = [
    "header", "footer", "nav", "aside",
    "script", "style", "noscript", "iframe",
    "form", "button", "figure",
]

# Gürültü temizliğinde kaldırılacak CSS class/id desenleri (küçük harf)
NOISE_PATTERNS = [
    "menu", "navbar", "nav-", "header", "footer",
    "breadcrumb", "sidebar", "widget", "banner",
    "advertisement", "ad-", "social", "share",
    "cookie", "popup", "modal", "overlay",
]

# ─────────────────────────────────────────────
#  Logging
# ─────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, encoding="utf-8"),
        logging.StreamHandler(),
    ],
)
logger = logging.getLogger(__name__)


# ─────────────────────────────────────────────
#  Chrome WebDriver kurulumu
# ─────────────────────────────────────────────
def build_driver() -> webdriver.Chrome:
    options = Options()
    options.accept_insecure_certs = True
    options.add_argument("--ignore-certificate-errors")
    options.add_argument("--ignore-ssl-errors")
    options.add_argument("--allow-running-insecure-content")
    options.add_argument("--disable-web-security")
    options.add_argument("--headless=new")
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument("--disable-gpu")
    options.add_argument("--blink-settings=imagesEnabled=false")
    options.add_argument(
        "user-agent=Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/124.0.0.0 Safari/537.36"
    )

    service = Service(ChromeDriverManager().install())
    driver = webdriver.Chrome(service=service, options=options)
    driver.set_page_load_timeout(60)
    return driver


# ─────────────────────────────────────────────
#  URL doğrulama
# ─────────────────────────────────────────────
def is_internal(url: str) -> bool:
    """URL yyu.edu.tr domainine mi ait?"""
    try:
        parsed = urlparse(url)
        netloc = parsed.netloc.lower()
        if ALLOWED_DOMAIN not in netloc:
            return False
        
        # Taranması gereksiz veya erişim hatası veren portal/sistem alt alan adları
        skip_subdomains = [
            "online.yyu.edu.tr", "ebys.yyu.edu.tr", "bkys.yyu.edu.tr", 
            "erasmusbasvuru.yyu.edu.tr", "obs.yyu.edu.tr", "mail.yyu.edu.tr",
            "kutuphane.yyu.edu.tr", "ubys.yyu.edu.tr", "enstitu.yyu.edu.tr",
            "moodle.yyu.edu.tr", "uzem.yyu.edu.tr", "vankedisi.yyu.edu.tr",
            "yeniogrenci.yyu.edu.tr", "eduroam.yyu.edu.tr"
        ]
        if any(sub in netloc for sub in skip_subdomains):
            return False
            
        return True
    except Exception:
        return False


def normalize_url(url: str, base: str) -> str | None:
    """Göreli URL'leri mutlak yap; geçersizse None döndür."""
    try:
        full = urljoin(base, url).split("#")[0].rstrip("/")
        parsed = urlparse(full)
        if parsed.scheme not in ("http", "https"):
            return None
        if not is_internal(full):
            return None
        
        skip_exts = (
            ".pdf", ".jpg", ".jpeg", ".png", ".gif", ".svg",
            ".zip", ".rar", ".doc", ".docx", ".xls", ".xlsx",
            ".ppt", ".pptx", ".mp4", ".mp3", ".avi",
        )
        if any(parsed.path.lower().endswith(ext) for ext in skip_exts):
            return None
        return full
    except Exception:
        return None


# ─────────────────────────────────────────────
#  Sayfa içi link toplama
# ─────────────────────────────────────────────
def extract_links(driver: webdriver.Chrome, current_url: str) -> list[str]:
    """Sayfadaki tüm <a href> linklerini toplar, temizlerและ döndürür."""
    links = []
    try:
        elements = driver.find_elements(By.TAG_NAME, "a")
        for el in elements:
            try:
                href = el.get_attribute("href") or ""
                normalized = normalize_url(href, current_url)
                if normalized:
                    links.append(normalized)
            except Exception:
                continue
    except Exception as exc:
        logger.warning(f"Link toplama hatası [{current_url}]: {exc}")
    return list(set(links))


# ─────────────────────────────────────────────
#  Gürültü temizleme
# ─────────────────────────────────────────────
def _is_noisy_element(tag) -> bool:
    """Bir BeautifulSoup tag'inin gürültü içerip içermediğini kontrol eder."""
    try:
        if tag is None:
            return False
        
        # Etiket tipini kontrol et (Yalnızca gerçek HTML Tag nesnelerini işle, metinleri atla)
        if not hasattr(tag, "get") or not hasattr(tag, "name") or tag.name is None:
            return False
            
        raw_class = tag.get("class", [])
        if isinstance(raw_class, list):
            cls = " ".join(raw_class).lower()
        else:
            cls = str(raw_class).lower()
            
        tag_id = str(tag.get("id") or "").lower()
        combined = cls + " " + tag_id
        
        if "no-footer" in combined:
            return False
            
        return any(p in combined for p in NOISE_PATTERNS)
    except Exception:
        return False


def clean_html(html: str) -> tuple[str, str]:
    """
    Ham HTML'den sayfa başlığını ve temizlenmiş metni ayıklar.
    Herhangi bir ayrıştırma hatasına karşı try-except korumalıdır.
    """
    try:
        soup = BeautifulSoup(html, "html.parser")

        # Sayfa başlığı
        page_title = soup.title.get_text(strip=True) if soup.title else ""

        # Gürültü tag'lerini kaldır
        for tag_name in NOISE_TAGS:
            for tag in soup.find_all(tag_name):
                try:
                    if tag and hasattr(tag, "decompose"):
                        tag.decompose()
                except Exception:
                    continue

        # Gürültü class/id'ye sahip div/section/article'ları kaldır
        for tag in soup.find_all(["div", "section", "article", "ul", "li", "span"]):
            try:
                if _is_noisy_element(tag):
                    if tag and hasattr(tag, "decompose"):
                        tag.decompose()
            except Exception:
                continue

        # Başlıkları topla
        headings = []
        for h in soup.find_all(["h1", "h2", "h3"]):
            try:
                text = h.get_text(separator=" ", strip=True)
                if text:
                    headings.append(text)
            except Exception:
                continue

        # Tablo verilerini yapılandırılmış metin olarak topla
        table_texts = []
        for table in soup.find_all("table"):
            try:
                rows = []
                for tr in table.find_all("tr"):
                    cells = [td.get_text(separator=" ", strip=True) for td in tr.find_all(["td", "th"]) if td]
                    if any(cells):
                        rows.append(" | ".join(cells))
                if rows:
                    table_texts.append("\n".join(rows))
                if table and hasattr(table, "decompose"):
                    table.decompose()
            except Exception:
                continue

        # Ana gövde metni kontrolü
        body = soup.find("body")
        if body:
            body_text = body.get_text(separator="\n", strip=True)
        else:
            body_text = soup.get_text(separator="\n", strip=True)

        # Birleştir
        parts = []
        if headings:
            parts.append("## Başlıklar\n" + "\n".join(headings))
        if body_text:
            parts.append("## İçerik\n" + body_text)
        if table_texts:
            parts.append("## Tablolar\n" + "\n\n".join(table_texts))

        main_text = "\n\n".join(parts)

        # Tekrar eden boş satırları temizle
        lines = [ln for ln in main_text.splitlines() if ln.strip()]
        main_text = "\n".join(lines)

        return page_title, main_text
    except Exception as e:
        logger.error(f"HTML ayrıştırma sırasında iç hata: {e}")
        return "", ""


# ─────────────────────────────────────────────
#  Tek sayfa verisi çekme
# ─────────────────────────────────────────────
def scrape_page(driver: webdriver.Chrome, url: str) -> dict | None:
    try:
        try:
            driver.get(url)
        except TimeoutException:
            logger.warning(f"Sayfa yüklemesi zaman aşımına uğradı, kısmi içerik deneniyor: {url}")

        try:
            WebDriverWait(driver, PAGE_LOAD_WAIT).until(
                lambda d: d.execute_script("return document.readyState") in ("interactive", "complete")
            )
        except TimeoutException:
            pass

        # Gelen sayfa kaynağının tipini ve doğruluğunu sıkı denetle
        try:
            html = driver.page_source
        except Exception:
            logger.error(f"Sayfa kaynağı driver'dan alınamadı: {url}")
            return None

        if not html or not isinstance(html, str) or len(html) < 200:
            logger.info(f"Sayfa içeriği geçersiz veya çok kısa, atlandı: {url}")
            return None

        page_title, main_text = clean_html(html)

        if not main_text or not main_text.strip():
            logger.info(f"Boş içerik, atlandı: {url}")
            return None

        return {
            "url": url,
            "page_title": page_title,
            "main_text": main_text,
        }

    except WebDriverException as exc:
        logger.error(f"WebDriver hatası [{url}]: {exc}")
        return None
    except Exception as exc:
        logger.error(f"Beklenmeyen hata [{url}]: {exc}")
        return None


# ─────────────────────────────────────────────
#  Ana tarama döngüsü
# ─────────────────────────────────────────────
def crawl() -> None:
    logger.info("=" * 60)
    logger.info("YYÜ Web Scraper başlatıldı")
    logger.info(f"Başlangıç URL sayısı: {len(START_URLS)}")
    logger.info(f"Çıktı dosyası : {OUTPUT_FILE}")
    logger.info("=" * 60)

    driver = build_driver()
    visited: set[str]  = set()
    queue:  deque[str] = deque(START_URLS)
    page_count = 0

    # Mevcut verileri korumak ve mükerrer taramayı önlemek için önceden taranmış URL'leri oku
    import os
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as in_file:
                for line in in_file:
                    line = line.strip()
                    if line:
                        try:
                            record = json.loads(line)
                            if "url" in record:
                                visited.add(record["url"])
                        except Exception:
                            continue
            logger.info(f"-> Mevcut veri tabanından {len(visited)} adet taranmış URL yüklendi. Bu sayfalar tekrar taranmayacaktır.")
        except Exception as e:
            logger.warning(f"Mevcut veri tabanı okunurken hata oluştu: {e}")

    try:
        with open(OUTPUT_FILE, "a", encoding="utf-8") as out_file:

            while queue:
                if MAX_PAGES and page_count >= MAX_PAGES:
                    logger.info(f"Maksimum sayfa sayısına ulaşıldı: {MAX_PAGES}")
                    break

                url = queue.popleft()

                # Ziyaret edilmiş sayfaları atla, ancak başlangıç sayfalarını (START_URLS) 
                # yeni linkleri keşfedebilmek için her zaman tara.
                if url in visited and url not in START_URLS:
                    continue
                
                is_already_saved = url in visited
                visited.add(url)

                logger.info(f"[{page_count + 1}] Ziyaret ediliyor: {url}")

                record = scrape_page(driver, url)

                if record:
                    if not is_already_saved:
                        out_file.write(json.dumps(record, ensure_ascii=False) + "\n")
                        out_file.flush()
                        page_count += 1
                        logger.info(f"    ✓ Kaydedildi | Başlık: {record['page_title'][:60]}")
                    else:
                        logger.info(f"    ✓ Başlangıç merkezi analiz edildi (mükerrer kayıt önlendi, yeni linkler taranıyor).")

                    new_links = extract_links(driver, url)
                    added = 0
                    for link in new_links:
                        if link not in visited and link not in queue:
                            queue.append(link)
                            added += 1
                    logger.info(f"    → {added} yeni link kuyruğa eklendi "
                                f"(kuyruk boyutu: {len(queue)})")
                else:
                    logger.info(f"    ✗ İçerik alınamadı, geçildi.")

                sleep_time = random.uniform(SLEEP_MIN, SLEEP_MAX)
                time.sleep(sleep_time)

    except KeyboardInterrupt:
        logger.info("Kullanıcı tarafından durduruldu (Ctrl+C).")
    except Exception as exc:
        logger.critical(f"Kritik hata: {exc}", exc_info=True)
    finally:
        try:
            driver.quit()
        except Exception:
            pass
        logger.info("=" * 60)
        logger.info(f"Tarama tamamlandı. Toplam kaydedilen sayfa: {page_count}")
        logger.info(f"Çıktı dosyası: {OUTPUT_FILE}")
        logger.info("=" * 60)


if __name__ == "__main__":
    crawl()
    