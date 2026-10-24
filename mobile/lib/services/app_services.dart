// One object that carries all the services, so screens receive a single
// parameter ("services") instead of three. Created once in app.dart.
import 'auth_service.dart';
import 'history_service.dart';
import 'prediction_service.dart';

class AppServices {
  AppServices({required this.auth, PredictionService? predictions, HistoryService? history})
      : predictions = predictions ?? PredictionService(), // "??" = use this if null
        history = history ?? HistoryService();

  final AuthService auth;
  final PredictionService predictions;
  final HistoryService history;
}
