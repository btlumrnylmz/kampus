/// Type of navigation instruction.
enum NavigationInstructionType {
  straight,
  turnLeft,
  turnRight,
  slightLeft,
  slightRight,
  uTurn,
  arrive,
}

/// A turn-by-turn navigation instruction.
/// 
/// Pure Dart domain entity - no Flutter or map dependencies.
class NavigationInstruction {
  /// Human-readable instruction text.
  final String text;

  /// Type of maneuver.
  final NavigationInstructionType type;

  /// Distance in meters to this maneuver point (null if arrived).
  final double? distanceMeters;

  /// Bearing change in degrees (positive = right, negative = left).
  final double? bearingChange;

  const NavigationInstruction({
    required this.text,
    required this.type,
    this.distanceMeters,
    this.bearingChange,
  });

  /// Creates an "arrive" instruction.
  factory NavigationInstruction.arrive() {
    return const NavigationInstruction(
      text: 'Hedefe ulaştın!',
      type: NavigationInstructionType.arrive,
    );
  }

  /// Creates a "go straight" instruction.
  factory NavigationInstruction.straight({required double distanceMeters}) {
    return NavigationInstruction(
      text: 'Düz devam et (${distanceMeters.toStringAsFixed(0)} m)',
      type: NavigationInstructionType.straight,
      distanceMeters: distanceMeters,
    );
  }

  /// Creates a turn instruction based on bearing change.
  factory NavigationInstruction.fromBearingChange({
    required double bearingChange,
    required double distanceMeters,
  }) {
    final absBearing = bearingChange.abs();
    
    NavigationInstructionType type;
    String direction;

    if (absBearing > 150) {
      type = NavigationInstructionType.uTurn;
      direction = 'geri dön';
    } else if (absBearing > 45) {
      if (bearingChange > 0) {
        type = NavigationInstructionType.turnRight;
        direction = 'sağa dön';
      } else {
        type = NavigationInstructionType.turnLeft;
        direction = 'sola dön';
      }
    } else if (absBearing > 20) {
      if (bearingChange > 0) {
        type = NavigationInstructionType.slightRight;
        direction = 'hafif sağa dön';
      } else {
        type = NavigationInstructionType.slightLeft;
        direction = 'hafif sola dön';
      }
    } else {
      // Very small angle change - treat as straight
      return NavigationInstruction.straight(distanceMeters: distanceMeters);
    }

    return NavigationInstruction(
      text: '${distanceMeters.toStringAsFixed(0)} m sonra $direction',
      type: type,
      distanceMeters: distanceMeters,
      bearingChange: bearingChange,
    );
  }

  @override
  String toString() => 'NavigationInstruction($type: $text)';
}









