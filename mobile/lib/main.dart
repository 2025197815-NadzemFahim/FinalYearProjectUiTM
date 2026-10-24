// App start-up: connect to Firebase, then show the app.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';
import 'config/firebase_config.dart';
import 'services/auth_service.dart';

Future<void> main() async {
  // Needed before calling plugins (Firebase) before runApp().
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: firebaseOptions());
  if (useEmulator) {
    // Must run before any sign-in call. Points Auth at the local emulator
    // started from firebase/ (docs/DATABASE.md).
    await FirebaseAuth.instance.useAuthEmulator(emulatorHost(), authEmulatorPort);
  }

  runApp(App(auth: FirebaseAuthService(FirebaseAuth.instance)));
}
