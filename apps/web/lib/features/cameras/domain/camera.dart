class Camera {
  const Camera({
    required this.id,
    required this.name,
    required this.enabled,
    this.runtimeState = 'offline',
  });
  final String id;
  final String name;
  final bool enabled;
  final String runtimeState;
  Camera withRuntimeState(String value) =>
      Camera(id: id, name: name, enabled: enabled, runtimeState: value);
  factory Camera.fromJson(Map<String, Object?> json) => Camera(
    id: json['id']! as String,
    name: json['name']! as String,
    enabled: json['enabled']! as bool,
  );
}
