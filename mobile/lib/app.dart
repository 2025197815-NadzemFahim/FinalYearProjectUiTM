import 'package:flutter/material.dart';

import 'screens/auth_gate.dart';
import 'services/app_services.dart';
import 'services/auth_service.dart';
import 'services/prediction_service.dart';
import 'services/profile_service.dart';
import 'theme/app_theme.dart';

/// The root widget. MaterialApp sets up the theme and the first screen.
class App extends StatelessWidget {
  // The services are passed in (not created here) so tests can give fake ones,
  // e.g. a ProfileService that already has a complete profile.
  // main.dart passes the real AI (ApiPredictionService); tests leave it out and
  // get the sample numbers (DemoPredictionService).
  App({super.key, required AuthService auth, ProfileService? profile,
      PredictionService? predictions})
      : services = AppServices(auth: auth, profile: profile, predictions: predictions);

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
