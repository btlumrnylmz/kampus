/// Status of user's position relative to the active navigation route.
/// 
/// Pure Dart domain entity - no Flutter or map dependencies.
class RouteStatus {
  /// Whether the user has deviated from the route.
  final bool isOffRoute;

  /// Distance from current position to the nearest point on the route, in meters.
  final double distanceToRouteMeters;

  /// Human-readable status message.
  final String message;

  /// Whether a re-route is currently in progress.
  final bool isRerouting;

  const RouteStatus({
    required this.isOffRoute,
    required this.distanceToRouteMeters,
    required this.message,
    this.isRerouting = false,
  });

  /// User is on route.
  factory RouteStatus.onRoute({required double distanceMeters}) {
    return RouteStatus(
      isOffRoute: false,
      distanceToRouteMeters: distanceMeters,
      message: 'Rotadasın',
    );
  }

  /// User has deviated from route.
  factory RouteStatus.offRoute({
    required double distanceMeters,
    bool isRerouting = false,
  }) {
    return RouteStatus(
      isOffRoute: true,
      distanceToRouteMeters: distanceMeters,
      message: isRerouting ? 'Rotadan saptın • Rota güncelleniyor…' : 'Rotadan saptın',
      isRerouting: isRerouting,
    );
  }

  /// No active route.
  static const RouteStatus none = RouteStatus(
    isOffRoute: false,
    distanceToRouteMeters: 0,
    message: 'Rota yok',
  );

  @override
  String toString() => 'RouteStatus(offRoute: $isOffRoute, dist: ${distanceToRouteMeters.toStringAsFixed(1)}m)';
}









