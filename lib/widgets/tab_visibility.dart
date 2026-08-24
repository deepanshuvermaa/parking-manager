import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Publishes "which tab am I, and which tab is showing" to a tab's subtree.
///
/// The bottom-nav shell keeps every tab alive in an [IndexedStack] so that
/// in-progress work — a half-typed plate, the last receipt available for
/// reprint — survives a tab switch. The cost of keeping screens alive is that
/// `initState` no longer re-runs on every visit, which is where the data-driven
/// screens used to refresh themselves. This scope restores that explicitly:
/// screens declare when they want to reload instead of relying on being
/// destroyed and rebuilt.
class TabIndexScope extends InheritedWidget {
  const TabIndexScope({
    super.key,
    required this.index,
    required this.activeIndex,
    required super.child,
  });

  /// The index this subtree occupies in the shell.
  final int index;

  /// The tab currently on screen.
  final ValueListenable<int> activeIndex;

  static TabIndexScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TabIndexScope>();

  @override
  bool updateShouldNotify(TabIndexScope oldWidget) =>
      index != oldWidget.index || activeIndex != oldWidget.activeIndex;
}

/// Reloads a screen when its tab comes back into view.
///
/// Mix in and implement [onTabVisible]. It fires on the transition from hidden
/// to visible only — never on first build (the screen's own `initState` already
/// loaded), and never repeatedly while the tab stays open.
///
/// Screens outside a [TabIndexScope] (pushed routes, tests) simply never get
/// the callback, so the mixin is safe to apply anywhere.
mixin RefreshOnTabVisible<T extends StatefulWidget> on State<T> {
  ValueListenable<int>? _activeIndex;
  int? _myIndex;
  bool _wasVisible = false;

  /// Called when this tab becomes the visible one again.
  void onTabVisible();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = TabIndexScope.maybeOf(context);
    if (scope == null) return;

    if (!identical(scope.activeIndex, _activeIndex)) {
      _activeIndex?.removeListener(_handleVisibilityChange);
      _activeIndex = scope.activeIndex;
      _activeIndex!.addListener(_handleVisibilityChange);
    }
    _myIndex = scope.index;
    // Seed without firing: if we are the visible tab right now, this is the
    // first build and initState has already loaded.
    _wasVisible = _activeIndex!.value == _myIndex;
  }

  void _handleVisibilityChange() {
    if (!mounted) return;
    final isVisible = _activeIndex?.value == _myIndex;
    if (isVisible && !_wasVisible) {
      onTabVisible();
    }
    _wasVisible = isVisible;
  }

  @override
  void dispose() {
    _activeIndex?.removeListener(_handleVisibilityChange);
    super.dispose();
  }
}
