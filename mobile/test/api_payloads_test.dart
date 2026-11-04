// Unit tests for models/api_payloads.dart: the saved answers must become EXACTLY
// what the API accepts (backend/app/schemas.py) with the mappings approved at
// CHECKPOINT 6 (docs/lifestyle_check_proposal.md). Run: flutter test
import 'package:chronic_disease_app/models/api_payloads.dart';
import 'package:chronic_disease_app/models/disease.dart';
import 'package:chronic_disease_app/models/user_details.dart';
import 'package:flutter_test/flutter_test.dart';

/// A complete set of saved details (also used by the widget tests).
UserDetails sampleDetails({LifestyleAnswers? lifestyle}) => UserDetails(
      profile: UserProfile(
        dateOfBirth: DateTime(1966, 5, 20),
        sex: 'male',
        heightCm: 170,
        education: Education.spm,
        incomeMonthlyRm: 6500,
        healthCoverage: true,
        everMarried: true,
        workType: WorkType.government,
        residence: Residence.urban,
      ),
      history: const MedicalHistory(
        highBloodPressure: true,
        highCholesterol: false,
        cholesterolChecked5y: true,
        heartDisease: false,
        difficultyWalking: false,
      ),
      lifestyle: lifestyle ??
          LifestyleAnswers(
            smoked100: true,
            smokesNow: false,
            activity: ActivityAnswer.oneTwoWeekly,
            fruit: FoodFrequency.onceDaily,
            vegetables: FoodFrequency.fewTimesWeek,
            drinksAlcohol: false,
            updatedAt: DateTime(2026, 10, 1),
          ),
      lastWeightKg: 120,
    );

void main() {
  final day = DateTime(2026, 10, 29);
  const check = QuickCheckAnswers(
      weightKg: 70, generalHealth: 3, poorMentalDays: 2, poorPhysicalDays: 0,
      skippedDoctorCost: false);

  test('quick request has exactly the 20 API fields, with the approved codes', () {
    final q = ApiPayloads.quick(sampleDetails(), check, day);
    expect(q.keys.toSet(), {
      'age', 'sex', 'weight_kg', 'height_cm', 'high_blood_pressure', 'high_cholesterol',
      'cholesterol_checked_last_5_years', 'smoked_100_cigarettes',
      'physically_active_last_30_days', 'eats_fruit_daily', 'eats_vegetables_daily',
      'alcohol_drinks_per_week', 'has_health_coverage', 'skipped_doctor_due_to_cost',
      'general_health', 'poor_mental_health_days', 'poor_physical_health_days',
      'difficulty_walking', 'education_level', 'income_level',
    });
    expect(q['age'], 60);                               // born 20 May 1966
    expect(q['physically_active_last_30_days'], true);  // semi-active counts as active
    expect(q['eats_fruit_daily'], true);                // once a day
    expect(q['eats_vegetables_daily'], false);          // a few times a week
    expect(q['education_level'], 4);                    // SPM -> 4 (E1)
    expect(q['alcohol_drinks_per_week'], 0);            // doesn't drink
  });

  test('age is recalculated on the day of the check', () {
    final p = sampleDetails().profile;
    expect(p.ageOn(DateTime(2026, 5, 19)), 59); // day before the birthday
    expect(p.ageOn(DateTime(2026, 5, 20)), 60); // on the birthday
  });

  test('smoking: the four rows map to all three models', () {
    // (smoked 100, smokes now) -> (quick, stroke, diabetes, level)
    const rows = {
      (true, true): (true, 'smokes', 'current', 'Current smoker'),
      (true, false): (true, 'formerly smoked', 'former', 'Former smoker'),
      (false, true): (false, 'smokes', 'current', 'New / light smoker'),
      (false, false): (false, 'never smoked', 'never', 'Never smoked'),
    };
    rows.forEach((answers, expected) {
      final l = LifestyleAnswers(smoked100: answers.$1, smokesNow: answers.$2);
      final d = sampleDetails(lifestyle: LifestyleAnswers(
          smoked100: answers.$1, smokesNow: answers.$2, activity: ActivityAnswer.none,
          fruit: FoodFrequency.rarely, vegetables: FoodFrequency.rarely, drinksAlcohol: false));
      expect(ApiPayloads.quick(d, check, day)['smoked_100_cigarettes'], expected.$1);
      expect(ApiPayloads.strokeSmoking(l), expected.$2);
      expect(ApiPayloads.diabetesSmoking(l), expected.$3);
      expect(l.smokingLevel, expected.$4);
    });
  });

  test('activity: only "not at all" is inactive for the model', () {
    for (final a in ActivityAnswer.values) {
      final d = sampleDetails(lifestyle: LifestyleAnswers(
          smoked100: false, smokesNow: false, activity: a, fruit: FoodFrequency.rarely,
          vegetables: FoodFrequency.rarely, drinksAlcohol: false));
      expect(ApiPayloads.quick(d, check, day)['physically_active_last_30_days'],
          a != ActivityAnswer.none, reason: a.label);
    }
  });

  test('education table E', () {
    expect([for (final e in Education.values) ApiPayloads.educationCode(e)], [1, 2, 3, 4, 5, 6]);
  });

  test('alcohol levels use the same 14 / 7 rule as the API', () {
    const l = LifestyleAnswers(drinksAlcohol: true, drinksPerWeek: 10);
    expect(l.alcoholLevel('male'), 'Moderate');  // 10 <= 14
    expect(l.alcoholLevel('female'), 'Heavy');   // 10 > 7
    expect(const LifestyleAnswers(drinksAlcohol: false).alcoholLevel('male'), 'None');
  });

  test('income is a placeholder until the DOSM table is added', () {
    expect(ApiPayloads.dosmIncomePercentiles, isEmpty, reason: 'remove this line once added');
    expect(ApiPayloads.incomeBand(500), 7);     // everyone = median household for now
    expect(ApiPayloads.incomeBand(50000), 7);
  });

  test('heart (full): the 10 API fields; fasting sugar becomes yes/no at > 120', () {
    Map<String, Object> heart(int sugar) => ApiPayloads.deep(Disease.heart, sampleDetails(), {
          'resting_bp': 146, 'cholesterol': 236, 'fasting_blood_sugar_mg_dl': sugar,
          'max_heart_rate': 132, 'st_depression': 1.8, 'exercise_induced_angina': true,
          'chest_pain_type': 'asymptomatic', 'resting_ecg': 'normal',
        }, day);
    expect(heart(110).keys.toSet(), {
      'age', 'sex', 'chest_pain_type', 'resting_bp', 'cholesterol',
      'fasting_blood_sugar_over_120', 'resting_ecg', 'max_heart_rate',
      'exercise_induced_angina', 'st_depression',
    });
    expect(heart(110)['fasting_blood_sugar_over_120'], false);
    expect(heart(120)['fasting_blood_sugar_over_120'], false);
    expect(heart(121)['fasting_blood_sugar_over_120'], true);
  });

  test('heart (reduced): the 7 readings without the stress test', () {
    final h = ApiPayloads.deep(Disease.heart, sampleDetails(), {
      'resting_bp': 146, 'cholesterol': 236, 'fasting_blood_sugar_mg_dl': 110,
      'chest_pain_type': 'non-anginal', 'resting_ecg': 'normal',
    }, day);
    expect(h.keys.toSet(), {'age', 'sex', 'chest_pain_type', 'resting_bp', 'cholesterol',
        'fasting_blood_sugar_over_120', 'resting_ecg'});
  });

  test('stroke: the 10 API fields; BMI from weight + saved height', () {
    final s = ApiPayloads.deep(Disease.stroke, sampleDetails(),
        {'weight_kg': 120.0, 'avg_glucose_level': 140.0}, day);
    expect(s.keys.toSet(), {'age', 'sex', 'hypertension', 'heart_disease', 'ever_married',
        'work_type', 'residence_type', 'avg_glucose_level', 'bmi', 'smoking_status'});
    expect(s['bmi'], 41.5);              // 120 / 1.70^2
    expect(s['work_type'], 'Govt_job');
    expect(s['residence_type'], 'Urban');
    expect(s['smoking_status'], 'formerly smoked');
  });

  test('diabetes: the 8 API fields', () {
    final d = ApiPayloads.deep(Disease.diabetes, sampleDetails(),
        {'weight_kg': 70.0, 'hba1c_level': 6.6, 'blood_glucose_level': 140}, day);
    expect(d.keys.toSet(), {'age', 'sex', 'hypertension', 'heart_disease', 'smoking_history',
        'bmi', 'hba1c_level', 'blood_glucose_level'});
    expect(d['smoking_history'], 'former');
  });
}
