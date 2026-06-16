"""
Van Büyükşehir Belediyesi - YYÜ Otobüs Saatleri Scraper
========================================================
van.bel.tr/OtobusSaatDetay sayfalarından kampüse giden
otobüs hatlarının canlı hareket saatlerini çeker.

Kullanım:
    from otobus_scraper import OtobusScraper
    scraper = OtobusScraper()
    saatler = scraper.get_all_yyu_schedules()

Gerekli paketler:
    pip install beautifulsoup4 requests
"""

import json
import os
import re
import ssl
import time
from datetime import datetime
from typing import Optional

try:
    import requests
    from requests.adapters import HTTPAdapter
    from bs4 import BeautifulSoup
    import urllib3
except ImportError:
    print("Gerekli paketler yüklü değil!")
    print("Kurulum: pip install beautifulsoup4 requests")
    raise

# SSL uyarısını kapat
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


# SSL sorunlarını aşmak için özel adapter
class SSLAdapter(HTTPAdapter):
    """SSL sertifika sorunlarını aşmak için özel adapter."""
    def init_poolmanager(self, *args, **kwargs):
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        ctx.set_ciphers("DEFAULT@SECLEVEL=1")
        kwargs["ssl_context"] = ctx
        return super().init_poolmanager(*args, **kwargs)


# YYÜ'ye giden otobüs hatları
YYU_ROUTES = {
    "E-1": {
        "id": 126,
        "name": "E-1 — EDREMİT YENİ TOKİ-KİRACILAR TOKİ-ESKİ TOKİ-Y.Y.Ü EXSPRES HATTI",
        "short": "E-1 Edremit → YYÜ Ekspres",
    },
    "540": {
        "id": 162,
        "name": "540 — İKİNİSAN CADDESİ - YÜZÜNCÜ YIL ÜNİVERSİTESİ",
        "short": "540 İkinisan → YYÜ",
    },
    "541": {
        "id": 163,
        "name": "541 — BEŞYOL KAMPÜS YÜZÜNCÜ YIL ÜNİVERSİTESİ",
        "short": "541 Beşyol → YYÜ",
    },
    "542": {
        "id": 164,
        "name": "542 — MARAŞ CADDESİ - YÜZÜNCÜ YIL ÜNİVERSİTESİ",
        "short": "542 Maraş Cad. → YYÜ",
    },
    "543": {
        "id": 165,
        "name": "543 — İSKELE MAHALLESİ - YÜZÜNCÜ YIL ÜNİVERSİTESİ",
        "short": "543 İskele → YYÜ",
    },
    "641": {
        "id": 170,
        "name": "641 — F-TİPİ CEZAEVİ (YYÜ TOKİ)",
        "short": "641 F-Tipi (YYÜ TOKİ)",
    },
    "BF-100": {
        "id": 215,
        "name": "BF-100 — BÖLGE HASTANESİ-YYÜ HASTANESİ-F TİPİ CEZA EVİ",
        "short": "BF-100 Bölge Hast. → YYÜ Hast.",
    },
    "BK-400": {
        "id": 217,
        "name": "BK-400 — BOSTANİÇİ TOKİ-KAMPÜS",
        "short": "BK-400 Bostaniçi → Kampüs",
    },
}

# Önbellek dosyası ve süresi
CACHE_FILE = os.path.join(os.path.dirname(__file__), "otobus_cache.json")
CACHE_DURATION = 3600  # 1 saat (saniye)


class OtobusScraper:
    """Van Büyükşehir Belediyesi otobüs saatleri scraper."""

    BASE_URL = "https://van.bel.tr/OtobusSaatDetay"

    def __init__(self):
        self.session = requests.Session()
        # SSL adapter ekle
        self.session.mount("https://", SSLAdapter())
        self.session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                          "AppleWebKit/537.36 (KHTML, like Gecko) "
                          "Chrome/120.0.0.0 Safari/537.36",
            "Accept-Language": "tr-TR,tr;q=0.9",
        })
        self._last_error = None

    def _fetch_page(self, route_id: int) -> Optional[str]:
        """Belirtilen hat sayfasını çek."""
        url = f"{self.BASE_URL}/{route_id}"
        try:
            resp = self.session.get(url, timeout=15, verify=False)
            resp.raise_for_status()
            resp.encoding = "utf-8"
            return resp.text
        except requests.exceptions.ConnectionError as e:
            self._last_error = "bağlantı hatası"
            print(f"[OtobusScraper] Bağlantı hatası ({route_id}): {e}")
            return None
        except requests.exceptions.Timeout:
            self._last_error = "zaman aşımı"
            print(f"[OtobusScraper] Zaman aşımı ({route_id})")
            return None
        except Exception as e:
            self._last_error = str(e)
            print(f"[OtobusScraper] Sayfa çekilemedi ({route_id}): {e}")
            return None

    def _parse_schedule(self, html: str) -> dict:
        """
        HTML'den hareket saatlerini çıkar.
        İki bölüm: MERKEZ ve YYÜ (veya kampüs) hareket saatleri.
        """
        soup = BeautifulSoup(html, "html.parser")

        # Başlığı bul
        title_el = soup.find("h1") or soup.find("h2")
        title = title_el.get_text(strip=True) if title_el else "Bilinmeyen Hat"

        # li etiketlerindeki saatleri çıkar
        # Sayfa yapısı: iki grup var — merkez ve YYÜ (veya kampüs/üniversite)
        all_sections = []
        current_section = None

        # Tüm li elementlerini tara
        for li in soup.find_all("li"):
            text = li.get_text(strip=True)

            # Bölüm başlığı kontrolü
            if "HAREKET SAATLERİ" in text.upper():
                section_name = text.strip()
                current_section = {
                    "name": section_name,
                    "times": [],
                    "out_of_service": [],
                }
                all_sections.append(current_section)
                continue

            # Rota açıklaması (uzun metin, saat değil)
            if current_section and len(text) > 30 and "-" in text and ":" not in text[:6]:
                current_section["route_desc"] = text.strip()
                continue

            # Saat çıkar (HH:MM formatı)
            if current_section:
                time_match = re.search(r"(\d{2}:\d{2})", text)
                if time_match:
                    time_str = time_match.group(1)
                    is_arizali = "ARIZALI" in text.upper()
                    if is_arizali:
                        current_section["out_of_service"].append(time_str)
                    else:
                        current_section["times"].append(time_str)

        # Eğer bölüm bulunamazsa, tüm saatleri topla
        if not all_sections:
            times = []
            for li in soup.find_all("li"):
                text = li.get_text(strip=True)
                time_match = re.search(r"(\d{2}:\d{2})", text)
                if time_match:
                    times.append(time_match.group(1))
            if times:
                all_sections.append({
                    "name": "Hareket Saatleri",
                    "times": times,
                    "out_of_service": [],
                })

        return {
            "title": title,
            "sections": all_sections,
        }

    def get_route_schedule(self, route_code: str) -> Optional[dict]:
        """Belirli bir hattın saatlerini çek."""
        route = YYU_ROUTES.get(route_code.upper())
        if not route:
            return None

        html = self._fetch_page(route["id"])
        if not html:
            return None

        schedule = self._parse_schedule(html)
        schedule["code"] = route_code
        schedule["short_name"] = route["short"]
        schedule["full_name"] = route["name"]
        return schedule

    def get_all_yyu_schedules(self) -> list:
        """Tüm YYÜ hatlarının saatlerini çek (cache'li)."""
        # Önbellekten kontrol
        cached = self._load_cache()
        if cached:
            return cached

        schedules = []
        for code, route in YYU_ROUTES.items():
            html = self._fetch_page(route["id"])
            if html:
                schedule = self._parse_schedule(html)
                schedule["code"] = code
                schedule["short_name"] = route["short"]
                schedule["full_name"] = route["name"]
                schedules.append(schedule)
            time.sleep(0.5)  # Rate limiting

        if schedules:
            self._save_cache(schedules)

        return schedules

    def get_next_buses(self, from_yyu: bool = False) -> list:
        """
        Şu andan sonraki en yakın otobüsleri grupla ve döndür.
        from_yyu=True: YYÜ'den kalkan, False: merkeze giden
        """
        now = datetime.now().strftime("%H:%M")
        schedules = self.get_all_yyu_schedules()
        next_buses = []

        for sched in schedules:
            for section in sched.get("sections", []):
                name_upper = section.get("name", "").upper()

                # Doğru bölümü seç
                if from_yyu:
                    if "YYÜ" not in name_upper and "KAMPÜS" not in name_upper and "ÜNİVERSİTE" not in name_upper:
                        continue
                else:
                    if "MERKEZ" not in name_upper:
                        continue

                for t in section.get("times", []):
                    if t >= now:
                        next_buses.append({
                            "code": sched["code"],
                            "short_name": sched["short_name"],
                            "time": t,
                            "route_desc": section.get("route_desc", ""),
                        })
                        break  # Her hat için sadece sonraki ilk sefer

        # Zamana göre sırala
        next_buses.sort(key=lambda x: x["time"])
        return next_buses

    def format_schedule_text(self, route_code: str = None, from_yyu: bool = False) -> str:
        """
        Otobüs saatlerini okunabilir metin formatında döndür.
        route_code: belirli hat (ör. "541")
        from_yyu: YYÜ'den mi, merkezden mi?
        """
        now = datetime.now().strftime("%H:%M")

        if route_code:
            # Belirli bir hat
            schedule = self.get_route_schedule(route_code)
            if not schedule:
                error_detail = f" ({self._last_error})" if self._last_error else ""
                return (
                    f"⚠️ {route_code} hattının saatleri şu anda alınamadı{error_detail}.\n\n"
                    f"Güncel saatler için: https://van.bel.tr/OtobusSaatDetay/"
                    f"{YYU_ROUTES.get(route_code.upper(), {}).get('id', '')}\n"
                    f"📋 Tüm hatlar: https://van.bel.tr/Syf/Otobus-Hareket-Saatleri.html"
                )

            lines = [f"🚌 **{schedule['short_name']}**\n"]
            for section in schedule.get("sections", []):
                lines.append(f"📌 {section['name']}")
                if section.get("times"):
                    active_times = []
                    for t in section["times"]:
                        marker = " ← sonraki" if t >= now and "← sonraki" not in " ".join(active_times) else ""
                        active_times.append(f"  • {t}{marker}")
                    lines.append("\n".join(active_times))
                if section.get("out_of_service"):
                    lines.append(f"  ⚠️ Arızalı seferler: {', '.join(section['out_of_service'])}")
                if section.get("route_desc"):
                    lines.append(f"  🗺️ Güzergah: {section['route_desc']}")
                lines.append("")

            return "\n".join(lines)

        # Sonraki otobüsler özeti
        next_buses = self.get_next_buses(from_yyu=from_yyu)
        if not next_buses:
            direction = "YYÜ'den" if from_yyu else "merkeze doğru"
            return f"⚠️ Şu andan sonra {direction} kalkan YYÜ otobüsü bulunmamaktadır."

        direction = "YYÜ'den kalkan" if from_yyu else "YYÜ'ye giden"
        lines = [f"🚌 **{direction} yaklaşan otobüsler:**\n"]
        for bus in next_buses[:5]:  # En yakın 5 sefer
            lines.append(f"  🕐 **{bus['time']}** — {bus['short_name']}")

        lines.append(f"\n📋 Tüm saatler: https://van.bel.tr/Syf/Otobus-Hareket-Saatleri.html")
        return "\n".join(lines)

    def _load_cache(self) -> Optional[list]:
        """Önbellek dosyasından veri yükle."""
        try:
            if os.path.exists(CACHE_FILE):
                with open(CACHE_FILE, "r", encoding="utf-8") as f:
                    data = json.load(f)
                if time.time() - data.get("timestamp", 0) < CACHE_DURATION:
                    return data.get("schedules", [])
        except Exception:
            pass
        return None

    def _save_cache(self, schedules: list):
        """Önbellek dosyasına kaydet."""
        try:
            with open(CACHE_FILE, "w", encoding="utf-8") as f:
                json.dump({
                    "timestamp": time.time(),
                    "schedules": schedules,
                }, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"[OtobusScraper] Cache kayıt hatası: {e}")


# Test amaçlı
if __name__ == "__main__":
    scraper = OtobusScraper()

    print("=" * 60)
    print("YYÜ'ye giden tüm otobüs hatları:")
    print("=" * 60)

    # 541 hattının detaylı saatleri
    text = scraper.format_schedule_text("541")
    print(text)

    print("\n" + "=" * 60)
    print("Yaklaşan otobüsler (merkez → YYÜ):")
    print("=" * 60)
    text = scraper.format_schedule_text(from_yyu=False)
    print(text)

    print("\n" + "=" * 60)
    print("Yaklaşan otobüsler (YYÜ → merkez):")
    print("=" * 60)
    text = scraper.format_schedule_text(from_yyu=True)
    print(text)
