// =============================================================================
// Turns the user's answers into the EXACT request bodies the API accepts
// (backend/app/schemas.py). Every mapping here was approved at CHECKPOINT 6
// (docs/lifestyle_check_proposal.md). No API or model change is needed.
//
// This is the one place answers become model codes. If a mapping must change,
// change it here and the unit tests in test/api_payloads_test.dart.
// =============================================================================
import 'disease.dart';
import 'user_details.dart';

/// The 5 readings the Quick Prediction screen still asks every time.
class QuickCheckAnswers {
  const QuickCheckAnswers({
    required this.weightKg,
    required this.generalHealth,
    required this.poorMentalDays,
    required this.poorPhysicalDays,
    required this.skippedDoctorCost,
  });

  final double weightKg;
  final int generalHealth;      // 1 excellent ... 5 poor
  final int poorMentalDays;     // 0-30
  final int poorPhysicalDays;   // 0-30
  final bool skippedDoctorCost; // past 12 months
}

/// "In general, would you say your health is..." -> BRFSS GenHlth code 1-5.
const generalHealthOptions = ['Excellent', 'Very good', 'Good', 'Fair', 'Poor'];

class ApiPayloads {
  // ------------------------------------------------------------ small mappings
  static double bmi(double weightKg, double heightCm) =>
      weightKg / ((heightCm / 100) * (heightCm / 100));

  /// Table E (education): BRFSS code 1-6. SPM -> 4 (completes secondary school, E1).
  static int educationCode(Education e) => switch (e) {
        Education.none => 1,
        Education.primary => 2,
        Education.someSecondary => 3,
        Education.spm => 4,
        Education.postSecondary => 5,
        Education.degree => 6,
      };

  static String workTypeValue(WorkType w) => switch (w) {
        WorkType.private => 'Private',
        WorkType.selfEmployed => 'Self-employed',
        WorkType.government => 'Govt_job',
        WorkType.neverWorked => 'Never_worked',
      };

  static String residenceValue(Residence r) => r == Residence.urban ? 'Urban' : 'Rural';

  /// Stroke model smoking_status (the four clear rows; never "Unknown").
  static String strokeSmoking(LifestyleAnswers l) =>
      l.smokesNow! ? 'smokes' : (l.smoked100! ? 'formerly smoked' : 'never smoked');

  /// Diabetes model smoking_history (never "not current", "ever" or "No Info").
  static String diabetesSmoking(LifestyleAnswers l) =>
      l.smokesNow! ? 'current' : (l.smoked100! ? 'former' : 'never');

  // ------------------------------------------------------------ income (PENDING)
  /// Share of BRFSS households at or below each income band 1..8 (from the training
  /// data; docs/input_readings.md section 8).
  static const brfssCumulativeShare = [0.039, 0.085, 0.148, 0.228, 0.330, 0.473, 0.644, 1.0];

  /// PLACEHOLDER until you add the DOSM HIES 2022 table (CHECKPOINT 6, item 6).
  /// Fill with (monthly household income in RM, share of Malaysian households at or
  /// below it), lowest first, e.g. the decile boundaries from DOSM.
  static const dosmIncomePercentiles = <(double, double)>[];

  /// Percentile matching: find the user's position among Malaysian households, then
  /// the BRFSS band that holds the same position.
  static int incomeBand(double monthlyRm) {
    final share = _malaysianShareAtOrBelow(monthlyRm);
    for (var band = 0; band < brfssCumulativeShare.length; band++) {
      if (share <= brfssCumulativeShare[band]) return band + 1;
    }
    return 8;
  }

  static double _malaysianShareAtOrBelow(double rm) {
    // Without the DOSM table everyone is treated as the median household (share 0.5,
    // which falls in band 7). This keeps the app working; it is NOT the user's real band.
    if (dosmIncomePercentiles.isEmpty) return 0.5;
    var (prevRm, prevShare) = (0.0, 0.0);
    for (final (limitRm, share) in dosmIncomePercentiles) {
      if (rm <= limitRm) {
        // straight line between the two DOSM points around the user's income
        final t = limitRm == prevRm ? 1.0 : (rm - prevRm) / (limitRm - prevRm);
        return prevShare + t * (share - prevShare);
      }
      (prevRm, prevShare) = (limitRm, share);
    }
    return 1.0;
  }

  // ------------------------------------------------------------ request bodies
  /// POST /predict/quick: all 20 fields of QuickPredictionInput.
  static Map<String, Object> quick(UserDetails d, QuickCheckAnswers c, DateTime now) {
    final p = d.profile, h = d.history, l = d.lifestyle;
    return {
      'age': p.ageOn(now)!,
      'sex': p.sex!,
      'weight_kg': c.weightKg,
      'height_cm': p.heightCm!,
      'high_blood_pressure': h.highBloodPressure!,
      'high_cholesterol': h.highCholesterol!,
      'cholesterol_checked_last_5_years': h.cholesterolChecked5y!,
      'smoked_100_cigarettes': l.smoked100!,
      // any activity in the past 30 days = yes (Active and Semi-active both count)
      'physically_active_last_30_days': l.activity != ActivityAnswer.none,
      'eats_fruit_daily': l.fruit!.daily,
      'eats_vegetables_daily': l.vegetables!.daily,
      'alcohol_drinks_per_week': l.weeklyDrinks, // the API applies the 14/7 heavy rule
      'has_health_coverage': p.healthCoverage!,
      'skipped_doctor_due_to_cost': c.skippedDoctorCost,
      'general_health': c.generalHealth,
      'poor_mental_health_days': c.poorMentalDays,
      'poor_physical_health_days': c.poorPhysicalDays,
      'difficulty_walking': h.difficultyWalking!,
      'education_level': educationCode(p.education!),
      'income_level': incomeBand(p.incomeMonthlyRm!),
    };
  }

  /// POST /predict/deep/{disease}. [form] holds the Deep-Check screen's answers,
  /// keyed as in deep_check_form.dart; the rest comes from the saved details.
  /// Heart without the 3 stress-test keys = the reduced heart model (H1).
  static Map<String, Object> deep(Disease disease, UserDetails d, Map<String, Object> form,
      DateTime now) {
    final p = d.profile, h = d.history, l = d.lifestyle;
    final base = <String, Object>{'age': p.ageOn(now)!, 'sex': p.sex!};
    double bmiFromForm() => bmi((form['weight_kg'] as num).toDouble(), p.heightCm!);
    return switch (disease) {
      Disease.heart => {
          ...base,
          for (final e in form.entries)
            if (e.key != 'fasting_blood_sugar_mg_dl') e.key: e.value,
          // the model was trained on "fasting blood sugar > 120 mg/dL", a yes/no
          'fasting_blood_sugar_over_120': (form['fasting_blood_sugar_mg_dl'] as num) > 120,
        },
      Disease.stroke => {
          ...base,
          'hypertension': h.highBloodPressure!,
          'heart_disease': h.heartDisease!,
          'ever_married': p.everMarried!,
          'work_type': workTypeValue(p.workType!),
          'residence_type': residenceValue(p.residence!),
          'avg_glucose_level': form['avg_glucose_level']!,
          'bmi': double.parse(bmiFromForm().toStringAsFixed(1)),
          'smoking_status': strokeSmoking(l),
        },
      Disease.diabetes => {
          ...base,
          'hypertension': h.highBloodPressure!,
          'heart_disease': h.heartDisease!,
          'smoking_history': diabetesSmoking(l),
          'bmi': double.parse(bmiFromForm().toStringAsFixed(1)),
          'hba1c_level': form['hba1c_level']!,
          'blood_glucose_level': form['blood_glucose_level']!,
        },
    };
  }
}
