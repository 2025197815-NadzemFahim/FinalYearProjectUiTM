// The Home / History / Profile bar at the bottom of 7 mockups.
//
// The SAME widget is used by HomeShell (the three tab pages) and by the
// prediction screens opened from Home, so the bar looks identical everywhere.
import 'package:flutter/material.dart';

import '../navigation/app_tabs.dart';
import '../theme/app_theme.dart';

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentIndex});

  /// Which tab is highlighted green (AppTabs.home / history / profile).
  final int currentIndex;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      // The thin grey line along the top of the bar in the mockup.
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        // What happens on tap: switch to that tab (closing any pushed screens).
        onTap: (index) => AppTabs.goTo(context, index),
        type: BottomNavigationBarType.fixed, // all labels always visible
        backgroundColor: Colors.white,
        elevation: 0,
        selectedItemColor: AppColors.green,  // selected tab colour
        unselectedItemColor: Colors.black,   // other tabs
        selectedLabelStyle: AppFonts.body(size: 12, color: AppColors.green),
        unselectedLabelStyle: AppFonts.body(size: 12),
        items: const [
          // To add a tab: add an item here AND a page in home_shell.dart.
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined, size: 30), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.receipt_long_outlined, size: 30), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline, size: 30), label: 'Profile'),
        ],
      ),
    );
  }
}
