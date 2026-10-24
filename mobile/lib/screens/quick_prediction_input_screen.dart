// =============================================================================
// 5. QUICK PREDICTION INPUT INTERFACE (Figure 3.19)
//
//   <-
//        Age   [ 58 ]        Sex    [ Male ]
//     Weight   [120 KG]   Height    [170 CM]
//        BMI   [41.5]                          <- calculated, not typed
//                                   NO  YES
//   High Blood Pressure?            ( )  (o)
//   ...
//   Smoking Status [v]   General Health Self Rating [v]
//                 [ Check ]
//   Home | History | Profile
//
// The numbers are SAMPLE values from the mockup so you can press Check at once.
// Flow (Figure 3.25): Check -> AI model -> Quick Prediction Result.
// =============================================================================
import 'package:flutter/material.dart';

import '../models/disease.dart';
import '../navigation/app_tabs.dart';
import '../services/app_services.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/labeled_box.dart';
import '../widgets/labeled_dropdown.dart';
import '../widgets/phone_width.dart';
import '../widgets/primary_button.dart';
import '../widgets/yes_no_table.dart';
import 'login_screen.dart' show showErrorDialog;
import 'quick_prediction_result_screen.dart';

class QuickPredictionInputScreen extends StatefulWidget {
  const QuickPredictionInputScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<QuickPredictionInputScreen> createState() => _QuickPredictionInputScreenState();
}

class _QuickPredictionInputScreenState extends State<QuickPredictionInputScreen> {
  final _formKey = GlobalKey<FormState>();

  // A TextEditingController holds the text inside one box.
  final _age = TextEditingController(text: '58');
  final _weight = TextEditingController(text: '120');
  final _height = TextEditingController(text: '170');
  final _bmi = TextEditingController();

  String _sex = 'Male';
  String _smoking = 'Active';
  String _generalHealth = 'Poor';

  // The YES/NO answers. Change a "true" to "false" to change the starting tick.
  final Map<String, bool> _yesNo = {
    'High Blood Pressure?': true,
    'High Cholesterol?': true,
    'Alcohol Consumption': false,
    'Physical Activity Level': true,
  };

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _updateBmi(); // fill BMI from the sample weight/height
  }

  @override
  void dispose() {
    for (final c in [_age, _weight, _height, _bmi]) {
      c.dispose();
    }
    super.dispose();
  }

  /// BMI = weight (kg) / height (m)^2. Runs every time weight or height changes.
  void _updateBmi() {
    final kg = double.tryParse(_weight.text);
    final cm = double.tryParse(_height.text);
    if (kg == null || cm == null || cm == 0) {
      _bmi.text = '';
      return;
    }
    final m = cm / 100;
    _bmi.text = (kg / (m * m)).toStringAsFixed(1); // one decimal place: 41.5
  }

  Future<void> _check() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    // Everything the user entered, by name. This is what the backend will receive.
    final answers = <String, Object>{
      'age': int.parse(_age.text),
      'sex': _sex,
      'weight': double.parse(_weight.text),
      'height': double.parse(_height.text),
      'bmi': double.tryParse(_bmi.text) ?? 0,
      ..._yesNo, // copies the four YES/NO answers in
      'smokingStatus': _smoking,
      'generalHealth': _generalHealth,
    };

    List<RiskResult>? results;
    try {
      results = await widget.services.predictions.quickPredict(answers);
    } catch (e) {
      // e.g. no internet once the real backend is connected
      if (mounted) await showErrorDialog(context, 'Prediction failed', '$e');
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (results == null) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuickPredictionResultScreen(services: widget.services, results: results!),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Same bar as the Home tab. The Home icon stays green because this
      // screen was opened from Home.
      bottomNavigationBar: const AppBottomNav(currentIndex: AppTabs.home),
      body: SafeArea(
        child: PhoneWidth(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 24),
              children: [
                const Align(alignment: Alignment.centerLeft, child: AppBackButton()),
                // ---- the two-column boxes
                TwoColumnGrid(
                  children: [
                    LabeledNumberBox(label: 'Age', controller: _age),
                    LabeledChoiceBox(
                      label: 'Sex',
                      value: _sex,
                      options: const ['Male', 'Female'],
                      onChanged: (v) => setState(() => _sex = v),
                    ),
                    LabeledNumberBox(
                      label: 'Weight',
                      controller: _weight,
                      suffix: 'KG',
                      decimal: true,
                      onChanged: (_) => setState(_updateBmi),
                    ),
                    LabeledNumberBox(
                      label: 'Height',
                      controller: _height,
                      suffix: 'CM',
                      decimal: true,
                      onChanged: (_) => setState(_updateBmi),
                    ),
                    LabeledNumberBox(label: 'BMI', controller: _bmi, readOnly: true),
                  ],
                ),
                const SizedBox(height: 18),
                // ---- YES / NO questions
                YesNoTable(
                  answers: _yesNo,
                  onChanged: (question, value) => setState(() => _yesNo[question] = value),
                ),
                const SizedBox(height: 20),
                // ---- the two drop-downs side by side
                Row(
                  // .end lines the two boxes up at the bottom even though the
                  // right label wraps onto two lines.
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: LabeledDropdown(
                        label: 'Smoking Status',
                        value: _smoking,
                        options: const ['Active', 'Former', 'Never'],
                        onChanged: (v) => setState(() => _smoking = v),
                      ),
                    ),
                    const SizedBox(width: 50),
                    Expanded(
                      child: LabeledDropdown(
                        label: 'General Health Self Rating',
                        value: _generalHealth,
                        options: const ['Excellent', 'Very Good', 'Good', 'Fair', 'Poor'],
                        onChanged: (v) => setState(() => _generalHealth = v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 60),
                Center(
                  child: PrimaryButton(
                    key: const Key('quickCheck'),
                    label: 'Check',
                    width: 172,
                    height: 46,
                    loading: _loading,
                    onPressed: _check,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
