import 'core/api_client.dart';
import 'features/cameras/data/camera_repository.dart';
import 'features/cameras/domain/camera.dart';
import 'features/recordings/data/recording_repository.dart';
import 'features/recordings/domain/recording.dart';

class DashboardData {
  const DashboardData(this.cameras, this.recordings);
  final List<Camera> cameras;
  final List<Recording> recordings;
}

class DashboardController {
  DashboardController(ApiClient api)
    : cameras = CameraRepository(api),
      recordings = RecordingRepository(api);
  final CameraRepository cameras;
  final RecordingRepository recordings;
  Future<DashboardData> load() async {
    final values = await Future.wait<Object>([
      cameras.list(),
      recordings.list(),
    ]);
    return DashboardData(
      values[0] as List<Camera>,
      values[1] as List<Recording>,
    );
  }
}
