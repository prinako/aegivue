import 'package:flutter/material.dart';

class AppHeaderWidget extends StatefulWidget {
  const AppHeaderWidget({
    super.key,
    required this.title,
    required this.onRefresh,
    this.onAdd,
    this.actions,
  });

  final String title;
  final Future<void> Function() onRefresh;
  final VoidCallback? onAdd;
  final Widget? actions;

  @override
  State<AppHeaderWidget> createState() => _AppHeaderWidgetState();
}

class _AppHeaderWidgetState extends State<AppHeaderWidget> {
  bool _refreshing = false;

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 74),
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final title = Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Text(
                'Security monitoring console',
                style: TextStyle(color: Colors.white54, fontSize: 11),
              ),
            ],
          );
          final refresh = IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          );
          final trailing = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              refresh,
              if (widget.onAdd != null) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: widget.onAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add camera'),
                ),
              ],
            ],
          );
          final actions = widget.actions;
          if (actions == null || constraints.maxWidth >= 900) {
            return Row(
              children: [
                Expanded(child: title),
                if (actions != null) ...[
                  Flexible(child: actions),
                  const SizedBox(width: 8),
                ],
                trailing,
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Expanded(child: title),
                      trailing,
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                SizedBox(height: 48, child: actions),
              ],
            ),
          );
        },
      ),
    );
  }
}
