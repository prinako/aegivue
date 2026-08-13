class Camera {
  const Camera({required this.id, required this.name, required this.enabled});
  final String id;
  final String name;
  final bool enabled;
  factory Camera.fromJson(Map<String, Object?> json) => Camera(
    id: json['id']! as String,
    name: json['name']! as String,
    enabled: json['enabled']! as bool,
  );
}
