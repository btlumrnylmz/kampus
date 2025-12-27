import '../entities/geo_point.dart';
import '../entities/route_path.dart';

/// Repository for building navigation routes.
/// 
/// Implementations may use external routing APIs (OSRM, etc.)
/// or fallback to simple straight-line routes.
abstract class RouteRepository {
  /// Builds a route from [from] to [to].
  /// 
  /// Returns a [RoutePath] with ordered points and total distance in meters.
  /// Implementations should handle network failures gracefully with fallbacks.
  Future<RoutePath> buildRoute({
    required GeoPoint from,
    required GeoPoint to,
  });
}









