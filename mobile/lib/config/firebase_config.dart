// Which Firebase the app talks to.
//
// NOW (no Firebase project yet): the local emulators (Auth + Firestore) from
// firebase/ in the repo, using a "demo-" project. The options below are
// placeholders - the emulators don't check them.
//
// LATER (real project): run `flutterfire configure` in mobile/. It generates
// lib/firebase_options.dart; then return DefaultFirebaseOptions.currentPlatform
// from firebaseOptions() and run with --dart-define=USE_EMULATOR=false.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Turn the emulator off with:  flutter run --dart-define=USE_EMULATOR=false
const bool useEmulator = bool.fromEnvironment('USE_EMULATOR', defaultValue: true);

/// Optional override, e.g. a real phone on Wi-Fi needs your PC's LAN IP:
///   flutter run --dart-define=EMULATOR_HOST=192.168.1.20
const String _emulatorHostOverride = String.fromEnvironment('EMULATOR_HOST');

/// The emulator ports, the same as firebase/firebase.json. Override them only if
/// you start the emulators on other ports, e.g.
///   flutter run --dart-define=FIRESTORE_EMULATOR_PORT=8180
const int authEmulatorPort = int.fromEnvironment('AUTH_EMULATOR_PORT', defaultValue: 9099);
const int firestoreEmulatorPort = int.fromEnvironment('FIRESTORE_EMULATOR_PORT', defaultValue: 8080);

const String demoProjectId = 'demo-fyp-chronic'; // same as firebase/.firebaserc

/// Where the emulator is, as seen from the device the app runs on.
String emulatorHost() {
  if (_emulatorHostOverride.isNotEmpty) return _emulatorHostOverride;
  // The Android emulator is its own virtual machine: inside it, 127.0.0.1 is
  // the phone itself. 10.0.2.2 is the special address for "the PC".
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) return '10.0.2.2';
  return '127.0.0.1'; // web (Chrome) and iOS simulator share the PC's network
}

FirebaseOptions firebaseOptions() {
  final String platform = kIsWeb
      ? 'web'
      : (defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
  return FirebaseOptions(
    apiKey: 'demo-api-key',
    appId: '1:000000000000:$platform:0000000000000000',
    messagingSenderId: '000000000000',
    projectId: demoProjectId,
  );
}
