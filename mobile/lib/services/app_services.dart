// One object that carries all the services, so screens receive a single
// parameter ("services") instead of five. Created once in app.dart.
import 'auth_service.dart';
import 'history_service.dart';
import 'prediction_service.dart';
import 'profile_service.dart';
import 'tutorial_service.dart';

class AppServices {
  AppServices({
    required this.auth,
    PredictionService? predictions,
    HistoryService? history,
    ProfileService? profile,
    TutorialService? tutorials,
  })  : predictions = predictions ?? DemoPredictionService(), // "??" = use this if null
        history = history ?? HistoryService(),
        profile = profile ?? ProfileService(),
        tutorials = tutorials ?? TutorialService();

  final AuthService auth;               // sign in / out (Firebase Auth)
  final PredictionService predictions;  // the AI (FastAPI backend)
  final HistoryService history;         // past deep-check results
  final ProfileService profile;         // My details, Medical history, Lifestyle check
  final TutorialService tutorials;      // Health guides (assets/tutorials.json)

  /// Called once per login (HomeShell). If a different person signs in on the
  /// same device, each service forgets the previous user's data first.
  void startSession(String uid) {
    profile.startSession(uid);
    history.startSession(uid);
  }
}
