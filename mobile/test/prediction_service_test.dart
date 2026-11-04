// Tests for the REAL prediction service (services/prediction_service.dart), using a
// fake server (MockClient): it checks what the app sends and how it reads the
// API's answers and failures, without running the backend. Run: flutter test
import 'dart:convert';

import 'package:chronic_disease_app/models/disease.dart';
import 'package:chronic_disease_app/services/prediction_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// A service talking to a fake server that answers with [handler].
ApiPredictionService serviceWith(Future<http.Response> Function(http.Request) handler,
        {String? token = 'tok123'}) =>
    ApiPredictionService(
        baseUrl: 'http://api.test', idToken: () async => token, client: MockClient(handler));

http.Response json(Object body, [int status = 200]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

void main() {
  test('quick: posts JSON to /predict/quick and reads decimals, highest risk first', () async {
    late http.Request sent;
    final s = serviceWith((req) async {
      sent = req;
      return json({'results': [
        {'disease': 'diabetes', 'risk_percent': 70.4,
         'breakdown': {'prediabetes': 3.3, 'diabetes': 67.1}},
        {'disease': 'heart_disease', 'risk_percent': 49.1},
        {'disease': 'stroke', 'risk_percent': 0.2},
      ], 'disclaimer': '...'});
    });
    final results = await s.quickPredict({'age': 64});
    expect(sent.url.toString(), 'http://api.test/predict/quick');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), {'age': 64});
    expect([for (final r in results) r.disease], [Disease.diabetes, Disease.heart, Disease.stroke]);
    expect([for (final r in results) r.percentText], ['70.4', '49.1', '0.2']); // not rounded to 0
  });

  test('deep: sends the login token and shows the API notes + disclaimer', () async {
    late http.Request sent;
    final s = serviceWith((req) async {
      sent = req;
      return json({'disease': 'heart', 'risk_percent': 84.0,
          'explanation': ['Resting blood pressure is in the hypertensive range (>= 140 mmHg).'],
          'disclaimer': 'This is a screening estimate, not a medical diagnosis.',
          'result_id': 'r1'});
    });
    final r = await s.deepCheck(Disease.heart, {'max_heart_rate': 132});
    expect(sent.url.path, '/predict/deep/heart');
    expect(sent.headers['Authorization'], 'Bearer tok123'); // -> saved to History by the backend
    expect(r.percentText, '84');
    expect(r.explanation, contains('an 84% likelihood of heart disease'));
    expect(r.explanation, contains('• Resting blood pressure'));
    expect(r.explanation, contains('not a medical diagnosis'));
  });

  test('deep: signed out -> no Authorization header (still works, just not saved)', () async {
    late http.Request sent;
    final s = serviceWith((req) async {
      sent = req;
      return json({'risk_percent': 12.9, 'explanation': [], 'disclaimer': 'd'});
    }, token: null);
    await s.deepCheck(Disease.stroke, {'bmi': 41.5});
    expect(sent.url.path, '/predict/deep/stroke');
    expect(sent.headers.containsKey('Authorization'), isFalse);
  });

  test('heart without stress-test readings: clear message, nothing sent', () async {
    var calls = 0;
    final s = serviceWith((req) async {
      calls++;
      return json({});
    });
    await expectLater(
        s.deepCheck(Disease.heart, {'resting_bp': 146}),
        throwsA(isA<PredictionFailure>()
            .having((e) => e.message, 'message', contains('without a stress test'))));
    expect(calls, 0);
  });

  test('a reading the API rejects (422) names the field', () async {
    final s = serviceWith((req) async => json({'detail': [
          {'loc': ['body', 'age'], 'msg': 'Input should be greater than or equal to 18'}
        ]}, 422));
    await expectLater(
        s.quickPredict({'age': 10}),
        throwsA(isA<PredictionFailure>().having((e) => e.message, 'message',
            'Some readings were not accepted: age: Input should be greater than or equal to 18')));
  });

  test('server not running -> "Is the API running?"', () async {
    final s = serviceWith((req) async => throw http.ClientException('Connection refused'));
    await expectLater(
        s.quickPredict({}),
        throwsA(isA<PredictionFailure>()
            .having((e) => e.message, 'message', contains('Is the API running?'))));
  });

  test('model missing on the server (503) is explained', () async {
    final s = serviceWith(
        (req) async => json({'detail': "Model 'layer1_general' is not trained yet."}, 503));
    await expectLater(
        s.quickPredict({}),
        throwsA(isA<PredictionFailure>()
            .having((e) => e.message, 'message', contains('not trained yet'))));
  });
}
