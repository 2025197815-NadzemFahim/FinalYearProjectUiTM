// What each Deep-Check Input form asks for.
//
// Instead of writing three almost identical screens, ONE screen
// (deep_check_input_screen.dart) reads this list and builds the right form.
// To add or remove a question, edit the lists below - no layout code needed.
//
// Heart Disease: copied from the mockup (Figure 3.21).
// Diabetes and Stroke: NO mockup exists, so their fields come from the report's
//   data dictionary (Tables 3.22, 3.23), plus Age / Sex / BMI like the heart form.
import 'disease.dart';

/// A number typed into a rounded box (e.g. "Resting BP  146").
class NumberQuestion {
  const NumberQuestion(this.label, {required this.sample, this.decimal = false});
  final String label;
  final String sample;  // dummy starting value, like the numbers in the mockup
  final bool decimal;   // true if 1.8 is allowed, false for whole numbers only
}

/// A YES/NO question with two radio buttons.
class YesNoQuestion {
  const YesNoQuestion(this.label, {this.sample = false});
  final String label;
  final bool sample;
}

/// A drop-down list (e.g. Chest Pain Type).
class ChoiceQuestion {
  const ChoiceQuestion(this.label, {required this.options});
  final String label;
  final List<String> options; // the first one is pre-selected
}

class DeepCheckForm {
  const DeepCheckForm({
    required this.numbers,
    this.yesNo = const [],
    this.choices = const [],
  });

  final List<NumberQuestion> numbers;
  final List<YesNoQuestion> yesNo;
  final List<ChoiceQuestion> choices;

  static const _sex = ChoiceQuestion('Sex', options: ['Male', 'Female']);
  static const _smoking = ChoiceQuestion('Smoking History', options: ['Never', 'Former', 'Current']);

  /// Look up the form for a disease.
  static DeepCheckForm forDisease(Disease d) => switch (d) {
        Disease.heart => const DeepCheckForm(
            numbers: [
              NumberQuestion('Age', sample: '58'),
              NumberQuestion('BMI', sample: '41.5', decimal: true),
              NumberQuestion('Resting BP', sample: '146'),
              NumberQuestion('Cholesterol Level', sample: '236'),
              NumberQuestion('Fasting Blood Sugar', sample: '110'),
              NumberQuestion('Max Heart Rate', sample: '132'),
              NumberQuestion('ST Depression', sample: '1.8', decimal: true),
              NumberQuestion('Major Vessel Number', sample: '1'),
            ],
            yesNo: [YesNoQuestion('High Blood Pressure?', sample: true)],
            choices: [
              _sex,
              ChoiceQuestion('Chest Pain Type', options: [
                'Typical Angina', 'Atypical Angina', 'Non-anginal Pain', 'Asymptomatic',
              ]),
            ],
          ),
        Disease.diabetes => const DeepCheckForm(
            numbers: [
              NumberQuestion('Age', sample: '58'),
              NumberQuestion('BMI', sample: '41.5', decimal: true),
              NumberQuestion('HbA1c Level', sample: '6.6', decimal: true),
              NumberQuestion('Glucose Level', sample: '140'),
            ],
            yesNo: [YesNoQuestion('Hypertension?', sample: true)],
            choices: [_sex, _smoking],
          ),
        Disease.stroke => const DeepCheckForm(
            numbers: [
              NumberQuestion('Age', sample: '58'),
              NumberQuestion('BMI', sample: '41.5', decimal: true),
              NumberQuestion('Glucose Level', sample: '140'),
            ],
            yesNo: [YesNoQuestion('Hypertension?', sample: true)],
            choices: [_sex, _smoking],
          ),
      };
}
