class CameraConnection {
  const CameraConnection({
    required this.host,
    required this.port,
    required this.mainStream,
    this.username,
    this.subStream,
  });

  final String host;
  final int port;
  final String? username;
  final String mainStream;
  final String? subStream;

  factory CameraConnection.fromJson(Map<String, Object?> json) =>
      CameraConnection(
        host: json['host']! as String,
        port: (json['port']! as num).toInt(),
        username: json['username'] as String?,
        mainStream: json['mainStream']! as String,
        subStream: json['subStream'] as String?,
      );
}
