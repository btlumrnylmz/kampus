import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../controllers/map_controller.dart';
import '../controllers/map_render_state.dart';
import 'models/collectible.dart';
import 'services/storage_service.dart';

/// Controller for the collectible game mode.
/// 
/// Handles:
/// - Game state (active/inactive)
/// - Collectible spawning and management
/// - Score tracking and persistence
/// - Collection logic (distance checks)
/// - Camera follow mode
class GameController extends ChangeNotifier {
  final MapController mapController;
  final ValueNotifier<MapRenderState> mapRenderState;
  final GameStorageService storageService;

  // Game state
  bool _isGameActive = false;
  int _score = 0;
  final List<Collectible> _collectibles = [];
  final Set<String> _collectedIds = {};
  LatLng? _playerLocation;
  bool _cameraFollowEnabled = false;

  // Constants
  static const int minCollectibles = 15;
  static const int maxCollectibles = 30;
  static const double spawnRadiusMinMeters = 150.0; // Minimum spawn radius
  static const double spawnRadiusMaxMeters = 300.0; // Maximum spawn radius
  static const double collectionDistanceMeters = 15.0; // Must be within 15m to collect
  static const double highlightDistanceMeters = 30.0; // Increased glow/scale when within 30m

  GameController({
    required this.mapController,
    required this.mapRenderState,
    required this.storageService,
  });

  // Getters
  bool get isGameActive => _isGameActive;
  int get score => _score;
  List<Collectible> get collectibles => _collectibles.where((c) => !c.isCollected).toList();
  int get remainingCount => collectibles.length;
  LatLng? get playerLocation => _playerLocation;
  bool get cameraFollowEnabled => _cameraFollowEnabled;
  
  // Setters
  set cameraFollowEnabled(bool value) {
    _cameraFollowEnabled = value;
    final currentState = mapRenderState.value;
    mapRenderState.value = currentState.copyWith(cameraFollowEnabled: value);
    notifyListeners();
  }

  /// Start the game mode.
  /// 
  /// - Loads saved score and collected items
  /// - Requests location permission
  /// - Spawns collectibles around player
  /// - Enables camera follow
  Future<bool> startGame(LatLng? initialLocation) async {
    if (_isGameActive) return false;

    try {
      // Load saved state
      _score = await storageService.loadScore();
      _collectedIds.addAll(await storageService.loadCollectedIds());

      // Use provided location or get current
      if (initialLocation != null) {
        _playerLocation = initialLocation;
      } else {
        // Try to get current location
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        );
        _playerLocation = LatLng(position.latitude, position.longitude);
      }

      if (_playerLocation == null) {
        return false;
      }

      // Spawn collectibles
      _spawnCollectibles(_playerLocation!);

      // Update map state with collectibles
      _updateMapState();

      // Enable camera follow
      _cameraFollowEnabled = true;
      final currentState = mapRenderState.value;
      mapRenderState.value = currentState.copyWith(
        cameraFollowEnabled: true,
        userLocation: _playerLocation,
      );

      _isGameActive = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('[GameController] Error starting game: $e');
      return false;
    }
  }

  /// Stop the game mode.
  void stopGame() {
    if (!_isGameActive) return;

    _cameraFollowEnabled = false;
    _isGameActive = false;
    
    // Clear collectibles from map
    final currentState = mapRenderState.value;
    mapRenderState.value = currentState.copyWith(
      collectibles: const {},
      nearbyCollectibleIds: const {},
      cameraFollowEnabled: false,
    );
    
    notifyListeners();
  }

  /// Update player location (called from GPS stream).
  void updatePlayerLocation(LatLng location) {
    if (!_isGameActive) return;

    _playerLocation = location;

    // Update map state with new location
    final currentState = mapRenderState.value;
    mapRenderState.value = currentState.copyWith(
      userLocation: location,
    );

    // Check for nearby collectibles (for highlighting)
    _checkNearbyCollectibles(location);

    notifyListeners();
  }

  /// Attempt to collect a collectible by ID.
  /// 
  /// Returns:
  /// - Points gained if collected successfully (>= 0)
  /// - null if too far or already collected
  Future<int?> collectItem(String collectibleId) async {
    if (!_isGameActive) return null;

    final collectible = _collectibles.firstWhere(
      (c) => c.id == collectibleId,
      orElse: () => throw Exception('Collectible not found'),
    );

    if (collectible.isCollected || _collectedIds.contains(collectibleId)) {
      return null;
    }

    if (_playerLocation == null) {
      return null;
    }

    // CRITICAL: Distance check - user must be within collectionDistanceMeters (15m) to collect
    // Uses Geolocator.distanceBetween for accurate Haversine distance calculation
    final distance = Geolocator.distanceBetween(
      _playerLocation!.latitude,
      _playerLocation!.longitude,
      collectible.position.latitude,
      collectible.position.longitude,
    );

    if (distance > collectionDistanceMeters) {
      return null; // Too far - user needs to get closer
    }

    // Collect!
    final index = _collectibles.indexWhere((c) => c.id == collectibleId);
    if (index != -1) {
      final pointsGained = collectible.points;
      _collectibles[index] = _collectibles[index].copyWith(isCollected: true);
      _collectedIds.add(collectibleId);
      _score += pointsGained;

      // CRITICAL: Persist state to SharedPreferences
      // Score and collected IDs are saved so game state survives app restarts
      await storageService.saveScore(_score);
      await storageService.saveCollectedIds(_collectedIds);

      // Update map
      _updateMapState();

      notifyListeners();
      return pointsGained;
    }

    return null;
  }

  /// Get distance to a collectible in meters.
  double? getDistanceToCollectible(String collectibleId) {
    if (_playerLocation == null) return null;

    final collectible = _collectibles.firstWhere(
      (c) => c.id == collectibleId,
      orElse: () => throw Exception('Collectible not found'),
    );

    return Geolocator.distanceBetween(
      _playerLocation!.latitude,
      _playerLocation!.longitude,
      collectible.position.latitude,
      collectible.position.longitude,
    );
  }

  /// Check if a collectible is within highlight distance.
  bool isCollectibleNearby(String collectibleId) {
    final distance = getDistanceToCollectible(collectibleId);
    if (distance == null) return false;
    return distance <= highlightDistanceMeters;
  }

  /// Spawn collectibles around a center location.
  void _spawnCollectibles(LatLng center) {
    _collectibles.clear();

    final random = math.Random();
    final count = minCollectibles +
        random.nextInt(maxCollectibles - minCollectibles + 1);

    // Filter out already collected items
    final availableCount = count - _collectedIds.length;
    if (availableCount <= 0) {
      // All items already collected, reset?
      _collectedIds.clear();
      storageService.saveCollectedIds(_collectedIds);
    }

    for (int i = 0; i < count; i++) {
      final id = 'collectible_$i';
      
      // Skip if already collected
      if (_collectedIds.contains(id)) continue;

      // CRITICAL: Spawn collectibles within 150-300m radius of player
      // Uses random angle and distance to distribute items around the player
      final angle = random.nextDouble() * 2 * math.pi;
      final distance = spawnRadiusMinMeters + 
          random.nextDouble() * (spawnRadiusMaxMeters - spawnRadiusMinMeters);
      
      // Convert meters to lat/lng offset (approximate conversion)
      // ~111,320 meters per degree of latitude
      // Longitude conversion accounts for latitude (cos factor)
      final latOffset = distance * math.cos(angle) / 111320.0;
      final lonOffset = distance * math.sin(angle) / (111320.0 * math.cos(center.latitude * math.pi / 180));

      final position = LatLng(
        center.latitude + latOffset,
        center.longitude + lonOffset,
      );

      _collectibles.add(Collectible(
        id: id,
        position: position,
        points: 10 + random.nextInt(20), // 10-30 points
        createdAt: DateTime.now(),
      ));
    }
  }

  /// Update map render state with collectibles.
  void _updateMapState() {
    final collectiblesMap = <String, LatLng>{};
    for (final c in _collectibles) {
      if (!c.isCollected) {
        collectiblesMap[c.id] = c.position;
      }
    }

    final currentState = mapRenderState.value;
    mapRenderState.value = currentState.copyWith(
      collectibles: collectiblesMap,
      cameraFollowEnabled: _cameraFollowEnabled,
    );
  }

  /// Check for nearby collectibles and update their highlight state.
  void _checkNearbyCollectibles(LatLng location) {
    final nearbyIds = <String>{};
    for (final c in _collectibles) {
      if (c.isCollected) continue;
      final distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        c.position.latitude,
        c.position.longitude,
      );
      if (distance <= highlightDistanceMeters) {
        nearbyIds.add(c.id);
      }
    }

    final currentState = mapRenderState.value;
    mapRenderState.value = currentState.copyWith(
      nearbyCollectibleIds: nearbyIds,
    );
  }

  /// Reset game (clear score and collected items).
  Future<void> resetGame() async {
    _score = 0;
    _collectedIds.clear();
    _collectibles.clear();
    await storageService.clearAll();
    notifyListeners();
  }
}

