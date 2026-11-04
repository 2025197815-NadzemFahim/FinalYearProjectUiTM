// =============================================================================
// PREDICTION SERVICE: how the app gets risk percentages (task U0).
//
//   PredictionService      what every version must do (the screens only see this)
//   ApiPredictionService   the REAL AI: calls the FastAPI backend
//                          POST /predict/quick and POST /predict/deep/{disease}
//   DemoPredictionService  sample numbers from the mockups, no backend needed
//                          (used by the tests, and by
//                          flutter run --dart-define=USE_DEMO_PREDICTIONS=true)
//
// The request bodies are built in models/api_payloads.dart; this file only
// sends them and turns the answers (or failures) into what the screens show.
// =============================================================================
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/disease.dart';

/// A prediction that couldn't be made. [message] is shown to the user as is.
class PredictionFailure implements Exception {
  const PredictionFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

abstract class PredictionService {
  /// Quick Prediction (Model 1). All three diseases, highest risk first
  /// (report Section 1.6: "display the list ... highest to the lowest").
  Future<List<RiskResult>> quickPredict(Map<String, Object> request);

  /// Deep Check (Model 2) for one disease. The result's [RiskResult.explanation]
  /// holds the model's notes and the disclaimer.
  Future<RiskResult> deepCheck(Disease disease, Map<String, Object> request);

  /// Short sentence for the Quick Prediction Result cards (Figure 3.20).
  static String quickSummary(RiskResult r) =>
      'Your responses indicate a ${r.level.word} risk of ${r.disease.label.toLowerCase()}. '
      'Continue to the deep check for a more detailed evaluation.';

  /// Paragraph for the Deep-Check Result screen (Figure 3.22), ending with the
  /// disclaimer the report requires ("a screening estimate, not a diagnosis").
  static String deepExplanation(RiskResult r) =>
      'Based on your deep check responses, the model estimates ${_article(r.percent)} '
      '${r.percentText}% likelihood of elevated ${r.disease.label.toLowerCase()} risk, '
      'reflecting patterns across key indicators such as blood pressure, cholesterol, and '
      'lifestyle habits. This is a screening estimate, not a diagnosis. We recommend '
      'consulting a healthcare professional for further evaluation.';

  /// "an 80%", "an 8.5%", "an 11%", "an 18%" but "a 50%" (by how the number sounds).
  static String _article(double percent) {
    final p = percent.floor();
    return (p == 8 || p == 11 || p == 18 || (p >= 80 && p <= 89)) ? 'an' : 'a';
  }
}

// =============================================================================
// The REAL AI
// =============================================================================
class ApiPredictionService implements PredictionService {
  ApiPredictionService({required this.baseUrl, required this.idToken, http.Client? client})
      : _client = client ?? http.Client();

  final String baseUrl;                     // config/api_config.dart: apiBaseUrl()
  final Future<String?> Function() idToken; // the login token (AuthService.idToken)
  final http.Client _client;

  static const _timeout = Duration(seconds: 30);

  /// The API's disease names -> the app's.
  static const _diseases = {
    'heart_disease': Disease.heart, 'heart': Disease.heart,
    'diabetes': Disease.diabetes,
    'stroke': Disease.stroke,
  };

  @override
  Future<List<RiskResult>> quickPredict(Map<String, Object> request) async {
    final body = await _post('/predict/quick', request);
    final results = [
      for (final r in body['results'] as List)
        RiskResult(
          disease: _diseases[r['disease']]!,
          percent: (r['risk_percent'] as num).toDouble(),
        ),
    ];
    results.sort((a, b) => b.percent.compareTo(a.percent)); // already sorted; kept to be safe
    return results;
  }

  @override
  Future<RiskResult> deepCheck(Disease disease, Map<String, Object> request) async {
    // Heart without the stress-test readings = the reduced model (task H1). It has
    // no API endpoint until that model is trained and approved (AI phase).
    if (disease == Disease.heart && !request.containsKey('max_heart_rate')) {
      throw const PredictionFailure(
          'The check without a stress test will be available once its AI model is ready. '
          'For now, choose "Yes" if you have stress-test results.');
    }
    final path = switch (disease) {
      Disease.heart => 'heart',
      Disease.stroke => 'stroke',
      Disease.diabetes => 'diabetes',
    };
    // Signed in -> send the login token, so the backend saves the result to the
    // user's history in Firestore (FR-10). Without it the check still works.
    final body = await _post('/predict/deep/$path', request, token: await idToken());
    final notes = [for (final n in body['explanation'] as List) '• $n'].join('\n');
    final percent = (body['risk_percent'] as num).toDouble();
    final base = RiskResult(disease: disease, percent: percent);
    return RiskResult(
      disease: disease,
      percent: percent,
      explanation: 'The model estimates ${PredictionService._article(percent)} '
          '${base.percentText}% likelihood of ${disease.label.toLowerCase()}.\n\n'
          '$notes\n\n${body['disclaimer']}',
    );
  }

  /// POST [request] as JSON; return the JSON answer, or throw a PredictionFailure
  /// with a message a user (and you, while testing) can act on.
  Future<Map<String, dynamic>> _post(String path, Map<String, Object> request,
      {String? token}) async {
    final http.Response res;
    try {
      res = await _client
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode(request),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const PredictionFailure('The prediction server took too long to answer. '
          'Please try again.');
    } on http.ClientException {
      // No connection at all: wrong address, server not running, or (in Chrome) CORS
      throw PredictionFailure("Can't reach the prediction server at $baseUrl. "
          'Is the API running?');
    }

    final body = res.body.isEmpty ? <String, dynamic>{} : jsonDecode(res.body);
    if (res.statusCode == 200) return body as Map<String, dynamic>;
    // FastAPI's error answers have a "detail" field
    final detail = body is Map ? body['detail'] : null;
    throw PredictionFailure(switch (res.statusCode) {
      // 422: a reading outside the API's valid range (the forms should prevent this)
      422 => 'Some readings were not accepted: ${_describe422(detail)}',
      503 => 'The AI model is not available on the server: $detail',
      _ => 'The prediction server returned an error (${res.statusCode}).',
    });
  }

  /// FastAPI 422 detail: [{"loc": ["body", "age"], "msg": "..."}] -> "age: ...".
  static String _describe422(Object? detail) {
    if (detail is! List) return '$detail';
    return detail.map((e) => '${(e['loc'] as List).last}: ${e['msg']}').join('; ');
  }
}

// =============================================================================
// Sample numbers (no backend): the mockups' values
// =============================================================================
class DemoPredictionService implements PredictionService {
  @override
  Future<List<RiskResult>> quickPredict(Map<String, Object> request) async {
    await Future.delayed(const Duration(milliseconds: 600)); // pretend network delay
    final results = [
      // Sample values from Figure 3.20
      const RiskResult(disease: Disease.heart, percent: 50),
      const RiskResult(disease: Disease.diabetes, percent: 40),
      const RiskResult(disease: Disease.stroke, percent: 20),
    ];
    results.sort((a, b) => b.percent.compareTo(a.percent)); // highest first
    return results;
  }

  @override
  Future<RiskResult> deepCheck(Disease disease, Map<String, Object> request) async {
    await Future.delayed(const Duration(milliseconds: 600));
    // Sample values: 80% for heart comes from Figure 3.22; the others are made up.
    final double percent = switch (disease) {
      Disease.heart => 80,
      Disease.diabetes => 62,
      Disease.stroke => 35,
    };
    return RiskResult(disease: disease, percent: percent);
  }
}
