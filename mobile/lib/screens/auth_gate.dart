// Decides which screen to show based on whether someone is signed in.
//
// Screens never "navigate to Login" or "navigate to Home" after signing in or
// out. They just call signIn()/signOut(); Firebase announces the change on
// authStateChanges(), and this StreamBuilder rebuilds with the right screen.
// One place decides, so a signed-out user can never see a private screen.
// Firebase also remembers the session, so reopening the app skips the login.
import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/auth_service.dart';
import 'home_shell.dart';
import 'login_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: services.auth.authStateChanges(),
      builder: (context, snapshot) {
        // Before Firebase answers (a split second at start-up)
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final user = snapshot.data;
        if (user == null) return LoginScreen(services: services);
        return HomeShell(services: services, user: user);
      },
    );
  }
}
