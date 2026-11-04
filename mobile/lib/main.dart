// App start-up: connect to Firebase, then show the app.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config/api_config.dart';
import 'config/firebase_config.dart';
import 'services/auth_service.dart';
import 'services/prediction_service.dart';

Future<void> main() async {
  // Needed before calling plugins (Firebase) before runApp().
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: firebaseOptions());
  if (useEmulator) {
    // Must run before any sign-in call. Points Auth at the local emulator
    // started from firebase/ (docs/DATABASE.md).
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost(), authEmulatorPort);
  }

  final auth = FirebaseAuthService(FirebaseAuth.instance);
  // The real AI (FastAPI backend), unless run with --dart-define=USE_DEMO_PREDICTIONS=true
  final PredictionService predictions = useDemoPredictions
      ? DemoPredictionService()
      : ApiPredictionService(baseUrl: apiBaseUrl(), idToken: auth.idToken);

  runApp(App(auth: auth, predictions: predictions));
}
