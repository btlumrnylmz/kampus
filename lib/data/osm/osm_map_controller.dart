import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import '../../domain/entities/geo_point.dart';
import '../../domain/entities/user_location.dart';
import '../../presentation/controllers/map_controller.dart';
import '../../presentation/controllers/map_render_state.dart';

/// OpenStreetMap implementation of [MapController].
/// 
/// This adapter converts domain objects ([UserLocation], [GeoPoint]) to [LatLng]
/// for map rendering. The conversion happens ONLY in this layer,
/// keeping domain pure.
/// 
/// Can be replaced with a Mapbox implementation later by creating
/// a new adapter that implements the same [MapController] interface.
class OsmMapController implements MapController {
  /// Notifier for map render state updates.
  final ValueNotifier<MapRenderState> renderState;

  /// Mapping from buildingId to geographic coordinates.
  final Map<String, LatLng> buildingAnchors;

  OsmMapController({
    required this.renderState,
    required this.buildingAnchors,
  });

  @override
  void initialize() {
    // Reset to empty state
    renderState.value = MapRenderState.empty;
  }

  @override
  void showUserLocation(UserLocation location) {
    final latLng = _userLocationToLatLng(location);
    renderState.value = renderState.value.copyWith(userLocation: latLng);
  }

  @override
  void drawPath(List<UserLocation> path) {
    final latLngPath = path.map(_userLocationToLatLng).toList();
    renderState.value = renderState.value.copyWith(routePolyline: latLngPath);
  }

  @override
  void setRoutePolyline(List<GeoPoint> points) {
    final latLngPath = points.map(_geoPointToLatLng).toList();
    renderState.value = renderState.value.copyWith(routePolyline: latLngPath);
  }

  @override
  void clearRoute() {
    renderState.value = renderState.value.copyWith(clearRoute: true);
  }

  @override
  void highlightBuilding(String buildingId) {
    final anchor = buildingAnchors[buildingId];
    if (anchor != null) {
      renderState.value = renderState.value.copyWith(
        highlightedPoint: anchor,
        highlightedBuildingId: buildingId,
      );
    }
  }

  @override
  void clearHighlights() {
    renderState.value = renderState.value.copyWith(clearHighlight: true);
  }

  /// Converts domain [UserLocation] to map [LatLng].
  LatLng _userLocationToLatLng(UserLocation location) {
    return LatLng(location.lat, location.lon);
  }

  /// Converts domain [GeoPoint] to map [LatLng].
  LatLng _geoPointToLatLng(GeoPoint point) {
    return LatLng(point.lat, point.lon);
  }
}


