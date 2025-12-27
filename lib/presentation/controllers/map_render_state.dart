import 'package:latlong2/latlong.dart';

/// Immutable render state for the map view.
/// This is a presentation-layer model that uses LatLng (from latlong2)
/// to represent geographic coordinates for rendering.
class MapRenderState {
  /// Current user location marker position.
  final LatLng? userLocation;

  /// Navigation route polyline to draw on map.
  final List<LatLng> routePolyline;

  /// Highlighted building/target marker position.
  final LatLng? highlightedPoint;

  /// ID of the currently highlighted building.
  final String? highlightedBuildingId;

  /// Game mode collectibles (id -> position).
  final Map<String, LatLng> collectibles;

  /// Set of collectible IDs that are nearby (for highlighting).
  final Set<String> nearbyCollectibleIds;

  /// Whether camera follow mode is enabled (for game mode).
  final bool cameraFollowEnabled;

  const MapRenderState({
    this.userLocation,
    this.routePolyline = const [],
    this.highlightedPoint,
    this.highlightedBuildingId,
    this.collectibles = const {},
    this.nearbyCollectibleIds = const {},
    this.cameraFollowEnabled = false,
  });

  /// Empty initial state.
  static const MapRenderState empty = MapRenderState();

  /// Whether there's an active route to display.
  bool get hasRoute => routePolyline.length >= 2;

  /// Creates a copy with updated fields.
  MapRenderState copyWith({
    LatLng? userLocation,
    List<LatLng>? routePolyline,
    LatLng? highlightedPoint,
    String? highlightedBuildingId,
    Map<String, LatLng>? collectibles,
    Set<String>? nearbyCollectibleIds,
    bool? cameraFollowEnabled,
    bool clearUserLocation = false,
    bool clearHighlight = false,
    bool clearRoute = false,
    bool clearCollectibles = false,
  }) {
    return MapRenderState(
      userLocation: clearUserLocation ? null : (userLocation ?? this.userLocation),
      routePolyline: clearRoute ? const [] : (routePolyline ?? this.routePolyline),
      highlightedPoint: clearHighlight ? null : (highlightedPoint ?? this.highlightedPoint),
      highlightedBuildingId: clearHighlight ? null : (highlightedBuildingId ?? this.highlightedBuildingId),
      collectibles: clearCollectibles ? const {} : (collectibles ?? this.collectibles),
      nearbyCollectibleIds: nearbyCollectibleIds ?? this.nearbyCollectibleIds,
      cameraFollowEnabled: cameraFollowEnabled ?? this.cameraFollowEnabled,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MapRenderState &&
          runtimeType == other.runtimeType &&
          userLocation == other.userLocation &&
          highlightedPoint == other.highlightedPoint &&
          highlightedBuildingId == other.highlightedBuildingId &&
          _listEquals(routePolyline, other.routePolyline) &&
          _mapEquals(collectibles, other.collectibles) &&
          nearbyCollectibleIds == other.nearbyCollectibleIds &&
          cameraFollowEnabled == other.cameraFollowEnabled;

  @override
  int get hashCode => Object.hash(
        userLocation,
        highlightedPoint,
        highlightedBuildingId,
        Object.hashAll(routePolyline),
        Object.hashAll(collectibles.entries),
        Object.hashAll(nearbyCollectibleIds),
        cameraFollowEnabled,
      );

  static bool _listEquals(List<LatLng> a, List<LatLng> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEquals(Map<String, LatLng> a, Map<String, LatLng> b) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (b[entry.key] != entry.value) return false;
    }
    return true;
  }
}


