// What is written to Firestore must come back as the same answers when it is
// read again (services/firestore_maps.dart). Plain unit tests, no database:
//   flutter test test/firestore_maps_test.dart
import 'package:chronic_disease_app/models/disease.dart';
import 'package:chronic_disease_app/models/user_details.dart';
import 'package:chronic_disease_app/services/firestore_maps.dart';
import 'package:chronic_disease_app/services/prediction_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'api_payloads_test.dart' show sampleDetails;

/// users/{uid} as Firestore would hold it after Create Account + all three forms.
Map<String, dynamic> savedUserDoc(UserDetails d) => {
      'userName': 'Ali Ahmad',
      'userEmail': 'ali@demo.com',
      'userSex': d.profile.sex,
      'dateOfBirth': Timestamp.fromDate(d.profile.dateOfBirth!),
      'contactNumber': d.profile.contactNumber,
      'userCreate_at': Timestamp.now(),
      'profile': FirestoreMaps.toMyDetails(d.profile),
      'history': FirestoreMaps.toMedicalHistory(d.history),
      'lifestyle': FirestoreMaps.toLifestyle(d.lifestyle),
      'lastWeightKg': d.lastWeightKg,
    };

void main() {
  test('every saved answer comes back the same', () {
    final original = sampleDetails();
    final loaded = FirestoreMaps.fromUserDoc(savedUserDoc(original));

    final a = original.profile, b = loaded.profile;
    expect((b.dateOfBirth, b.sex, b.contactNumber), (a.dateOfBirth, a.sex, a.contactNumber));
    expect((b.heightCm, b.education, b.incomeMonthlyRm), (a.heightCm, a.education, a.incomeMonthlyRm));
    expect((b.healthCoverage, b.everMarried, b.workType, b.residence),
        (a.healthCoverage, a.everMarried, a.workType, a.residence));

    expect(loaded.history.highBloodPressure, original.history.highBloodPressure);
    expect(loaded.history.difficultyWalking, original.history.difficultyWalking);
    expect(loaded.lifestyle.activity, original.lifestyle.activity);
    expect(loaded.lifestyle.vegetables, original.lifestyle.vegetables);
    expect(loaded.lifestyle.updatedAt, original.lifestyle.updatedAt);
    expect(loaded.lastWeightKg, original.lastWeightKg);
    expect(loaded.isComplete, isTrue);
  });

  test('choices are stored by name, readable in the Emulator UI', () {
    final d = sampleDetails();
    expect(FirestoreMaps.toMyDetails(d.profile)['education'], 'spm');
    expect(FirestoreMaps.toLifestyle(d.lifestyle)['activity'], 'oneTwoWeekly');
  });

  test('drinks per week is only stored for people who drink', () {
    final none = sampleDetails().lifestyle; // drinksAlcohol: false
    expect(FirestoreMaps.toLifestyle(none).containsKey('drinksPerWeek'), isFalse);

    final drinks = sampleDetails(
      lifestyle: const LifestyleAnswers(
        smoked100: false,
        smokesNow: false,
        activity: ActivityAnswer.none,
        fruit: FoodFrequency.rarely,
        vegetables: FoodFrequency.rarely,
        drinksAlcohol: true,
        drinksPerWeek: 3,
      ),
    ).lifestyle;
    expect(FirestoreMaps.toLifestyle(drinks)['drinksPerWeek'], 3);
  });

  test('a new account (only Create Account fields) loads as "details not complete"', () {
    final loaded = FirestoreMaps.fromUserDoc({
      'userName': 'Mei Ling',
      'userSex': 'female',
      'dateOfBirth': Timestamp.fromDate(DateTime(1990, 1, 2)),
      'contactNumber': '0123456789',
    });
    expect(loaded.profile.accountComplete, isTrue);
    expect(loaded.profile.detailsComplete, isFalse);
    expect(loaded.history.isComplete, isFalse);
  });

  test('wrong types or unknown choices become "not answered" instead of crashing', () {
    final loaded = FirestoreMaps.fromUserDoc({
      'userSex': 42,
      'profile': {'heightCm': 'tall', 'education': 'phd-in-space'},
      'lifestyle': 'not a map',
    });
    expect(loaded.profile.sex, isNull);
    expect(loaded.profile.heightCm, isNull);
    expect(loaded.profile.education, isNull);
    expect(loaded.lifestyle.activity, isNull);
  });

  group('deep-check results (written by the backend)', () {
    test('a saved result becomes a History card with the notes and disclaimer', () {
      final when = DateTime(2026, 11, 10, 9, 30);
      final entry = FirestoreMaps.fromResultDoc({
        'diseaseType': 'heart',
        'risk_percentage': 72.4,
        'explanation_text': ['Resting blood pressure is high.', 'Exercise angina: yes.'],
        'created_at': Timestamp.fromDate(when),
      }, title: 'Diagnosis 3')!;

      expect(entry.title, 'Diagnosis 3');
      expect((entry.result.disease, entry.result.percent), (Disease.heart, 72.4));
      expect(entry.date, when);
      expect(entry.explanation, contains('• Resting blood pressure is high.'));
      expect(entry.explanation, endsWith(PredictionService.disclaimer));
    });

    test('a result the app cannot show is skipped', () {
      expect(FirestoreMaps.fromResultDoc({'diseaseType': 'flu'}, title: 'x'), isNull);
      expect(FirestoreMaps.fromResultDoc({'diseaseType': 'stroke'}, title: 'x'), isNull);
    });
  });
}
