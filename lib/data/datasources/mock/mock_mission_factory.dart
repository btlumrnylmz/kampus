import 'package:kampus/domain/entities/mission.dart';
import 'package:kampus/domain/entities/user_location.dart';

Mission createCentralLibraryMission() {
  return Mission(
    id: 'mission_central_library',
    type: MissionType.navigation,
    title: 'Merkez Kütüphanesi Navigasyon',
    targetBuildingId: 'central_library',
    targetLocation: UserLocation(
      lat: 38.5015,
      lon: 43.3830,
      accuracyMeters: 5,
      timestamp: DateTime.now(),
    ),
    constraints: const MissionConstraints(proximityMeters: 50),
  );
}


