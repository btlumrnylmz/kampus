import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';

import '../../domain/entities/mission_state.dart';
import '../../domain/entities/navigation_instruction.dart';
import '../../domain/entities/nearby_anchor.dart';
import '../../domain/entities/route_status.dart';
import '../controllers/map_controller.dart';
import '../controllers/map_render_state.dart';
import '../game/pages/game_map_page.dart';
import '../state/mission_provider.dart';
import '../widgets/campus_map_view.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final MapController _mapController;
  late final ValueNotifier<MapRenderState> _mapRenderState;

  @override
  void initState() {
    super.initState();
    _mapController = GetIt.I<MapController>();
    _mapRenderState = GetIt.I<ValueNotifier<MapRenderState>>();
    _mapController.initialize();

    // Auto-start GPS tracking after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<MissionProvider>().ensureTrackingStarted();
    });
  }

  @override
  Widget build(BuildContext context) {
    final missionProvider = context.watch<MissionProvider>();
    final missionState = missionProvider.missionState;
    final aiNarration = missionProvider.aiNarration;
    final locationError = missionProvider.locationError;

    // Update map when mission state changes (highlight target building)
    _updateMapFromMissionState(missionState);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, missionState, missionProvider.isTracking),
              // Location error banner
              if (locationError != null)
                _buildLocationErrorBanner(locationError),
              // Map view - takes flexible space
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: CampusMapView(renderState: _mapRenderState),
                  ),
                ),
              ),
              // Mission info cards - scrollable
              Expanded(
                flex: 3,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildMissionCard(context, missionState),
                      const SizedBox(height: 12),
                      // Navigation info card
                      _buildNavigationCard(context, missionProvider),
                      const SizedBox(height: 12),
                      // Route status banner
                      if (missionProvider.hasActiveRoute)
                        _buildRouteStatusBanner(missionProvider.routeStatus),
                      if (missionProvider.hasActiveRoute)
                        const SizedBox(height: 12),
                      // Nearby building card
                      if (missionProvider.nearbyAnchor != null)
                        _buildNearbyAnchorCard(missionProvider.nearbyAnchor!),
                      if (missionProvider.nearbyAnchor != null)
                        const SizedBox(height: 12),
                      // DEBUG: Route simulation controls
                      if (kDebugMode)
                        _buildRouteSimulatorCard(context, missionProvider),
                      if (kDebugMode) const SizedBox(height: 12),
                      // DEBUG: Distance readout card
                      if (kDebugMode)
                        _buildDebugDistanceCard(context, missionProvider),
                      if (kDebugMode) const SizedBox(height: 12),
                      _buildProgressCard(context, missionState),
                      const SizedBox(height: 12),
                      _buildAiNarrationCard(context, aiNarration),
                      const SizedBox(height: 12),
                      // AI Assistant result card
                      _buildAiAssistantCard(context, missionProvider),
                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildNavigationFAB(context, missionProvider),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  /// Updates map markers and highlights based on mission state.
  void _updateMapFromMissionState(MissionState? missionState) {
    if (missionState == null) return;

    // Always highlight the target building
    _mapController.highlightBuilding(missionState.mission.targetBuildingId);
  }

  /// Shows location error banner at top.
  Widget _buildLocationErrorBanner(String error) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFef5350).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFef5350).withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_off, color: Color(0xFFef5350), size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: const TextStyle(
                color: Color(0xFFef5350),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    MissionState? missionState,
    bool isTracking,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'KAMPÜS NAVİGASYON',
                      style: TextStyle(
                        color: Color(0xFFe94560),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // GPS status indicator
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isTracking
                            ? const Color(0xFF66bb6a)
                            : Colors.grey,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                Text(
                  missionState?.mission.title ?? 'Yükleniyor...',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          _buildStatusBadge(missionState?.phase),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(MissionPhase? phase) {
    final (color, icon, label) = switch (phase) {
      MissionPhase.enRoute => (
        const Color(0xFFffa726),
        Icons.directions_walk,
        'Yolda',
      ),
      MissionPhase.nearTarget => (
        const Color(0xFF42a5f5),
        Icons.near_me,
        'Yakında',
      ),
      MissionPhase.success => (
        const Color(0xFF66bb6a),
        Icons.check_circle,
        'Başarılı',
      ),
      MissionPhase.failed => (
        const Color(0xFFef5350),
        Icons.cancel,
        'Başarısız',
      ),
      null => (Colors.grey, Icons.hourglass_empty, 'Bekliyor'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMissionCard(BuildContext context, MissionState? missionState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFe94560).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.flag_rounded,
                  color: Color(0xFFe94560),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Aktif Görev',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            missionState?.mission.title ?? 'Görev yükleniyor...',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Colors.white54,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                missionState?.mission.targetBuildingId ?? '-',
                style: const TextStyle(color: Colors.white54, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Navigation info card showing turn-by-turn instruction, distance and ETA.
  Widget _buildNavigationCard(BuildContext context, MissionProvider provider) {
    final hasRoute = provider.hasActiveRoute;
    final remainingMeters = provider.remainingMeters;
    final etaMinutes = provider.etaMinutes;
    final isLoading = provider.isLoadingRoute;
    final instruction = provider.currentInstruction;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasRoute
              ? [
                  const Color(0xFF4285F4).withValues(alpha: 0.25),
                  const Color(0xFF4285F4).withValues(alpha: 0.1),
                ]
              : [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasRoute
              ? const Color(0xFF4285F4).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  hasRoute ? Icons.navigation_rounded : Icons.route_outlined,
                  color: const Color(0xFF4285F4),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Yönlendirme',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              if (isLoading)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF4285F4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (hasRoute) ...[
            // Turn-by-turn instruction
            if (instruction != null) _buildInstructionRow(instruction),
            if (instruction != null) const SizedBox(height: 16),
            // Distance and ETA row
            Row(
              children: [
                Expanded(
                  child: _buildNavInfoItem(
                    icon: Icons.straighten,
                    label: 'Kalan Mesafe',
                    value: remainingMeters != null
                        ? '${remainingMeters.toStringAsFixed(0)} m'
                        : '-',
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                Expanded(
                  child: _buildNavInfoItem(
                    icon: Icons.schedule,
                    label: 'Tahmini Süre',
                    value: etaMinutes != null ? '$etaMinutes dk' : '-',
                  ),
                ),
              ],
            ),
          ] else ...[
            // No route message
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Rota henüz oluşturulmadı',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Builds the turn-by-turn instruction row with icon and text.
  Widget _buildInstructionRow(NavigationInstruction instruction) {
    final (icon, color) = _getInstructionIconAndColor(instruction.type);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          // Direction icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 12),
          // Instruction text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  instruction.text,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                _buildInstructionTypeBadge(instruction.type),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Returns icon and color based on instruction type.
  (IconData, Color) _getInstructionIconAndColor(
    NavigationInstructionType type,
  ) {
    return switch (type) {
      NavigationInstructionType.straight => (
        Icons.arrow_upward,
        const Color(0xFF4285F4),
      ),
      NavigationInstructionType.turnLeft => (
        Icons.turn_left,
        const Color(0xFFffa726),
      ),
      NavigationInstructionType.turnRight => (
        Icons.turn_right,
        const Color(0xFFffa726),
      ),
      NavigationInstructionType.slightLeft => (
        Icons.turn_slight_left,
        const Color(0xFF66bb6a),
      ),
      NavigationInstructionType.slightRight => (
        Icons.turn_slight_right,
        const Color(0xFF66bb6a),
      ),
      NavigationInstructionType.uTurn => (
        Icons.u_turn_left,
        const Color(0xFFef5350),
      ),
      NavigationInstructionType.arrive => (
        Icons.flag_rounded,
        const Color(0xFF66bb6a),
      ),
    };
  }

  /// Builds a small badge showing the instruction type.
  Widget _buildInstructionTypeBadge(NavigationInstructionType type) {
    final label = switch (type) {
      NavigationInstructionType.straight => 'Düz',
      NavigationInstructionType.turnLeft => 'Sola Dön',
      NavigationInstructionType.turnRight => 'Sağa Dön',
      NavigationInstructionType.slightLeft => 'Hafif Sol',
      NavigationInstructionType.slightRight => 'Hafif Sağ',
      NavigationInstructionType.uTurn => 'Geri Dön',
      NavigationInstructionType.arrive => 'Varış',
    };

    final (_, color) = _getInstructionIconAndColor(type);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Route status banner showing on-route or off-route state.
  Widget _buildRouteStatusBanner(RouteStatus status) {
    final isOffRoute = status.isOffRoute;
    final color = isOffRoute
        ? const Color(0xFFef5350)
        : const Color(0xFF66bb6a);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.1)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          // Status icon
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              isOffRoute
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          // Status text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  status.message,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (kDebugMode)
                  Text(
                    'Rotaya uzaklık: ${status.distanceToRouteMeters.toStringAsFixed(1)} m',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.8),
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ),
          // Rerouting indicator
          if (status.isRerouting)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFef5350),
              ),
            ),
        ],
      ),
    );
  }

  /// Nearby building/POI card.
  Widget _buildNearbyAnchorCard(NearbyAnchor anchor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF7c3aed).withValues(alpha: 0.2),
            const Color(0xFF7c3aed).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF7c3aed).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          // Building icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF7c3aed).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.location_city_rounded,
              color: Color(0xFF7c3aed),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          // Building info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Yakındaki Bina',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  anchor.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          // Distance badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF7c3aed).withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${anchor.distanceMeters.toStringAsFixed(0)} m',
              style: const TextStyle(
                color: Color(0xFF7c3aed),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF4285F4), size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  /// DEBUG: Route simulation controls.
  Widget _buildRouteSimulatorCard(
    BuildContext context,
    MissionProvider provider,
  ) {
    final hasRoute = provider.hasActiveRoute;
    final isSimulating = provider.isSimulating;
    final simIndex = provider.simulationIndex;
    final simTotal = provider.simulationTotalPoints;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF9c27b0).withValues(alpha: 0.2),
            const Color(0xFF9c27b0).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF9c27b0).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF9c27b0).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.developer_mode,
                  color: Color(0xFF9c27b0),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'DEBUG: Rota Simülasyonu',
                style: TextStyle(
                  color: Color(0xFF9c27b0),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Simulation status
          if (hasRoute && isSimulating)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF9c27b0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Adım $simIndex / $simTotal',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
            ),

          // Buttons row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Build route button
              _buildDebugButton(
                label: 'Rota Oluştur',
                icon: Icons.route,
                onPressed: provider.isLoadingRoute
                    ? null
                    : () => provider.buildRouteToTarget(),
                color: const Color(0xFF4285F4),
              ),

              // Start/Stop simulation
              if (hasRoute)
                _buildDebugButton(
                  label: isSimulating ? 'Durdur' : 'Simülasyonu Başlat',
                  icon: isSimulating ? Icons.stop : Icons.play_arrow,
                  onPressed: isSimulating
                      ? () => provider.stopRouteSimulation()
                      : () => provider.startRouteSimulation(),
                  color: isSimulating
                      ? const Color(0xFFef5350)
                      : const Color(0xFF66bb6a),
                ),

              // Step once
              if (hasRoute && !isSimulating)
                _buildDebugButton(
                  label: 'Adım At',
                  icon: Icons.skip_next,
                  onPressed: () => provider.stepSimulationOnce(),
                  color: const Color(0xFFffa726),
                ),

              // Clear route
              if (hasRoute)
                _buildDebugButton(
                  label: 'Rotayı Temizle',
                  icon: Icons.clear,
                  onPressed: () => provider.clearRoute(),
                  color: Colors.grey,
                ),

              // Simulate off-route
              if (hasRoute)
                _buildDebugButton(
                  label: 'Rotadan Sap',
                  icon: Icons.wrong_location,
                  onPressed: () => provider.simulateOffRoute(),
                  color: const Color(0xFFef5350),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebugButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: onPressed != null
                ? color.withValues(alpha: 0.2)
                : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: onPressed != null
                  ? color.withValues(alpha: 0.5)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: onPressed != null ? color : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: onPressed != null ? color : Colors.grey,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// DEBUG: Shows distance to target and coordinate info.
  Widget _buildDebugDistanceCard(
    BuildContext context,
    MissionProvider provider,
  ) {
    final missionState = provider.missionState;
    final lastLocation = provider.lastLocation;
    final distance = provider.lastDistanceMeters;
    final threshold = missionState?.mission.constraints.proximityMeters ?? 0;

    final isNear = distance != null && distance <= threshold;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFffa726).withValues(alpha: 0.2),
            const Color(0xFFffa726).withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFffa726).withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFffa726).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bug_report,
                  color: Color(0xFFffa726),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'DEBUG: Distance Info',
                style: TextStyle(
                  color: Color(0xFFffa726),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Distance readout
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Distance to target
                Row(
                  children: [
                    Icon(
                      isNear
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: isNear ? const Color(0xFF66bb6a) : Colors.white54,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Hedefe uzaklık: ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 11,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      distance != null
                          ? '${distance.toStringAsFixed(1)} m'
                          : 'Hesaplanıyor...',
                      style: TextStyle(
                        color: isNear ? const Color(0xFF66bb6a) : Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Text(
                      ' (eşik: ${threshold.toStringAsFixed(0)}m)',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Current location
                _buildCoordRow(
                  'GPS',
                  lastLocation?.lat,
                  lastLocation?.lon,
                  lastLocation?.accuracyMeters,
                ),
                const SizedBox(height: 4),

                // Target location
                _buildCoordRow(
                  'TARGET',
                  missionState?.mission.targetLocation.lat,
                  missionState?.mission.targetLocation.lon,
                  null,
                ),
                const SizedBox(height: 4),

                // Phase
                Row(
                  children: [
                    Text(
                      'PHASE: ',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontFamily: 'monospace',
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _getPhaseColor(
                          missionState?.phase,
                        ).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        missionState?.phase.name ?? 'null',
                        style: TextStyle(
                          color: _getPhaseColor(missionState?.phase),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoordRow(
    String label,
    double? lat,
    double? lon,
    double? accuracy,
  ) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 10,
              fontFamily: 'monospace',
            ),
          ),
        ),
        Text(
          lat != null ? lat.toStringAsFixed(6) : '?.??????',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          ', ',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
        Text(
          lon != null ? lon.toStringAsFixed(6) : '?.??????',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontFamily: 'monospace',
          ),
        ),
        if (accuracy != null)
          Text(
            ' (±${accuracy.toStringAsFixed(1)}m)',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 9,
              fontFamily: 'monospace',
            ),
          ),
      ],
    );
  }

  Color _getPhaseColor(MissionPhase? phase) {
    return switch (phase) {
      MissionPhase.enRoute => const Color(0xFFffa726),
      MissionPhase.nearTarget => const Color(0xFF42a5f5),
      MissionPhase.success => const Color(0xFF66bb6a),
      MissionPhase.failed => const Color(0xFFef5350),
      null => Colors.grey,
    };
  }

  Widget _buildProgressCard(BuildContext context, MissionState? missionState) {
    final points = missionState?.score.points ?? 0;
    final maxPoints = 100;
    final progress = (points / maxPoints).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF66bb6a).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.emoji_events_rounded,
                      color: Color(0xFF66bb6a),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Puan',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF66bb6a).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '$points',
                  style: const TextStyle(
                    color: Color(0xFF66bb6a),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(
                progress >= 1.0
                    ? const Color(0xFF66bb6a)
                    : const Color(0xFFe94560),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(progress * 100).toInt()}% tamamlandı',
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 16),
          // Play Game button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _startGameMode(context),
              icon: const Icon(Icons.play_arrow, size: 20),
              label: const Text(
                'Oyunu Başlat',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFe94560),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Navigate to game page.
  void _startGameMode(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const GameMapPage()));
  }

  Widget _buildAiNarrationCard(BuildContext context, aiNarration) {
    final hasNarration = aiNarration?.missionExplanation != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasNarration
              ? [
                  const Color(0xFF7c3aed).withValues(alpha: 0.3),
                  const Color(0xFF7c3aed).withValues(alpha: 0.1),
                ]
              : [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasNarration
              ? const Color(0xFF7c3aed).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF7c3aed).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFF7c3aed),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI Asistan',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (hasNarration) ...[
                const Spacer(),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF66bb6a),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  'Aktif',
                  style: TextStyle(
                    color: Color(0xFF66bb6a),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          if (hasNarration)
            Text(
              aiNarration.missionExplanation!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.5,
              ),
            )
          else
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Hedefe yaklaştığınızda bilgi alacaksınız',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// AI Assistant card - shows results from the real AI backend.
  Widget _buildAiAssistantCard(BuildContext context, MissionProvider provider) {
    final isLoading = provider.aiLoading;
    final aiError = provider.aiError;
    final aiResult = provider.aiResult;
    final hasResult = aiResult != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: hasResult && aiResult.isOk
              ? [
                  const Color(0xFF10b981).withValues(alpha: 0.25),
                  const Color(0xFF10b981).withValues(alpha: 0.1),
                ]
              : hasResult && !aiResult.isOk
              ? [
                  const Color(0xFFf59e0b).withValues(alpha: 0.25),
                  const Color(0xFFf59e0b).withValues(alpha: 0.1),
                ]
              : [
                  Colors.white.withValues(alpha: 0.15),
                  Colors.white.withValues(alpha: 0.05),
                ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasResult && aiResult.isOk
              ? const Color(0xFF10b981).withValues(alpha: 0.5)
              : hasResult && !aiResult.isOk
              ? const Color(0xFFf59e0b).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10b981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.smart_toy_outlined,
                  color: Color(0xFF10b981),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'AI Asistan',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              // Ask button
              InkWell(
                onTap: () => _showAskDialog(context, provider),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10b981).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        color: Colors.white,
                        size: 14,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Sor',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Content based on state
          if (isLoading)
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF10b981),
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  'Yanıt hazırlanıyor...',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            )
          else if (aiError != null)
            Text(
              aiError,
              style: const TextStyle(color: Color(0xFFef5350), fontSize: 13),
            )
          else if (hasResult && aiResult.isOk)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Answer text
                Text(
                  aiResult.missionExplanation ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                // Actions
                if (aiResult.nextActions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  ...aiResult.nextActions.map(
                    (action) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '• ',
                            style: TextStyle(color: Colors.white70),
                          ),
                          Expanded(
                            child: Text(
                              action,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                // Source chips
                if (aiResult.sources.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: aiResult.sources.map((sourceId) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10b981).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(
                              0xFF10b981,
                            ).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          sourceId,
                          style: const TextStyle(
                            color: Color(0xFF10b981),
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            )
          else if (hasResult && !aiResult.isOk)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message
                Text(
                  aiResult.message ?? 'Bilgi bulunamadı.',
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                // Suggestions
                if (aiResult.suggestions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Öneriler:',
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...aiResult.suggestions.map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '• $s',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            )
          else
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: Colors.white.withValues(alpha: 0.4),
                  size: 16,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Soru sormak için "Sor" butonuna tıklayın',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Shows a dialog for asking the AI assistant a question.
  void _showAskDialog(BuildContext context, MissionProvider provider) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1a1a2e),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: const Color(0xFF10b981).withValues(alpha: 0.3),
          ),
        ),
        title: const Row(
          children: [
            Icon(Icons.smart_toy_outlined, color: Color(0xFF10b981)),
            SizedBox(width: 10),
            Text(
              'AI Asistana Sor',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Sorunuzu yazın...',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('İptal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () {
              final query = controller.text.trim();
              if (query.isNotEmpty) {
                Navigator.of(dialogContext).pop();
                provider.askAssistant(query);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10b981),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Gönder', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationFAB(BuildContext context, MissionProvider provider) {
    // Debug-only simulation button
    final isDebugMode = kDebugMode;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (isDebugMode ? const Color(0xFFffa726) : Colors.grey)
                .withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: FloatingActionButton.extended(
        // Only enabled in debug mode
        onPressed: isDebugMode ? () => provider.simulateMovement() : null,
        backgroundColor: isDebugMode
            ? const Color(0xFFffa726)
            : Colors.grey.shade700,
        foregroundColor: Colors.white,
        elevation: 0,
        icon: const Icon(Icons.bug_report, size: 20),
        label: Text(
          isDebugMode ? 'Simüle Et (Debug)' : 'Debug Kapalı',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
