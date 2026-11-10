// =============================================================================
// NAVIGATION: which bottom-bar tab is selected (Home / History / Profile).
//
// The bottom bar appears on 7 mockups - the 3 tab pages AND the prediction
// screens opened from Home. So the tab choice lives here, in one shared
// "notifier" that any screen can read or change:
//   - HomeShell LISTENS to it and shows the matching tab page.
//   - AppBottomNav CHANGES it when a tab is tapped.
// =============================================================================
import 'package:flutter/material.dart';

class AppTabs {
  static const home = 0;
  static const history = 1;
  static const profile = 2;

  /// A ValueNotifier holds one value and tells listeners when it changes.
  static final ValueNotifier<int> current = ValueNotifier<int>(home);

  /// Switch tab from anywhere. If we're deep inside a pushed screen (e.g. a
  /// Deep-Check result), first close those screens so the tab page is visible.
  static void goTo(BuildContext context, int tab) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    current.value = tab;
  }
}
