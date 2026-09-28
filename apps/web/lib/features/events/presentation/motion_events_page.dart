import 'package:aegivue/features/events/domain/event.dart';
import 'package:aegivue/features/events/presentation/widgets/motion_event_card.dart';
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
          return MotionEventCard(event: widget.events[index]);
        },
      ),
    );
  }
}
