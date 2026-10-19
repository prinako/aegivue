import 'package:flutter/widgets.dart';

typedef AppHeaderActionsBuilder = Widget Function(BuildContext context);
typedef AppHeaderRefresh = Future<void> Function();

class AppHeaderActionsViewModel extends ChangeNotifier {
  final Map<int, _HeaderActionsRegistration> _registrations = {};

  Widget? buildActions(BuildContext context, int section) {
    return _registrations[section]?.builder(context);
  }

  AppHeaderRefresh? refreshFor(int section) =>
      _registrations[section]?.onRefresh;

  void register({
    required int section,
    required Object owner,
    required AppHeaderActionsBuilder builder,
    AppHeaderRefresh? onRefresh,
  }) {
    _registrations[section] = _HeaderActionsRegistration(
      owner,
      builder,
      onRefresh,
    );
    notifyListeners();
  }

  void refresh(int section) {
    if (_registrations.containsKey(section)) notifyListeners();
  }

  void unregister({required int section, required Object owner}) {
    if (_registrations[section]?.owner != owner) return;
    _registrations.remove(section);
    notifyListeners();
  }
}

class _HeaderActionsRegistration {
  const _HeaderActionsRegistration(this.owner, this.builder, this.onRefresh);

  final Object owner;
  final AppHeaderActionsBuilder builder;
  final AppHeaderRefresh? onRefresh;
}
