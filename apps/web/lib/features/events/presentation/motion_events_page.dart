import 'package:aegivue/features/events/domain/event.dart';
import 'package:flutter/material.dart';

class MotionEventsPage extends StatefulWidget {
  static const id = '/motion-events';
  const MotionEventsPage({
    super.key,
    required this.events,
    required this.onRefresh,
    required this.onLoadMore,
    required this.hasMore,
    required this.loadingMore,
  });

  final List<AegivueEvent> events;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onLoadMore;
  final bool hasMore;
  final bool loadingMore;

  @override
  State<MotionEventsPage> createState() => _MotionEventsPageState();
}

class _MotionEventsPageState extends State<MotionEventsPage> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (!widget.hasMore || widget.loadingMore) return;
    if (_scrollController.position.extentAfter < 400) {
      widget.onLoadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.events.isEmpty) {
      return RefreshIndicator(
        onRefresh: widget.onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 160),
            Icon(
              Icons.motion_photos_off_outlined,
              size: 48,
              color: Colors.white38,
            ),
            SizedBox(height: 12),
            Center(
              child: Text(
                'No motion events yet',
                style: TextStyle(color: Colors.white60),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        itemCount: widget.events.length + (widget.loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= widget.events.length) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _MotionEventCard(event: widget.events[index]);
        },
      ),
    );
  }
}

class _MotionEventCard extends StatelessWidget {
  const _MotionEventCard({required this.event});

  final AegivueEvent event;

  @override
  Widget build(BuildContext context) {
    final metadata = event.metadata;
    final stream = metadata['stream']?.toString();
    final detector = metadata['detector']?.toString();
    final fps = metadata['analysisFps'];
    final sensitivity = metadata['sensitivity'];
    final score = event.score;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                event.active ? Icons.sensors : Icons.directions_run_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          event.cameraName,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _StatusChip(active: event.active),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTimestamp(event.startedAt.toLocal()),
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (score != null)
                        _MetaChip(
                          label: 'Score ${(score * 100).toStringAsFixed(1)}%',
                        ),
                      if (event.duration != null)
                        _MetaChip(
                          label: 'Duration ${_formatDuration(event.duration!)}',
                        ),
                      if (stream != null) _MetaChip(label: 'Stream $stream'),
                      if (fps != null) _MetaChip(label: '$fps fps'),
                      if (sensitivity != null)
                        _MetaChip(label: 'Sensitivity $sensitivity'),
                      if (detector != null) _MetaChip(label: detector),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: active
            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.14)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Active' : 'Ended',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: active
              ? Theme.of(context).colorScheme.primary
              : Colors.white60,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 11, color: Colors.white70),
      ),
    );
  }
}

String _formatTimestamp(DateTime value) {
  String two(int number) => number.toString().padLeft(2, '0');
  return '${value.year}-${two(value.month)}-${two(value.day)} '
      '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
}

String _formatDuration(Duration value) {
  if (value.inSeconds < 60) return '${value.inSeconds}s';
  final minutes = value.inMinutes;
  final seconds = value.inSeconds.remainder(60);
  return '${minutes}m ${seconds}s';
}
