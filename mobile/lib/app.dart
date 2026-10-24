import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'services/app_services.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

/// The root widget. MaterialApp sets up the theme and the first screen.
class App extends StatelessWidget {
  // The auth service is passed in (not created here) so tests can give a fake one.
  App({super.key, required AuthService auth}) : services = AppServices(auth: auth);

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chronic Disease Early Prediction',
      debugShowCheckedModeBanner: false, // hides the red "DEBUG" ribbon
      theme: AppTheme.light(),
      home: AuthGate(services: services),
    );
  }
}
