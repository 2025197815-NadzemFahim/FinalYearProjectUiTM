// =============================================================================
// 7. DEEP-CHECK INPUT INTERFACE (Figure 3.21, Heart Disease)
//
//   <-  Heart Disease
//        Age [58]            Sex [Male]
//        BMI [41.5]   Resting BP [146]
//   ...
//   High Blood Pressure?     NO ( )  YES (o)
//   Chest Pain Type [ Typical Angina  v ]
//              [ Deep Check ]
//
// ONE screen serves all three diseases: it reads the question list from
// DeepCheckForm.forDisease(disease) (models/deep_check_form.dart) and builds
// the boxes from it. The report only has a mockup for Heart Disease, so
// Diabetes and Stroke reuse this exact layout with their own questions.
//
// Flow (Figure 3.25): Deep Check -> AI model -> save result -> show result.
// =============================================================================
import 'package:flutter/material.dart';

import '../models/deep_check_form.dart';
import '../models/disease.dart';
import '../navigation/app_tabs.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/labeled_box.dart';
import '../widgets/labeled_dropdown.dart';
import '../widgets/phone_width.dart';
import '../widgets/primary_button.dart';
import '../widgets/yes_no_table.dart';
import 'deep_check_result_screen.dart';
import 'login_screen.dart' show showErrorDialog;

class DeepCheckInputScreen extends StatefulWidget {
  const DeepCheckInputScreen({super.key, required this.services, required this.disease});

  final AppServices services;
  final Disease disease;

  @override
  State<DeepCheckInputScreen> createState() => _DeepCheckInputScreenState();
}

class _DeepCheckInputScreenState extends State<DeepCheckInputScreen> {
  final _formKey = GlobalKey<FormState>();
  late final DeepCheckForm _form;

  // One controller / answer per question, looked up by the question's label.
  final Map<String, TextEditingController> _numbers = {};
  final Map<String, bool> _yesNo = {};
  final Map<String, String> _choices = {};

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _form = DeepCheckForm.forDisease(widget.disease);
    for (final q in _form.numbers) {
      _numbers[q.label] = TextEditingController(text: q.sample);
    }
    for (final q in _form.yesNo) {
      _yesNo[q.label] = q.sample;
    }
    for (final q in _form.choices) {
      _choices[q.label] = q.options.first;
    }
  }

  @override
  void dispose() {
    for (final c in _numbers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    final answers = <String, Object>{
      for (final e in _numbers.entries) e.key: double.parse(e.value.text),
      ..._yesNo,
      ..._choices,
    };

    final services = widget.services;
    RiskResult? result;
    try {
      result = await services.predictions.deepCheck(widget.disease, answers);
    } catch (e) {
      if (mounted) await showErrorDialog(context, 'Deep check failed', '$e');
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (result == null) return;

    // Flowchart: "Save the prediction result in Database" -> it appears in History.
    services.history.add(result);

    // pushReplacement: the result REPLACES this form, so pressing back from the
    // result goes to the Quick Result list and can't submit the form twice.
    await Navigator.of(context).pushReplacement(MaterialPageRoute(
      builder: (_) => DeepCheckResultScreen(result: result!),
    ));
  }

  /// The boxes for the grid, in the mockup's order: Age, Sex, then the rest.
  List<Widget> _gridBoxes() {
    final boxes = <Widget>[
      for (final q in _form.numbers)
        LabeledNumberBox(label: q.label, controller: _numbers[q.label]!, decimal: q.decimal),
    ];
    // Sex is a choice, but the mockup shows it as a box right after Age.
    if (_choices.containsKey('Sex')) {
      boxes.insert(
        1,
        LabeledChoiceBox(
          label: 'Sex',
          value: _choices['Sex']!,
          options: _form.choices.firstWhere((c) => c.label == 'Sex').options,
          onChanged: (v) => setState(() => _choices['Sex'] = v),
        ),
      );
    }
    return boxes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentIndex: AppTabs.home),
      body: SafeArea(
        child: PhoneWidth(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
              children: [
                // ---- back arrow + disease name on one line
                Row(
                  children: [
                    const AppBackButton(),
                    const SizedBox(width: 4),
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown, // shrink "Diabetes Mellitus" if too long
                        alignment: Alignment.centerLeft,
                        child: Text(widget.disease.label, style: AppFonts.serif(size: 34)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TwoColumnGrid(children: _gridBoxes()),
                const SizedBox(height: 14),
                YesNoTable(
                  answers: _yesNo,
                  onChanged: (q, v) => setState(() => _yesNo[q] = v),
                ),
                const SizedBox(height: 8),
                // ---- the other drop-downs (Chest Pain Type, Smoking History)
                for (final q in _form.choices.where((c) => c.label != 'Sex')) ...[
                  // FractionallySizedBox: 70% of the width, like the mockup's box.
                  FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: 0.7,
                    child: LabeledDropdown(
                      label: q.label,
                      value: _choices[q.label]!,
                      options: q.options,
                      onChanged: (v) => setState(() => _choices[q.label] = v),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                const SizedBox(height: 12),
                Center(
                  child: PrimaryButton(
                    key: const Key('deepCheckSubmit'),
                    label: 'Deep Check',
                    width: 126,
                    fontSize: 14,
                    height: 34,
                    loading: _loading,
                    onPressed: _submit,
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
