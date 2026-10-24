// The signed-in part of the app: three tab pages + the bottom bar.
//
// IndexedStack keeps ALL three pages alive and only shows one, so switching
// tabs doesn't lose your scroll position. ValueListenableBuilder rebuilds this
// widget whenever AppTabs.current changes (i.e. when a tab is tapped).
import 'package:flutter/material.dart';

import '../navigation/app_tabs.dart';
import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../widgets/app_bottom_nav.dart';
import 'history_screen.dart';
import 'main_screen.dart';
import 'profile_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.services, required this.user});

  final AppServices services;
  final AppUser user;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    // initState runs once, when the shell first appears (i.e. right after
    // login), so every login starts on the Home tab.
    AppTabs.current.value = AppTabs.home;
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.services, user = widget.user;
    return ValueListenableBuilder<int>(
      valueListenable: AppTabs.current,
      builder: (context, tab, _) => Scaffold(
        body: IndexedStack(
          index: tab,
          // The order here must match the items in AppBottomNav.
          children: [
            MainScreen(services: services, user: user),   // AppTabs.home
            HistoryScreen(services: services),             // AppTabs.history
            ProfileScreen(services: services, user: user), // AppTabs.profile
          ],
        ),
        bottomNavigationBar: AppBottomNav(currentIndex: tab),
      ),
    );
  }
}
