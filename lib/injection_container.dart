import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:latlong2/latlong.dart';

import 'core/constants/app_config.dart';
import 'data/datasources/mock/mock_ai_narration_repository.dart';
import 'data/datasources/mock/mock_mission_factory.dart';
import 'data/datasources/mock/mock_mission_repository.dart';
import 'data/datasources/mock/mock_rag_datasource.dart';
import 'data/datasources/mock/mock_simulation_repository.dart';
import 'data/datasources/remote/rag_api_client.dart';
import 'data/osm/building_anchors_loader.dart';
import 'data/osm/osm_map_controller.dart';
import 'data/repositories/ai_narration_repository_impl.dart';
import 'data/repositories/location_repository_impl.dart';
import 'data/repositories/rag_repository_http.dart';
import 'data/repositories/route_repository_impl.dart';
import 'domain/repositories/ai_narration_repository.dart';
import 'domain/repositories/location_repository.dart';
import 'domain/repositories/mission_repository.dart';
import 'domain/repositories/rag_repository.dart';
import 'domain/repositories/route_repository.dart';
import 'domain/repositories/simulation_repository.dart';
import 'domain/usecases/evaluate_mission_rules.dart';
import 'domain/usecases/request_ai_narration.dart';
import 'domain/usecases/start_mission.dart';
import 'domain/usecases/update_location.dart';
import 'presentation/controllers/map_controller.dart';
import 'presentation/controllers/map_render_state.dart';
import 'presentation/game/game_controller.dart';
import 'presentation/game/services/storage_service.dart';
import 'presentation/state/mission_provider.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // ============================================================
  // MAP LAYER
  // ============================================================
  
  // Load building anchors from JSON asset
  const loader = BuildingAnchorsLoader();
  final Map<String, LatLng> buildingAnchors = await loader.load();
  sl.registerSingleton<Map<String, LatLng>>(buildingAnchors);

  // Map render state (ValueNotifier for reactive updates)
  sl.registerLazySingleton<ValueNotifier<MapRenderState>>(
    () => ValueNotifier(MapRenderState.empty),
  );

  // Map controller (OSM implementation, swappable with Mapbox later)
  sl.registerLazySingleton<MapController>(
    () => OsmMapController(
      renderState: sl<ValueNotifier<MapRenderState>>(),
      buildingAnchors: sl<Map<String, LatLng>>(),
    ),
  );

  // ============================================================
  // REMOTE API CLIENTS
  // ============================================================

  // RAG API Client (singleton for connection reuse)
  sl.registerLazySingleton<RagApiClient>(
    () => RagApiClient(baseUrl: AppConfig.ragBackendUrl),
  );

  // ============================================================
  // DATA SOURCES / REPOSITORIES
  // ============================================================
  
  // Location Repository - REAL GPS implementation (default)
  sl.registerLazySingleton<LocationRepository>(
    () => LocationRepositoryImpl(),
  );

  // Route Repository - OSRM with fallback
  sl.registerLazySingleton<RouteRepository>(
    () => RouteRepositoryImpl(),
  );
  
  // Mission Repository (mock for now)
  sl.registerLazySingleton<MissionRepository>(() => MockMissionRepository());

  // RAG Repository - feature flag to switch between mock and HTTP
  if (AppConfig.useRealRagBackend) {
    debugPrint('[DI] Using REAL RAG backend at ${AppConfig.ragBackendUrl}');
    sl.registerLazySingleton<RagRepository>(
      () => RagRepositoryHttp(baseUrl: AppConfig.ragBackendUrl),
    );
  } else {
    debugPrint('[DI] Using MOCK RAG backend');
    sl.registerLazySingleton<RagRepository>(() => MockRagDataSource());
  }

  // Simulation Repository (mock for now)
  sl.registerLazySingleton<SimulationRepository>(
    () => const MockSimulationRepository(
      targetLat: 38.5015,
      targetLon: 43.3830,
      successPoints: 100,
    ),
  );

  // AI Narration Repository - feature flag to switch between mock and HTTP
  if (AppConfig.useRealAiBackend) {
    debugPrint('[DI] Using REAL AI backend at ${AppConfig.ragBackendUrl}');
    sl.registerLazySingleton<AiNarrationRepository>(
      () => AiNarrationRepositoryImpl(client: sl<RagApiClient>()),
    );
  } else {
    debugPrint('[DI] Using MOCK AI backend');
    sl.registerLazySingleton<AiNarrationRepository>(
      () => MockAiNarrationRepository(),
    );
  }

  // ============================================================
  // USE CASES
  // ============================================================
  sl.registerLazySingleton(() => EvaluateMissionRules(
        sl<MissionRepository>(),
        sl<SimulationRepository>(),
      ));
  sl.registerLazySingleton(() => RequestAiNarration(sl<AiNarrationRepository>()));
  sl.registerLazySingleton(() => UpdateLocation(
        missionRepository: sl<MissionRepository>(),
        evaluateMissionRules: sl<EvaluateMissionRules>(),
        requestAiNarration: sl<RequestAiNarration>(),
        ragRepository: sl<RagRepository>(),
      ));
  sl.registerLazySingleton(() => StartMission(sl<MissionRepository>()));

  // ============================================================
  // GAME MODE
  // ============================================================
  
  // Game storage service
  sl.registerLazySingleton<GameStorageService>(
    () => GameStorageService(),
  );

  // Game controller (factory - new instance per use)
  sl.registerFactory(() => GameController(
        mapController: sl<MapController>(),
        mapRenderState: sl<ValueNotifier<MapRenderState>>(),
        storageService: sl<GameStorageService>(),
      ));

  // ============================================================
  // PROVIDERS / STATE
  // ============================================================
  sl.registerFactory(() => MissionProvider(
        startMission: sl<StartMission>(),
        updateLocation: sl<UpdateLocation>(),
        missionFactory: createCentralLibraryMission,
        locationRepository: sl<LocationRepository>(),
        routeRepository: sl<RouteRepository>(),
        mapController: sl<MapController>(),
        buildingAnchors: sl<Map<String, LatLng>>(),
        ragApiClient: sl<RagApiClient>(),
      ));
}
