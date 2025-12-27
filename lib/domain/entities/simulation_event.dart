enum SimulationEventType { success, info, penalty }

class SimulationEvent {
  final String id;
  final SimulationEventType type;
  final String description;
  final List<String> relatedIds;

  const SimulationEvent({
    required this.id,
    required this.type,
    required this.description,
    required this.relatedIds,
  });
}


