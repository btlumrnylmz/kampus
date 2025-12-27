import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:latlong2/latlong.dart';

/// Loads building anchor points from JSON asset file.
/// 
/// The JSON structure expected:
/// ```json
/// {
///   "building_id": {"lat": 38.xxx, "lon": 43.xxx, "name": "..."},
///   ...
/// }
/// ```
class BuildingAnchorsLoader {
  /// Asset path to the buildings JSON file.
  final String assetPath;

  const BuildingAnchorsLoader({
    this.assetPath = 'assets/buildings.json',
  });

  /// Loads and parses the building anchors from the JSON asset.
  /// Returns a map of buildingId -> LatLng.
  Future<Map<String, LatLng>> load() async {
    try {
      final jsonString = await rootBundle.loadString(assetPath);
      final Map<String, dynamic> jsonData = json.decode(jsonString);

      final Map<String, LatLng> anchors = {};

      for (final entry in jsonData.entries) {
        final buildingId = entry.key;
        final data = entry.value as Map<String, dynamic>;
        
        final lat = (data['lat'] as num).toDouble();
        final lon = (data['lon'] as num).toDouble();
        
        anchors[buildingId] = LatLng(lat, lon);
      }

      return anchors;
    } catch (e) {
      // Return empty map on error, log in production
      debugPrint('BuildingAnchorsLoader: Failed to load buildings.json: $e');
      return {};
    }
  }
}


