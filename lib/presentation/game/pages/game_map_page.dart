import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get_it/get_it.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../controllers/map_render_state.dart';
import '../game_controller.dart';
import '../services/location_service.dart';
import '../theme/game_theme.dart';
import '../widgets/game_hud.dart';
import '../../widgets/campus_map_view.dart';

/// Full-screen immersive game page for the collectible game mode.
///
/// Features:
/// - Entry animation with "Entering Game Mode..." banner
/// - Full-screen map with camera follow
/// - Collectible spawning and collection with animations
/// - Real-time GPS tracking or debug simulation
/// - Enhanced HUD overlay with glassmorphism
/// - Re-center button when user pans away
/// - Bottom action bar with Scan button
class GameMapPage extends StatefulWidget {
  const GameMapPage({super.key});

  @override
  State<GameMapPage> createState() => _GameMapPageState();
}

class _GameMapPageState extends State<GameMapPage>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  late final ValueNotifier<MapRenderState> _mapRenderState;
  late final GameController _gameController;
  late final LocationService _locationService;

  StreamSubscription<LatLng>? _locationSubscription;
  Timer? _cameraCheckTimer;
  bool _isInitialized = false;
  bool _isCentered = true; // Track if camera is following player
  LatLng? _lastPlayerLocation;

  // Animation controllers
  late AnimationController _entryAnimationController;
  late AnimationController _collectAnimationController;
  late Animation<double> _entryFadeAnimation;
  late Animation<Offset> _entrySlideAnimation;

  // Collect animation state
  String? _collectingId;
  Offset? _collectAnimationPosition;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _mapRenderState = GetIt.I<ValueNotifier<MapRenderState>>();
    _gameController = context.read<GameController>();
    _locationService = LocationService();

    // Entry animation
    _entryAnimationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _entryFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _entryAnimationController, curve: Curves.easeOut),
    );
    _entrySlideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _entryAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );

    // Collect animation
    _collectAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    // Start entry animation
    _entryAnimationController.forward();

    // Initialize game after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeGame();
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _cameraCheckTimer?.cancel();
    _gameController.stopGame();
    _mapController.dispose();
    _entryAnimationController.dispose();
    _collectAnimationController.dispose();
    super.dispose();
  }

  /// Initialize the game: request location, spawn collectibles, start tracking.
  Future<void> _initializeGame() async {
    if (_isInitialized) return;

    try {
      // Request location permission and get initial location
      final initialLocation = await _locationService.getCurrentLocation();

      if (initialLocation == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Konum izni gerekli. Lütfen ayarlardan izin verin.',
              ),
              backgroundColor: GameTheme.errorRed,
              duration: Duration(seconds: 3),
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Start game with initial location
      final success = await _gameController.startGame(initialLocation);

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Oyun başlatılamadı.'),
              backgroundColor: GameTheme.errorRed,
            ),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      // Smoothly fly to player location with zoom
      _lastPlayerLocation = initialLocation;
      _mapController.move(initialLocation, 18.0); // Zoom 18 for game mode

      // Start location tracking stream
      _locationSubscription = _locationService.watchLocation().listen(
        (location) {
          if (_gameController.isGameActive) {
            _gameController.updatePlayerLocation(location);

            // Update camera follow (smooth movement) if centered
            if (_gameController.cameraFollowEnabled && _isCentered) {
              _lastPlayerLocation = location;
              _mapController.move(location, _mapController.camera.zoom);
            } else {
              // Check if camera drifted from player (user panned)
              _checkCameraCentered(location);
            }
          }
        },
        onError: (error) {
          debugPrint('[GameMapPage] Location error: $error');
        },
      );

      // Periodic check for camera centering (every 2 seconds)
      _cameraCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        if (!mounted || !_gameController.isGameActive) {
          timer.cancel();
          return;
        }
        final playerLoc = _gameController.playerLocation;
        if (playerLoc != null && !_isCentered) {
          _checkCameraCentered(playerLoc);
        }
      });

      _isInitialized = true;

      // Hide entry banner after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _entryAnimationController.reverse();
        }
      });
    } catch (e) {
      debugPrint('[GameMapPage] Error initializing game: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: GameTheme.errorRed,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: GameTheme.backgroundGradient),
        child: Stack(
          children: [
            // Full-screen map
            CampusMapView(
              renderState: _mapRenderState,
              initialZoom: 18.0,
              onCollectibleTap: _handleCollectibleTap,
              mapController: _mapController,
            ),

            // Entry banner animation
            _buildEntryBanner(),

            // HUD overlay at the top
            const GameHUD(),

            // Re-center button (when not centered)
            if (!_isCentered && _lastPlayerLocation != null)
              _buildRecenterButton(),

            // Bottom action bar
            _buildBottomActionBar(),

            // Collect animation overlay
            if (_collectingId != null && _collectAnimationPosition != null)
              _buildCollectAnimation(),

            // Debug simulation controls (if in debug mode)
            if (kDebugMode) _buildDebugControls(),
          ],
        ),
      ),
    );
  }

  /// Entry banner: "Entering Game Mode..." with slide/fade animation.
  Widget _buildEntryBanner() {
    // Only show if animation is still playing or game not initialized
    if (_entryAnimationController.value == 0.0 || _isInitialized) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _entrySlideAnimation,
      child: FadeTransition(
        opacity: _entryFadeAnimation,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.only(top: 100),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: GameTheme.glassCard(
                  borderRadius: 20,
                  borderColor: GameTheme.amberAccent,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: GameTheme.amberAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Entering Game Mode...',
                      style: GameTheme.titleStyle.copyWith(
                        fontSize: 16,
                        color: GameTheme.amberAccent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Re-center button (floating, appears when user pans away).
  Widget _buildRecenterButton() {
    return Positioned(
      bottom: 120,
      right: 16,
      child: SafeArea(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              if (_lastPlayerLocation != null) {
                _isCentered = true;
                _gameController.cameraFollowEnabled = true;
                _mapController.move(_lastPlayerLocation!, 18.0);
                setState(() {});
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: GameTheme.glassCard(
                borderRadius: 16,
                borderColor: GameTheme.primaryAccent,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.my_location,
                    color: GameTheme.primaryAccent,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Re-center',
                    style: GameTheme.labelStyle.copyWith(
                      color: GameTheme.primaryAccent,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Bottom action bar with Scan and Inventory buttons.
  Widget _buildBottomActionBar() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Consumer<GameController>(
            builder: (context, gameController, _) {
              if (!gameController.isGameActive) {
                return const SizedBox.shrink();
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: GameTheme.glassCard(
                  borderRadius: 20,
                  borderOpacity: 0.15,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Scan button (find nearest collectible)
                    _buildActionButton(
                      icon: Icons.search,
                      label: 'Scan',
                      onTap: () => _scanNearestCollectible(gameController),
                      color: GameTheme.primaryAccent,
                    ),
                    // Inventory button (placeholder)
                    _buildActionButton(
                      icon: Icons.inventory_2_outlined,
                      label: 'Inventory',
                      onTap: () {
                        // Placeholder - show collected items
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Collected: ${gameController.score ~/ 10} items',
                            ),
                            backgroundColor: GameTheme.secondaryAccent,
                          ),
                        );
                      },
                      color: GameTheme.secondaryAccent,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withValues(alpha: 0.3),
                color.withValues(alpha: 0.15),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GameTheme.labelStyle.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Scan for nearest collectible and center camera on it.
  void _scanNearestCollectible(GameController gameController) {
    if (gameController.playerLocation == null) return;

    double? nearestDistance;
    LatLng? nearestLocation;

    for (final collectible in gameController.collectibles) {
      final distance = gameController.getDistanceToCollectible(collectible.id);
      if (distance != null) {
        if (nearestDistance == null || distance < nearestDistance) {
          nearestDistance = distance;
          nearestLocation = collectible.position;
        }
      }
    }

    if (nearestLocation != null) {
      _isCentered = false; // User manually moved, disable auto-follow
      _mapController.move(nearestLocation, _mapController.camera.zoom);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Nearest collectible: ${nearestDistance!.toStringAsFixed(0)}m away',
            ),
            backgroundColor: GameTheme.primaryAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No collectibles found'),
            backgroundColor: GameTheme.errorRed,
          ),
        );
      }
    }
  }

  /// Collect animation: burst effect at marker position.
  Widget _buildCollectAnimation() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: FadeTransition(
            opacity: _collectAnimationController,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.5, end: 2.0).animate(
                CurvedAnimation(
                  parent: _collectAnimationController,
                  curve: Curves.easeOut,
                ),
              ),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      GameTheme.successGreen.withValues(alpha: 0.8),
                      GameTheme.successGreen.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Handle collectible tap - check distance and collect if close enough.
  Future<void> _handleCollectibleTap(String collectibleId) async {
    if (!_gameController.isGameActive) return;

    final distance = _gameController.getDistanceToCollectible(collectibleId);

    if (distance == null) {
      return;
    }

    // Try to collect (returns points gained or null if too far)
    final pointsGained = await _gameController.collectItem(collectibleId);

    if (pointsGained != null) {
      // Success! Provide feedback
      if (mounted) {
        // Haptic feedback
        await HapticFeedback.mediumImpact();

        // Collect animation
        setState(() {
          _collectingId = collectibleId;
        });
        _collectAnimationController.forward().then((_) {
          _collectAnimationController.reset();
          if (mounted) {
            setState(() {
              _collectingId = null;
            });
          }
        });

        // Mini toast near HUD
        _showPointsToast(pointsGained);
      }
    } else {
      // Too far - show distance message
      if (mounted) {
        await HapticFeedback.lightImpact();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.warning, color: Colors.white),
                const SizedBox(width: 8),
                Text('Daha yaklaşın! (${distance.toStringAsFixed(0)} m kaldı)'),
              ],
            ),
            backgroundColor: GameTheme.warningOrange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Show mini toast with points gained near the HUD.
  void _showPointsToast(int points) {
    // Create overlay entry for toast
    final overlay = Overlay.of(context);
    final overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: 120,
        left: 0,
        right: 0,
        child: SafeArea(
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Opacity(
                    opacity: value,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: GameTheme.successGreen.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            '+$points',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    overlay.insert(overlayEntry);

    // Remove after animation
    Future.delayed(const Duration(milliseconds: 1500), () {
      overlayEntry.remove();
    });
  }

  /// Debug controls for simulating movement (themed).
  Widget _buildDebugControls() {
    return Positioned(
      bottom: 80,
      right: 16,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: GameTheme.glassCard(
            borderRadius: 20,
            borderColor: GameTheme.amberAccent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SIM MODE',
                style: GameTheme.labelStyle.copyWith(
                  fontSize: 10,
                  letterSpacing: 1,
                  color: GameTheme.amberAccent,
                ),
              ),
              const SizedBox(height: 12),
              // N/S/E/W buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDebugButton(
                    Icons.arrow_upward,
                    () => _simulateMove(0, -0.0001),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDebugButton(
                    Icons.arrow_back,
                    () => _simulateMove(-0.0001, 0),
                  ),
                  const SizedBox(width: 8),
                  _buildDebugButton(
                    Icons.arrow_forward,
                    () => _simulateMove(0.0001, 0),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDebugButton(
                    Icons.arrow_downward,
                    () => _simulateMove(0, 0.0001),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDebugButton(IconData icon, VoidCallback onPressed) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                GameTheme.amberAccent.withValues(alpha: 0.3),
                GameTheme.amberAccent.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: GameTheme.amberAccent.withValues(alpha: 0.5),
            ),
          ),
          child: Icon(icon, color: GameTheme.amberAccent, size: 20),
        ),
      ),
    );
  }

  /// Check if camera is centered on player (within 50m threshold).
  void _checkCameraCentered(LatLng playerLocation) {
    final cameraCenter = _mapController.camera.center;
    final distance = Geolocator.distanceBetween(
      cameraCenter.latitude,
      cameraCenter.longitude,
      playerLocation.latitude,
      playerLocation.longitude,
    );

    // If camera is more than 50m away, show re-center button
    final wasCentered = _isCentered;
    _isCentered = distance < 50.0;

    if (wasCentered != _isCentered) {
      setState(() {});
    }
  }

  /// Simulate player movement (debug mode only).
  void _simulateMove(double latOffset, double lonOffset) {
    final currentLocation = _gameController.playerLocation;
    if (currentLocation == null) return;

    final newLocation = LatLng(
      currentLocation.latitude + latOffset,
      currentLocation.longitude + lonOffset,
    );

    _gameController.updatePlayerLocation(newLocation);
    if (_isCentered) {
      _mapController.move(newLocation, _mapController.camera.zoom);
    }
  }
}
