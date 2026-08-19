import 'package:aegivue/features/recordings/domain/recording.dart';

class RecordingPage {
  const RecordingPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalItems,
    required this.totalPages,
  });

  final List<Recording> items;
  final int page;
  final int pageSize;
  final int totalItems;
  final int totalPages;

  bool get hasMore => page < totalPages;
}
