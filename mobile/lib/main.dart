// App start-up: connect to Firebase, then show the app.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config/api_config.dart';
import 'config/firebase_config.dart';
import 'services/auth_service.dart';
import 'services/history_service.dart';
import 'services/prediction_service.dart';
import 'services/profile_service.dart';

Future<void> main() async {
  // Needed before calling plugins (Firebase) before runApp().
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: firebaseOptions());

  if (useEmulator) {
    // Points Auth and Firestore at the local emulators started from firebase/
    // (docs/DATABASE.md). Both must run before anything else uses Auth or
    // Firestore. (Web release builds only: reloading the page while signed in
    // signs you out, because FlutterFire restores the login before this line
    // runs. `flutter run -d chrome` is a debug build and is not affected.)
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost(), authEmulatorPort);
    FirebaseFirestore.instance.useFirestoreEmulator(emulatorHost(), firestoreEmulatorPort);
  }

  final db = FirebaseFirestore.instance;
  final auth = FirebaseAuthService(FirebaseAuth.instance);

  // The real AI (FastAPI backend), unless run with --dart-define=USE_DEMO_PREDICTIONS=true
  final PredictionService predictions = useDemoPredictions
      ? DemoPredictionService()
      : ApiPredictionService(baseUrl: apiBaseUrl(), idToken: auth.idToken);

  runApp(App(
    auth: auth,
    predictions: predictions,
    profile: ProfileService(db: db), // saved details: users/{uid}
    history: HistoryService(db: db), // past results: users/{uid}/deepCheckResults
  ));
}
