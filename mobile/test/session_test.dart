// Saved details and results must never pass from one user to the next on a
// shared device. Plain unit tests (no screens): run with  flutter test
import 'package:chronic_disease_app/models/disease.dart';
import 'package:chronic_disease_app/services/history_service.dart';
import 'package:chronic_disease_app/services/profile_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_payloads_test.dart' show sampleDetails;

void main() {
  group('ProfileService', () {
    test('the same user logging in again keeps their details', () {
      final s = ProfileService(initial: sampleDetails(), ownerUid: 'u1');
      s.startSession('u1');
      expect(s.details.value.isComplete, isTrue);
    });

    test('a different user starts with empty details', () {
      final s = ProfileService(initial: sampleDetails(), ownerUid: 'u1');
      s.startSession('u2');
      expect(s.details.value.isComplete, isFalse);
      expect(s.details.value.profile.heightCm, isNull);
      expect(s.uid, 'u2');
    });

    test("a new account does not inherit the previous user's details", () async {
      final s = ProfileService(initial: sampleDetails(), ownerUid: 'u1');
      await s.saveAccount(
          uid: 'new', dateOfBirth: DateTime(1990, 1, 2), sex: 'female', contact: '0123456789');
      final p = s.details.value.profile;
      expect((p.sex, p.heightCm, p.incomeMonthlyRm), ('female', null, null));
      expect(s.details.value.history.isComplete, isFalse);

      // Logging in with the new account keeps what Create Account saved
      s.startSession('new');
      expect(s.details.value.profile.dateOfBirth, DateTime(1990, 1, 2));
    });
  });

  group('HistoryService', () {
    test('a different user sees only the samples, not the previous results', () {
      final h = HistoryService()..startSession('u1');
      final samples = h.entries.value.length;
      h.add(const RiskResult(disease: Disease.heart, percent: 42));

      h.startSession('u1'); // same person again: their result is still there
      expect(h.entries.value.length, samples + 1);

      h.startSession('u2'); // someone else
      expect(h.entries.value.length, samples);
      expect(h.entries.value.any((e) => e.result.percent == 42), isFalse);
    });
  });
}
