import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;

/// YYÜ Kampüs lokasyonları veri modeli
class CampusLocation {
  final String name;
  final String description;
  final LatLng coordinates;
  final String category;
  final IconData icon;
  final Color color;

  const CampusLocation({
    required this.name,
    required this.description,
    required this.coordinates,
    required this.category,
    required this.icon,
    required this.color,
  });

  /// İki nokta arası mesafe (metre)
  double distanceTo(LatLng other) {
    const double earthRadius = 6371000; // metre
    final double lat1 = coordinates.latitudeInRad;
    final double lat2 = other.latitudeInRad;
    final double dLat = other.latitudeInRad - coordinates.latitudeInRad;
    final double dLon = other.longitudeInRad - coordinates.longitudeInRad;

    final double a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1) *
            math.cos(lat2) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));

    return earthRadius * c;
  }

  /// Mesafeyi okunabilir formatta döndür
  String formattedDistanceTo(LatLng other) {
    final double meters = distanceTo(other);
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}

/// Lokasyon kategorileri
class LocationCategory {
  static const String akademik = 'Akademik';
  static const String idari = 'İdari';
  static const String yemeIcme = 'Yeme-İçme';
  static const String spor = 'Spor';
  static const String barinma = 'Barınma';
  static const String saglik = 'Sağlık';
  static const String ulasim = 'Ulaşım';
  static const String genel = 'Genel';
}

/// YYÜ Kampüs merkez noktası
final LatLng kampusMerkez = LatLng(38.5697, 43.2888);

/// Tüm kampüs lokasyonları
final List<CampusLocation> campusLocations = [
  // === AKADEMİK ===
  CampusLocation(
    name: 'Mühendislik Fakültesi',
    description:
        'Bilgisayar, Elektrik-Elektronik, İnşaat, Makine, Kimya Mühendisliği bölümleri',
    coordinates: LatLng(38.5680, 43.2870),
    category: LocationCategory.akademik,
    icon: Icons.engineering,
    color: Colors.blue,
  ),
  CampusLocation(
    name: 'Tıp Fakültesi (Dursun Odabaş)',
    description: 'Dursun Odabaş Tıp Merkezi ve Tıp Fakültesi',
    coordinates: LatLng(38.5750, 43.2977),
    category: LocationCategory.saglik,
    icon: Icons.local_hospital,
    color: Colors.red,
  ),
  CampusLocation(
    name: 'Fen Fakültesi',
    description: 'Fizik, Kimya, Biyoloji, Matematik bölümleri',
    coordinates: LatLng(38.5685, 43.2855),
    category: LocationCategory.akademik,
    icon: Icons.science,
    color: Colors.blue,
  ),
  CampusLocation(
    name: 'Edebiyat Fakültesi',
    description: 'Türk Dili, Tarih, Sosyoloji, Felsefe bölümleri',
    coordinates: LatLng(38.5670, 43.2865),
    category: LocationCategory.akademik,
    icon: Icons.menu_book,
    color: Colors.blue,
  ),
  CampusLocation(
    name: 'Eğitim Fakültesi',
    description: 'Öğretmenlik bölümleri',
    coordinates: LatLng(38.5690, 43.2845),
    category: LocationCategory.akademik,
    icon: Icons.school,
    color: Colors.blue,
  ),
  CampusLocation(
    name: 'İktisadi ve İdari Bilimler Fakültesi',
    description: 'İktisat, İşletme, Kamu Yönetimi bölümleri',
    coordinates: LatLng(38.5695, 43.2875),
    category: LocationCategory.akademik,
    icon: Icons.account_balance,
    color: Colors.blue,
  ),
  CampusLocation(
    name: 'Hukuk Fakültesi',
    description: 'Hukuk bölümü',
    coordinates: LatLng(38.5700, 43.2895),
    category: LocationCategory.akademik,
    icon: Icons.gavel,
    color: Colors.blue,
  ),
  CampusLocation(
    name: 'İlahiyat Fakültesi',
    description: 'İlahiyat bölümü',
    coordinates: LatLng(38.5675, 43.2900),
    category: LocationCategory.akademik,
    icon: Icons.auto_stories,
    color: Colors.blue,
  ),

  // === KÜTÜPHANe & GENEL ===
  CampusLocation(
    name: 'Ferit Melen Kütüphanesi',
    description:
        'Merkez kütüphane — çalışma salonları, bilgisayar odası, e-kaynaklar',
    coordinates: LatLng(38.5641, 43.2852),
    category: LocationCategory.akademik,
    icon: Icons.local_library,
    color: Colors.amber,
  ),

  // === İDARİ ===
  CampusLocation(
    name: 'Rektörlük Binası',
    description: 'YYÜ Rektörlük — Genel Sekreterlik, Yazı İşleri',
    coordinates: LatLng(38.5705, 43.2890),
    category: LocationCategory.idari,
    icon: Icons.domain,
    color: Colors.purple,
  ),
  CampusLocation(
    name: 'Öğrenci İşleri Daire Başkanlığı',
    description: 'Kayıt, transkript, belge, mezuniyet işlemleri',
    coordinates: LatLng(38.5700, 43.2882),
    category: LocationCategory.idari,
    icon: Icons.assignment_ind,
    color: Colors.purple,
  ),
  CampusLocation(
    name: 'SKS Daire Başkanlığı',
    description: 'Sağlık, Kültür ve Spor — Burs, yurt, sosyal etkinlikler',
    coordinates: LatLng(38.5693, 43.2878),
    category: LocationCategory.idari,
    icon: Icons.support_agent,
    color: Colors.purple,
  ),

  // === YEME-İÇME ===
  CampusLocation(
    name: 'Merkez Yemekhane',
    description: 'Öğrenci yemekhanesi — günlük 4 çeşit yemek',
    coordinates: LatLng(38.5645, 43.2860),
    category: LocationCategory.yemeIcme,
    icon: Icons.restaurant,
    color: Colors.orange,
  ),
  CampusLocation(
    name: 'Kantin / Kafeterya',
    description: 'Kampüs içi kantin ve kafeteryalar',
    coordinates: LatLng(38.5688, 43.2872),
    category: LocationCategory.yemeIcme,
    icon: Icons.local_cafe,
    color: Colors.orange,
  ),
  CampusLocation(
    name: 'Yeleli Restoran',
    description: 'Kampüs yakınında ev yemekleri ve kebap çeşitleri',
    coordinates: LatLng(38.5705, 43.2810),
    category: LocationCategory.yemeIcme,
    icon: Icons.restaurant,
    color: Colors.orange,
  ),
  CampusLocation(
    name: 'Komagene Etsiz Çiğ Köfte',
    description: 'Etsiz çiğ köfte, dürüm ve içecek çeşitleri',
    coordinates: LatLng(38.5680, 43.2845),
    category: LocationCategory.yemeIcme,
    icon: Icons.lunch_dining,
    color: Colors.orange,
  ),
  CampusLocation(
    name: 'Süphan Kafe',
    description: 'Kampüs yakınında kafe — kahve, tost ve atıştırmalıklar',
    coordinates: LatLng(38.5650, 43.2870),
    category: LocationCategory.yemeIcme,
    icon: Icons.coffee,
    color: Colors.orange,
  ),
  CampusLocation(
    name: 'Karaeski',
    description: 'Restoran ve kafe — çeşitli yemekler ve içecekler',
    coordinates: LatLng(38.5652, 43.2885),
    category: LocationCategory.yemeIcme,
    icon: Icons.restaurant_menu,
    color: Colors.orange,
  ),
  CampusLocation(
    name: 'Beyoğlu Pasta & Kahvaltı',
    description: 'Pasta, börek, kahvaltı ve geç kahvaltı çeşitleri',
    coordinates: LatLng(38.5748, 43.2995),
    category: LocationCategory.yemeIcme,
    icon: Icons.cake,
    color: Colors.orange,
  ),
  CampusLocation(
    name: 'Tendur Restaurant',
    description: 'Kampüs içi restoran — ev yemekleri, kebap ve pide çeşitleri',
    coordinates: LatLng(38.5668, 43.2862),
    category: LocationCategory.yemeIcme,
    icon: Icons.restaurant,
    color: Colors.orange,
  ),
  CampusLocation(
    name: 'İkizler Kampüs',
    description: 'Fast food — hamburger, dürüm, pizza ve içecek çeşitleri',
    coordinates: LatLng(38.5643, 43.2848),
    category: LocationCategory.yemeIcme,
    icon: Icons.fastfood,
    color: Colors.orange,
  ),
  CampusLocation(
    name: 'Süphan Market',
    description:
        'Kampüs içi market — atıştırmalık, içecek ve günlük ihtiyaçlar',
    coordinates: LatLng(38.5672, 43.2878),
    category: LocationCategory.yemeIcme,
    icon: Icons.local_grocery_store,
    color: Colors.orange,
  ),
  CampusLocation(
    name: 'Tıp Merkezi Kafeterya',
    description: 'YYÜ Dursun Odabaş Tıp Merkezi içi kafeterya',
    coordinates: LatLng(38.5745, 43.2970),
    category: LocationCategory.yemeIcme,
    icon: Icons.local_cafe,
    color: Colors.orange,
  ),
  CampusLocation(
    name: 'Unifood Campus',
    description:
        'Kampüs içi fast food — hamburger, tavuk, patates ve içecekler',
    coordinates: LatLng(38.5640, 43.2845),
    category: LocationCategory.yemeIcme,
    icon: Icons.fastfood,
    color: Colors.orange,
  ),
  CampusLocation(
    name: 'Kampüs Cafe',
    description:
        'Edebiyat Fakültesi yanı — kahve, çay, tost ve atıştırmalıklar',
    coordinates: LatLng(38.5673, 43.2860),
    category: LocationCategory.yemeIcme,
    icon: Icons.coffee,
    color: Colors.orange,
  ),

  // === SPOR ===
  CampusLocation(
    name: 'Spor Tesisleri',
    description: 'Kapalı spor salonu, yüzme havuzu, fitness',
    coordinates: LatLng(38.5660, 43.2830),
    category: LocationCategory.spor,
    icon: Icons.fitness_center,
    color: Colors.green,
  ),
  CampusLocation(
    name: 'Stadyum',
    description: 'Açık hava stadyumu ve atletizm pisti',
    coordinates: LatLng(38.5650, 43.2820),
    category: LocationCategory.spor,
    icon: Icons.stadium,
    color: Colors.green,
  ),

  // === BARINMA ===
  CampusLocation(
    name: 'KYK Erkek Yurdu',
    description: 'Kredi Yurtlar Kurumu erkek öğrenci yurdu',
    coordinates: LatLng(38.5720, 43.2910),
    category: LocationCategory.barinma,
    icon: Icons.apartment,
    color: Colors.teal,
  ),
  CampusLocation(
    name: 'KYK Kız Yurdu',
    description: 'Kredi Yurtlar Kurumu kız öğrenci yurdu',
    coordinates: LatLng(38.5730, 43.2920),
    category: LocationCategory.barinma,
    icon: Icons.apartment,
    color: Colors.teal,
  ),

  // === SAĞLIK ===
  CampusLocation(
    name: 'Mediko-Sosyal Merkezi',
    description: 'Kampüs sağlık merkezi — poliklinik hizmetleri',
    coordinates: LatLng(38.5690, 43.2885),
    category: LocationCategory.saglik,
    icon: Icons.medical_services,
    color: Colors.red,
  ),

  // === ULAŞIM ===
  CampusLocation(
    name: 'Kampüs Ana Girişi',
    description: 'Kampüs ana kapı — otobüs ve ring durağı',
    coordinates: LatLng(38.5630, 43.2830),
    category: LocationCategory.ulasim,
    icon: Icons.door_front_door,
    color: Colors.grey,
  ),
  CampusLocation(
    name: 'Durak — Ana Giriş',
    description: 'Kampüs ana giriş otobüs durağı',
    coordinates: LatLng(38.5635, 43.2835),
    category: LocationCategory.ulasim,
    icon: Icons.directions_bus,
    color: Colors.red,
  ),
  CampusLocation(
    name: 'Durak — Zeve Üst Yol',
    description: 'Zeve Yerleşkesi üst yol durağı',
    coordinates: LatLng(38.5720, 43.2892),
    category: LocationCategory.ulasim,
    icon: Icons.directions_bus,
    color: Colors.red,
  ),
  CampusLocation(
    name: 'Durak — Zeve Kavşak',
    description: 'Zeve Yerleşkesi kavşak durağı',
    coordinates: LatLng(38.5700, 43.2875),
    category: LocationCategory.ulasim,
    icon: Icons.directions_bus,
    color: Colors.red,
  ),
  CampusLocation(
    name: 'Durak — Merkez Kampüs',
    description: 'Merkez kampüs iç yol durağı',
    coordinates: LatLng(38.5670, 43.2862),
    category: LocationCategory.ulasim,
    icon: Icons.directions_bus,
    color: Colors.red,
  ),
  CampusLocation(
    name: 'Durak — Teknopark Yolu',
    description: 'Van Teknopark yönü durağı',
    coordinates: LatLng(38.5683, 43.2935),
    category: LocationCategory.ulasim,
    icon: Icons.directions_bus,
    color: Colors.red,
  ),
  CampusLocation(
    name: 'Durak — Van Yolu 1',
    description: 'Van ana yolu üzeri kampüs durağı (kuzey)',
    coordinates: LatLng(38.5758, 43.3030),
    category: LocationCategory.ulasim,
    icon: Icons.directions_bus,
    color: Colors.red,
  ),
  CampusLocation(
    name: 'Durak — Van Yolu 2',
    description: 'Van ana yolu üzeri kampüs durağı (güney)',
    coordinates: LatLng(38.5745, 43.3045),
    category: LocationCategory.ulasim,
    icon: Icons.directions_bus,
    color: Colors.red,
  ),
  CampusLocation(
    name: 'Durak — Tıp Fakültesi',
    description: 'Tıp Fakültesi önü otobüs durağı',
    coordinates: LatLng(38.5748, 43.2985),
    category: LocationCategory.ulasim,
    icon: Icons.directions_bus,
    color: Colors.red,
  ),
  CampusLocation(
    name: 'Durak — Güney Giriş',
    description: 'Kampüs güney kapı durağı',
    coordinates: LatLng(38.5590, 43.2800),
    category: LocationCategory.ulasim,
    icon: Icons.directions_bus,
    color: Colors.red,
  ),
  CampusLocation(
    name: 'Durak — Batı Giriş',
    description: 'Kampüs batı kapı durağı',
    coordinates: LatLng(38.5640, 43.2780),
    category: LocationCategory.ulasim,
    icon: Icons.directions_bus,
    color: Colors.red,
  ),
  CampusLocation(
    name: 'Durak — Kütüphane Yolu',
    description: 'Kütüphane yakını ring durağı',
    coordinates: LatLng(38.5648, 43.2848),
    category: LocationCategory.ulasim,
    icon: Icons.directions_bus,
    color: Colors.red,
  ),
  CampusLocation(
    name: 'Durak — Yurt Yolu',
    description: 'KYK yurtları yönü durağı',
    coordinates: LatLng(38.5605, 43.2810),
    category: LocationCategory.ulasim,
    icon: Icons.directions_bus,
    color: Colors.red,
  ),
];

/// Kategoriye göre lokasyonları filtrele
List<CampusLocation> getLocationsByCategory(String category) {
  return campusLocations.where((loc) => loc.category == category).toList();
}

/// Anahtar kelimeye göre lokasyon bul
CampusLocation? findLocationByKeyword(String keyword) {
  final kw = keyword.toLowerCase();
  try {
    return campusLocations.firstWhere(
      (loc) =>
          loc.name.toLowerCase().contains(kw) ||
          loc.description.toLowerCase().contains(kw),
    );
  } catch (_) {
    return null;
  }
}

/// Tüm kategorileri döndür
List<String> getAllCategories() {
  return campusLocations.map((loc) => loc.category).toSet().toList();
}

/// Kategori ikonları
IconData getCategoryIcon(String category) {
  switch (category) {
    case 'Akademik':
      return Icons.school;
    case 'İdari':
      return Icons.domain;
    case 'Yeme-İçme':
      return Icons.restaurant;
    case 'Spor':
      return Icons.fitness_center;
    case 'Barınma':
      return Icons.apartment;
    case 'Sağlık':
      return Icons.local_hospital;
    case 'Ulaşım':
      return Icons.directions_bus;
    default:
      return Icons.place;
  }
}

/// Kategori renkleri
Color getCategoryColor(String category) {
  switch (category) {
    case 'Akademik':
      return Colors.blue;
    case 'İdari':
      return Colors.purple;
    case 'Yeme-İçme':
      return Colors.orange;
    case 'Spor':
      return Colors.green;
    case 'Barınma':
      return Colors.teal;
    case 'Sağlık':
      return Colors.red;
    case 'Ulaşım':
      return Colors.grey;
    default:
      return Colors.blueGrey;
  }
}
