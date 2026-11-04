// What each Deep-Check Input form asks for (only the readings that change per
// check; age, sex, history and lifestyle come from the saved details).
//
// ONE screen (deep_check_input_screen.dart) reads these lists and builds the
// form, so adding or removing a question needs no layout code. Each question's
// [key] is the API field it fills (backend/app/schemas.py), except two the app
// converts first in api_payloads.dart:
//   weight_kg                  -> BMI (with the height from My details)
//   fasting_blood_sugar_mg_dl  -> fasting_blood_sugar_over_120 (yes/no)
//
// Approved at CHECKPOINT 5 (docs/input_readings.md): heart asks "Have you done
// an exercise stress test?" first; Yes = full model (10 readings), No = reduced
// model (7 readings, no hospital-only tests).
import 'disease.dart';

/// A number typed into a rounded box (e.g. "Resting BP  146 mmHg").
class NumberQuestion {
  const NumberQuestion(this.label, this.key,
      {required this.sample, required this.min, required this.max,
       this.unit, this.decimal = false});
  final String label;
  final String key;
  final String sample;  // starting value (sample from the mockup) so the demo is quick
  final num min, max;   // the same valid range the API enforces
  final String? unit;   // "mmHg", "mg/dL", ...
  final bool decimal;   // true if 1.8 is allowed, false for whole numbers only
}

/// A YES/NO question with two radio buttons.
class YesNoQuestion {
  const YesNoQuestion(this.label, this.key, {this.sample = false});
  final String label;
  final String key;
  final bool sample;
}

/// One option of a drop-down: what the user reads, and what the API receives.
class Choice {
  const Choice(this.label, this.value);
  final String label;
  final String value;
}

/// A drop-down list (e.g. Chest Pain Type).
class ChoiceQuestion {
  const ChoiceQuestion(this.label, this.key, {required this.options});
  final String label;
  final String key;
  final List<Choice> options; // the first one is pre-selected
}

class DeepCheckForm {
  const DeepCheckForm({required this.numbers, this.yesNo = const [], this.choices = const []});

  final List<NumberQuestion> numbers;
  final List<YesNoQuestion> yesNo;
  final List<ChoiceQuestion> choices;

  static const _weight =
      NumberQuestion('Weight', 'weight_kg', sample: '70', min: 20, max: 350, unit: 'KG', decimal: true);
  static const _glucose = NumberQuestion('Blood Glucose', 'blood_glucose_level',
      sample: '140', min: 40, max: 400, unit: 'mg/dL');

  /// Look up the form for a disease. [stressTest] only matters for heart.
  static DeepCheckForm forDisease(Disease d, {bool stressTest = true}) => switch (d) {
        Disease.heart => DeepCheckForm(
            numbers: [
              const NumberQuestion('Resting BP', 'resting_bp',
                  sample: '146', min: 60, max: 250, unit: 'mmHg'),
              const NumberQuestion('Cholesterol Level', 'cholesterol',
                  sample: '236', min: 80, max: 700, unit: 'mg/dL'),
              const NumberQuestion('Fasting Blood Sugar', 'fasting_blood_sugar_mg_dl',
                  sample: '110', min: 40, max: 400, unit: 'mg/dL'),
              // the three hospital-only readings (exercise stress test)
              if (stressTest) ...const [
                NumberQuestion('Max Heart Rate', 'max_heart_rate',
                    sample: '132', min: 50, max: 230, unit: 'bpm'),
                NumberQuestion('ST Depression', 'st_depression',
                    sample: '1.8', min: -3, max: 7, unit: 'mm', decimal: true),
              ],
            ],
            yesNo: [
              if (stressTest)
                const YesNoQuestion('Chest pain during the stress test?', 'exercise_induced_angina',
                    sample: true),
            ],
            choices: const [
              ChoiceQuestion('Chest Pain Type', 'chest_pain_type', options: [
                Choice('Typical Angina', 'typical angina'),
                Choice('Atypical Angina', 'atypical angina'),
                Choice('Non-anginal Pain', 'non-anginal'),
                Choice('No chest pain (asymptomatic)', 'asymptomatic'),
              ]),
              ChoiceQuestion('Resting ECG Result', 'resting_ecg', options: [
                Choice('Normal', 'normal'),
                Choice('ST-T wave abnormality', 'st-t abnormality'),
                Choice('Left ventricular hypertrophy', 'lv hypertrophy'),
              ]),
            ],
          ),
        Disease.diabetes => const DeepCheckForm(numbers: [
            _weight,
            NumberQuestion('HbA1c Level', 'hba1c_level',
                sample: '6.6', min: 3, max: 15, unit: '%', decimal: true),
            _glucose,
          ]),
        Disease.stroke => const DeepCheckForm(numbers: [
            _weight,
            NumberQuestion('Average Glucose', 'avg_glucose_level',
                sample: '140', min: 40, max: 400, unit: 'mg/dL', decimal: true),
          ]),
      };
}
