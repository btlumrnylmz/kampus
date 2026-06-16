import 'package:flutter/material.dart';

/// Enhanced animated marker widget for collectible items.
/// 
/// Features:
/// - Gentle pulse animation (always)
/// - Increased glow and scale when nearby (within 30m)
/// - Smooth transitions
class CollectibleMarker extends StatefulWidget {
  final String id;
  final bool isNearby; // Within 30m
  final VoidCallback? onTap;

  const CollectibleMarker({
    super.key,
    required this.id,
    this.isNearby = false,
    this.onTap,
  });

  @override
  State<CollectibleMarker> createState() => _CollectibleMarkerState();
}

class _CollectibleMarkerState extends State<CollectibleMarker>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // Gentle pulse animation (always active)
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Opacity pulse
    _pulseAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    // Glow intensity (increases when nearby)
    _glowAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(CollectibleMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animation continues regardless of nearby state
    // Nearby state affects visual intensity only
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // Scale: slightly larger when nearby
          final baseScale = widget.isNearby ? 1.15 : 1.0;
          final scale = baseScale * _scaleAnimation.value;

          // Opacity: more visible when nearby
          final baseOpacity = widget.isNearby ? 1.0 : 0.8;
          final opacity = baseOpacity * _pulseAnimation.value;

          // Glow: stronger when nearby
          final glowIntensity = widget.isNearby
              ? _glowAnimation.value
              : _glowAnimation.value * 0.5;

          return Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: opacity,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer glow ring (pulsing)
                  Container(
                    width: 50 + (glowIntensity * 10),
                    height: 50 + (glowIntensity * 10),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFffa726)
                              .withValues(alpha: glowIntensity * 0.6),
                          blurRadius: 20 + (glowIntensity * 10),
                          spreadRadius: 2 + (glowIntensity * 3),
                        ),
                      ],
                    ),
                  ),
                  // Main marker
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFFffa726).withValues(alpha: opacity),
                          const Color(0xFFffa726)
                              .withValues(alpha: opacity * 0.7),
                        ],
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFffa726)
                              .withValues(alpha: glowIntensity * 0.8),
                          blurRadius: 15,
                          spreadRadius: 3,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.star,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
