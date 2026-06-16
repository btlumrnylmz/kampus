import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../game_controller.dart';
import '../theme/game_theme.dart';

/// Enhanced game HUD overlay with glassmorphism styling.
/// 
/// Features:
/// - Top HUD panel with game mode label, score, and exit button
/// - Status row showing GPS status, mode, and nearest collectible distance
/// - Matches existing dark theme with glassmorphism effects
class GameHUD extends StatelessWidget {
  const GameHUD({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<GameController>(
      builder: (context, gameController, _) {
        if (!gameController.isGameActive) {
          return const SizedBox.shrink();
        }

        return Stack(
          children: [
            // Top HUD panel
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Main HUD card
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: GameTheme.glassCard(
                          borderRadius: 24,
                          borderColor: Colors.white,
                          borderOpacity: 0.2,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Top row: Game mode label + Exit button
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Left: Game mode label
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'GAME MODE',
                                      style: GameTheme.labelStyle.copyWith(
                                        fontSize: 10,
                                        letterSpacing: 2,
                                        color: GameTheme.amberAccent,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Collectibles Hunt',
                                      style: GameTheme.titleStyle.copyWith(
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                // Right: Exit button (amber styled)
                                _buildExitButton(context, gameController),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Center: Score pill
                            _buildScorePill(gameController),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Status row (compact)
                      _buildStatusRow(gameController),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Large score pill in the center of HUD.
  Widget _buildScorePill(GameController gameController) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GameTheme.successGreen.withValues(alpha: 0.3),
            GameTheme.successGreen.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: GameTheme.successGreen.withValues(alpha: 0.5),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.emoji_events_rounded,
            color: GameTheme.successGreen,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            '${gameController.score}',
            style: GameTheme.valueStyle.copyWith(
              fontSize: 32,
              color: GameTheme.successGreen,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact status row showing GPS, mode, and nearest collectible.
  Widget _buildStatusRow(GameController gameController) {
    // Find nearest collectible distance
    double? nearestDistance;
    if (gameController.playerLocation != null) {
      for (final collectible in gameController.collectibles) {
        final distance = gameController.getDistanceToCollectible(collectible.id);
        if (distance != null) {
          if (nearestDistance == null || distance < nearestDistance) {
            nearestDistance = distance;
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: GameTheme.glassCard(
        borderRadius: 16,
        borderOpacity: 0.15,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // GPS status
          _buildStatusItem(
            icon: Icons.gps_fixed,
            label: 'GPS',
            value: 'ON',
            color: GameTheme.successGreen,
          ),
          // Divider
          Container(
            width: 1,
            height: 20,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          // Mode
          _buildStatusItem(
            icon: Icons.location_on,
            label: 'MODE',
            value: 'REAL',
            color: GameTheme.amberAccent,
          ),
          // Divider
          Container(
            width: 1,
            height: 20,
            color: Colors.white.withValues(alpha: 0.2),
          ),
          // Nearest collectible
          _buildStatusItem(
            icon: Icons.star,
            label: 'NEAREST',
            value: nearestDistance != null
                ? '${nearestDistance.toStringAsFixed(0)}m'
                : '-',
            color: GameTheme.warningOrange,
          ),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(height: 4),
        Text(
          value,
          style: GameTheme.valueStyle.copyWith(
            fontSize: 12,
            color: color,
          ),
        ),
        Text(
          label,
          style: GameTheme.labelStyle.copyWith(fontSize: 9),
        ),
      ],
    );
  }

  /// Exit button styled like existing amber buttons.
  Widget _buildExitButton(BuildContext context, GameController gameController) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          gameController.stopGame();
          Navigator.of(context).pop();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                GameTheme.amberAccent.withValues(alpha: 0.3),
                GameTheme.amberAccent.withValues(alpha: 0.2),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: GameTheme.amberAccent.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.exit_to_app,
                color: GameTheme.amberAccent,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                'Exit',
                style: GameTheme.labelStyle.copyWith(
                  color: GameTheme.amberAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
