// One object that carries all the services, so screens receive a single
// parameter ("services") instead of four. Created once in app.dart.
import 'auth_service.dart';
import 'history_service.dart';
import 'prediction_service.dart';
import 'profile_service.dart';

class AppServices {
  AppServices({
    required this.auth,
    PredictionService? predictions,
    HistoryService? history,
    ProfileService? profile,
  })  : predictions = predictions ?? DemoPredictionService(), // "??" = use this if null
        history = history ?? HistoryService(),
        profile = profile ?? ProfileService();

  final AuthService auth;
  final PredictionService predictions;
  final HistoryService history;
  final ProfileService profile; // My details, Medical history, Lifestyle check

  /// Called once per login (HomeShell). If a different person signs in on the
  /// same device, each service forgets the previous user's data first.
  void startSession(String uid) {
    profile.startSession(uid);
    history.startSession(uid);
  }
}
