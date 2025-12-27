import 'package:kampus/domain/entities/user_location.dart';

enum MissionType { navigation, discovery, service, scenario }

class MissionConstraints {
  final double proximityMeters;
  const MissionConstraints({required this.proximityMeters});
}

class Mission {
  final String id;
  final MissionType type;
  final String title;
  final String targetBuildingId;
  final UserLocation targetLocation;
  final MissionConstraints constraints;

  const Mission({
    required this.id,
    required this.type,
    required this.title,
    required this.targetBuildingId,
    required this.targetLocation,
    required this.constraints,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Mission &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          type == other.type &&
          title == other.title &&
          targetBuildingId == other.targetBuildingId &&
          constraints.proximityMeters == other.constraints.proximityMeters &&
          targetLocation.lat == other.targetLocation.lat &&
          targetLocation.lon == other.targetLocation.lon;

  @override
  int get hashCode => Object.hash(
        id,
        type,
        title,
        targetBuildingId,
        constraints.proximityMeters,
        targetLocation.lat,
        targetLocation.lon,
      );
}


