import 'package:kampus/domain/entities/geo_point.dart';
import 'package:kampus/domain/entities/user_location.dart';

abstract class MapController {
  void initialize();
  void showUserLocation(UserLocation location);
  void drawPath(List<UserLocation> path);
  void setRoutePolyline(List<GeoPoint> points);
  void clearRoute();
  void highlightBuilding(String buildingId);
  void clearHighlights();
}


