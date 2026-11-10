// Where the FastAPI backend (the AI) is, as seen from the device the app runs on.
//
// Same idea as the Firebase emulator in firebase_config.dart: the API runs on
// your PC (uvicorn backend.app.main:app, port 8000), and each device reaches the
// PC by a different address:
//   Chrome / iOS simulator   http://127.0.0.1:8000
//   Android emulator         http://10.0.2.2:8000
//   Real phone on Wi-Fi      flutter run --dart-define=EMULATOR_HOST=<PC's IP>
//                            (start uvicorn with --host 0.0.0.0 so the phone can reach it)
// Or set it directly:        flutter run --dart-define=API_URL=https://your-server
import 'firebase_config.dart' show emulatorHost;

const String _apiUrlOverride = String.fromEnvironment('API_URL');
const int apiPort = 8000;

/// Run the app WITHOUT the API (sample percentages, as before):
///   flutter run -d chrome --dart-define=USE_DEMO_PREDICTIONS=true
const bool useDemoPredictions = bool.fromEnvironment('USE_DEMO_PREDICTIONS');

String apiBaseUrl() =>
    _apiUrlOverride.isNotEmpty ? _apiUrlOverride : 'http://${emulatorHost()}:$apiPort';
