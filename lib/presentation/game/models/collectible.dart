import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Represents a collectible item in the game.
@immutable
class Collectible {
  final String id;
  final LatLng position;
  final int points;
  final bool isCollected;
  final DateTime createdAt;

  const Collectible({
    required this.id,
    required this.position,
    this.points = 10,
    this.isCollected = false,
    required this.createdAt,
  });

  Collectible copyWith({
    String? id,
    LatLng? position,
    int? points,
    bool? isCollected,
    DateTime? createdAt,
  }) {
    return Collectible(
      id: id ?? this.id,
      position: position ?? this.position,
      points: points ?? this.points,
      isCollected: isCollected ?? this.isCollected,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Collectible &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}


