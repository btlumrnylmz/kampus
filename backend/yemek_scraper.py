"""
YYU Yemek Listesi Web Scraper
==============================
yyu.edu.tr/yemek-listesi sayfasindan canli yemek verisi ceker.

Kullanim:
    from yemek_scraper import YemekScraper
    scraper = YemekScraper()
    menu = scraper.get_today_menu()

Gerekli paketler:
    pip install beautifulsoup4 requests
"""

import os
import json
import re
import ssl
import locale
from datetime import datetime, timedelta
from typing import Optional

try:
    import requests
    from requests.adapters import HTTPAdapter
    from bs4 import BeautifulSoup
    import urllib3
except ImportError:
    print("Gerekli paketler yuklu degil!")
    print("Kurulum: pip install beautifulsoup4 requests")
    raise

# SSL uyarisini kapat
urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


# YYU'nun zayif DH parametreleri icin ozel SSL adapter
class SSLAdapter(HTTPAdapter):
    """YYU sunucusunun zayif DH key sorununu cozmek icin ozel SSL adapter."""
    def init_poolmanager(self, *args, **kwargs):
        ctx = ssl.create_default_context()
        ctx.check_hostname = False
        ctx.verify_mode = ssl.CERT_NONE
        # Guvenlik seviyesini dusur (DH_KEY_TOO_SMALL icin)
        ctx.set_ciphers("DEFAULT@SECLEVEL=1")
        kwargs["ssl_context"] = ctx
        return super().init_poolmanager(*args, **kwargs)


# Turkce ay adlari (locale'den bagimsiz calisir)
TURKISH_MONTHS = {
    "ocak": 1, "subat": 2, "şubat": 2, "mart": 3, "nisan": 4,
    "mayis": 5, "mayıs": 5, "haziran": 6, "temmuz": 7,
    "agustos": 8, "ağustos": 8, "eylul": 9, "eylül": 9,
    "ekim": 10, "kasim": 11, "kasım": 11, "aralik": 12, "aralık": 12
}

CACHE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "yemek_cache.json")
CACHE_DURATION_HOURS = 1


class YemekScraper:
    """YYU yemek listesi sayfasindan canli veri ceker."""

    URL = "https://yyu.edu.tr/yemek-listesi"

    def __init__(self):
        self.session = requests.Session()
        self.session.headers.update({
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                          "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "Accept-Language": "tr-TR,tr;q=0.9",
        })
        # Ozel SSL adapter'i bagla (DH_KEY_TOO_SMALL sorunu icin)
        self.session.mount("https://", SSLAdapter())

    def _parse_turkish_date(self, date_text):
        """
        Turkce tarih metnini datetime nesnesine cevir.
        Ornekler: '2 Subat 2026', '24 Şubat 2026', '4 Mart 2026'
        """
        date_text = date_text.strip()

        # Sayilari ve ay adini ayikla
        match = re.search(r'(\d{1,2})\s+(\w+)\s+(\d{4})', date_text)
        if not match:
            return None

        day = int(match.group(1))
        month_name = match.group(2).lower()
        year = int(match.group(3))

        month = TURKISH_MONTHS.get(month_name)
        if not month:
            return None

        try:
            return datetime(year, month, day)
        except ValueError:
            return None

    def _fetch_page(self):
        """Sayfayi indir ve HTML olarak parse et."""
        try:
            response = self.session.get(self.URL, timeout=15)
            response.raise_for_status()
            response.encoding = 'utf-8'
            return BeautifulSoup(response.text, 'html.parser')
        except requests.RequestException as e:
            print(f"Sayfa indirme hatasi: {e}")
            return None

    def _parse_menu_cards(self, soup):
        """
        Sayfa HTML'inden tum yemek kartlarini parse et.
        Birden fazla HTML yapisini destekler (site degisirse uyum saglar).
        """
        menus = []

        # Strateji 1: Yapilandirilmis kart yapisi (div.card veya benzeri)
        # Ekran goruntusune gore: her kart bir tarih + yemek listesi icerir
        cards = soup.find_all('div', class_=re.compile(
            r'card|yemek|menu|food|list-item|col-',
            re.IGNORECASE
        ))

        if not cards:
            # Strateji 2: Tablo yapisi
            cards = soup.find_all('table')

        if not cards:
            # Strateji 3: Tum div'leri tara, tarih + yemek deseni ara
            cards = soup.find_all('div')

        for card in cards:
            card_text = card.get_text(separator='\n', strip=True)

            # Tarih ariyoruz (orn: "2 Subat 2026")
            date_match = re.search(
                r'(\d{1,2})\s+(Ocak|Şubat|Subat|Mart|Nisan|Mayıs|Mayis|Haziran|'
                r'Temmuz|Ağustos|Agustos|Eylül|Eylul|Ekim|Kasım|Kasim|Aralık|Aralik)'
                r'\s+(\d{4})',
                card_text,
                re.IGNORECASE
            )

            if not date_match:
                continue

            date_str = date_match.group(0)
            parsed_date = self._parse_turkish_date(date_str)
            if not parsed_date:
                continue

            # Yemekleri bul: "YEMEK ADI  XXX kcal" deseni
            meals = []
            # Kalori deseni: yemek adi + sayi + kcal/kalori
            meal_patterns = re.findall(
                r'([A-ZÇĞİÖŞÜa-zçğıöşü\s/]+?)\s*(\d+)\s*(?:kcal|kalori|cal)',
                card_text,
                re.IGNORECASE
            )

            for meal_name, calories in meal_patterns:
                meal_name = meal_name.strip()
                # Cok kisa veya sayi olan isimleri atla
                if len(meal_name) < 3:
                    continue
                # Tarih parcalarini atla
                if any(m in meal_name.lower() for m in TURKISH_MONTHS.keys()):
                    continue
                meals.append({
                    "name": meal_name,
                    "calories": int(calories)
                })

            if meals:
                # Tekrarlayan kayitlari onle
                existing_dates = [m["date"] for m in menus]
                if date_str not in existing_dates:
                    menus.append({
                        "date": date_str,
                        "date_parsed": parsed_date.strftime("%Y-%m-%d"),
                        "weekday": self._get_turkish_weekday(parsed_date),
                        "meals": meals,
                        "total_calories": sum(m["calories"] for m in meals)
                    })

        # Tarihe gore sirala
        menus.sort(key=lambda x: x["date_parsed"])
        return menus

    def _get_turkish_weekday(self, dt):
        """Datetime icin Turkce gun adi dondur."""
        days = ["Pazartesi", "Sali", "Carsamba", "Persembe", "Cuma", "Cumartesi", "Pazar"]
        return days[dt.weekday()]

    def _load_cache(self):
        """Onbellekten veri oku."""
        if not os.path.exists(CACHE_FILE):
            return None
        try:
            with open(CACHE_FILE, 'r', encoding='utf-8') as f:
                cache = json.load(f)
            # Cache suresi kontrol
            cache_time = datetime.fromisoformat(cache.get("cached_at", "2000-01-01"))
            if datetime.now() - cache_time < timedelta(hours=CACHE_DURATION_HOURS):
                return cache.get("menus", [])
        except (json.JSONDecodeError, ValueError):
            pass
        return None

    def _save_cache(self, menus):
        """Veriyi onbellege kaydet."""
        try:
            with open(CACHE_FILE, 'w', encoding='utf-8') as f:
                json.dump({
                    "cached_at": datetime.now().isoformat(),
                    "menus": menus
                }, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"Cache kaydetme hatasi: {e}")

    def get_all_menus(self, force_refresh=False):
        """Tum yemek menulerini getir (onbellekli)."""
        if not force_refresh:
            cached = self._load_cache()
            if cached:
                return cached

        soup = self._fetch_page()
        if not soup:
            # Site erisilemediyse cache'den dene
            cached = self._load_cache()
            return cached if cached else []

        menus = self._parse_menu_cards(soup)
        if menus:
            self._save_cache(menus)
        return menus

    def get_today_menu(self):
        """Bugunun menusunu getir."""
        today = datetime.now().strftime("%Y-%m-%d")
        menus = self.get_all_menus()

        for menu in menus:
            if menu["date_parsed"] == today:
                return menu
        return None

    def get_menu_by_date(self, target_date):
        """Belirli bir tarihin menusunu getir."""
        if isinstance(target_date, datetime):
            date_str = target_date.strftime("%Y-%m-%d")
        else:
            date_str = target_date

        menus = self.get_all_menus()
        for menu in menus:
            if menu["date_parsed"] == date_str:
                return menu
        return None

    def get_tomorrow_menu(self):
        """Yarinin menusunu getir."""
        tomorrow = datetime.now() + timedelta(days=1)
        return self.get_menu_by_date(tomorrow)

    def get_week_menu(self):
        """Bu haftanin menulerini getir."""
        today = datetime.now()
        start_of_week = today - timedelta(days=today.weekday())
        end_of_week = start_of_week + timedelta(days=6)

        menus = self.get_all_menus()
        week_menus = []
        for menu in menus:
            menu_date = datetime.strptime(menu["date_parsed"], "%Y-%m-%d")
            if start_of_week <= menu_date <= end_of_week:
                week_menus.append(menu)
        return week_menus

    def get_last_week_menu(self):
        """Gecen haftanin menulerini getir."""
        today = datetime.now()
        start_of_this_week = today - timedelta(days=today.weekday())
        start_of_last_week = start_of_this_week - timedelta(days=7)
        end_of_last_week = start_of_this_week - timedelta(days=1)

        menus = self.get_all_menus()
        week_menus = []
        for menu in menus:
            menu_date = datetime.strptime(menu["date_parsed"], "%Y-%m-%d")
            if start_of_last_week <= menu_date <= end_of_last_week:
                week_menus.append(menu)
        return week_menus

    def get_month_menu(self, year=None, month=None):
        """Belirli bir ayin menulerini getir. Varsayilan: bu ay."""
        today = datetime.now()
        if year is None:
            year = today.year
        if month is None:
            month = today.month

        menus = self.get_all_menus()
        month_menus = []
        for menu in menus:
            menu_date = datetime.strptime(menu["date_parsed"], "%Y-%m-%d")
            if menu_date.year == year and menu_date.month == month:
                month_menus.append(menu)
        return month_menus

    def format_menu_response(self, menu):
        """Bir menu kaydini kullaniciya gosterilecek metin formatina cevir."""
        if not menu:
            return None

        lines = [f"📅 {menu['date']} ({menu['weekday']})", ""]
        for i, meal in enumerate(menu["meals"], 1):
            lines.append(f"  {i}. {meal['name']}  —  {meal['calories']} kcal")
        lines.append(f"\n  🔥 Toplam: {menu['total_calories']} kcal")
        return "\n".join(lines)

    def format_multi_menu_response(self, menus, title="📋 Yemek Menüsü"):
        """Birden fazla menuyu formatlayarak dondur."""
        if not menus:
            return None

        parts = [f"{title}\n"]
        for menu in menus:
            parts.append(self.format_menu_response(menu))
            parts.append("")
        return "\n".join(parts)

    def format_week_response(self, week_menus):
        """Haftalik menuyu formatlayarak dondur."""
        return self.format_multi_menu_response(
            week_menus, "📋 Bu Haftanın Yemek Menüsü"
        )


# Test
if __name__ == "__main__":
    scraper = YemekScraper()
    print("Yemek listesi cekiliy or...")
    menus = scraper.get_all_menus()

    if menus:
        print(f"\n{len(menus)} gunluk menu bulundu:\n")
        for menu in menus[:3]:  # Ilk 3'u goster
            print(scraper.format_menu_response(menu))
            print("-" * 40)
    else:
        print("Menu bulunamadi!")

    # Bugunun menusu
    today = scraper.get_today_menu()
    if today:
        print("\n=== BUGUNUN MENUSU ===")
        print(scraper.format_menu_response(today))
    else:
        print("\nBugunun menusu bulunamadi.")
