abstract final class ApiEndpoints {
  static const cameras = '/api/v1/cameras';
  static const events = '/api/v1/events';
  static const recordings = '/api/v1/recordings';
  static const recordingTimeline = '$recordings/timeline';

  static String camera(String id) => '$cameras/$id';

  static String cameraStatus(String id) => '${camera(id)}/status';
}
