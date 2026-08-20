class AegivueEvent {
  const AegivueEvent({
    required this.id,
    required this.cameraId,
    required this.cameraName,
    required this.kind,
    required this.startedAt,
    required this.endedAt,
    required this.score,
    required this.metadata,
  });

  final String id;
  final String cameraId;
  final String cameraName;
  final String kind;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double? score;
  final Map<String, Object?> metadata;

  bool get active => endedAt == null;

  Duration? get duration => endedAt?.difference(startedAt);

  factory AegivueEvent.fromJson(Map<String, Object?> json) => AegivueEvent(
    id: json['id']! as String,
    cameraId: json['cameraId']! as String,
    cameraName: json['cameraName']! as String,
    kind: json['kind']! as String,
    startedAt: DateTime.parse(json['startedAt']! as String),
    endedAt: json['endedAt'] == null
        ? null
        : DateTime.parse(json['endedAt']! as String),
    score: (json['score'] as num?)?.toDouble(),
    metadata: Map<String, Object?>.from(
      (json['metadata'] as Map?)?.cast<String, Object?>() ?? const {},
    ),
  );
}
