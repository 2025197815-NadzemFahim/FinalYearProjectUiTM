// =============================================================================
// 7. DEEP-CHECK INPUT INTERFACE (Figure 3.21, updated for tasks U4 + U4b)
//
//   <-  Heart Disease
//   Have you done an exercise stress test recently?        <- heart only, asked first
//     [ Yes, I have the results ]   [ No ]
//
//   | Using your saved details        > |   <- age, sex, history, lifestyle
//      Resting BP [146 mmHg]   Cholesterol [236 mg/dL]
//      ...
//   Chest Pain Type [ Typical Angina  v ]
//              [ Deep Check ]
//
// ONE screen serves all three diseases: it reads the question list from
// DeepCheckForm.forDisease() (models/deep_check_form.dart) and builds the boxes.
// Heart: Yes = full model (10 readings), No = reduced model (7, no hospital-only
// stress-test readings). Stroke and diabetes only ask what changes per check.
//
// Flow (Figure 3.25): Deep Check -> AI model -> save result -> show result.
// =============================================================================
import 'package:flutter/material.dart';

import '../models/api_payloads.dart';
import '../models/deep_check_form.dart';
import '../models/disease.dart';
import '../navigation/app_tabs.dart';
import '../navigation/details_flow.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/labeled_box.dart';
import '../widgets/labeled_dropdown.dart';
import '../widgets/phone_width.dart';
import '../widgets/primary_button.dart';
import '../widgets/saved_details_card.dart';
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

  /// Heart only: null = not asked yet, true = full model, false = reduced model.
  bool? _stressTest;
  DeepCheckForm? _form;

  // One controller / answer per question, looked up by the question's key.
  final Map<String, TextEditingController> _numbers = {};
  final Map<String, bool> _yesNo = {};          // YesNoTable shows the label...
  final Map<String, String> _yesNoKeys = {};    // ...this maps label -> API key
  final Map<String, Choice> _choices = {};

  bool _loading = false;

  bool get _isHeart => widget.disease == Disease.heart;

  @override
  void initState() {
    super.initState();
    if (!_isHeart) _buildForm(stressTest: true); // stroke / diabetes: straight to the form
  }

  void _buildForm({required bool stressTest}) {
    final form = DeepCheckForm.forDisease(widget.disease, stressTest: stressTest);
    final lastWeight = widget.services.profile.details.value.lastWeightKg;
    for (final q in form.numbers) {
      final start = (q.key == 'weight_kg' && lastWeight != null) ? '$lastWeight' : q.sample;
      _numbers[q.key] = TextEditingController(text: start);
    }
    for (final q in form.yesNo) {
      _yesNo[q.label] = q.sample;
      _yesNoKeys[q.label] = q.key;
    }
    for (final q in form.choices) {
      _choices[q.key] = q.options.first;
    }
    _form = form;
  }

  @override
  void dispose() {
    for (final c in _numbers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _form!;
    if (_loading || !_formKey.currentState!.validate()) return;
    final services = widget.services;
    if (!await ensureDetailsComplete(context, services) || !mounted) return;
    setState(() => _loading = true);

    // The screen's answers keyed by API field (whole numbers stay whole numbers).
    final answers = <String, Object>{
      for (final q in form.numbers)
        q.key: q.decimal ? double.parse(_numbers[q.key]!.text) : int.parse(_numbers[q.key]!.text),
      for (final e in _yesNo.entries) _yesNoKeys[e.key]!: e.value,
      for (final e in _choices.entries) e.key: e.value.value,
    };
    if (answers['weight_kg'] case final num kg) await services.profile.saveLastWeight(kg.toDouble());
    final payload = ApiPayloads.deep(widget.disease, services.profile.details.value, answers,
        DateTime.now());

    RiskResult? result;
    try {
      result = await services.predictions.deepCheck(widget.disease, payload);
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
                if (_form == null) _stressTestQuestion() else ..._formFields(_form!),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Heart only, asked before the form (CHECKPOINT 5, decision 3).
  Widget _stressTestQuestion() {
    void choose(bool yes) => setState(() {
          _stressTest = yes;
          _buildForm(stressTest: yes);
        });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Text('Have you done an exercise stress test recently?',
            style: AppFonts.body(size: 18, weight: FontWeight.w600)),
        const SizedBox(height: 8),
        Text('A treadmill test at a hospital or heart clinic. Its report gives your maximum heart '
            'rate, ST depression and whether you had chest pain during the test.',
            style: AppFonts.body(size: 13, color: AppColors.hint)),
        const SizedBox(height: 28),
        Center(
          child: PrimaryButton(key: const Key('stressYes'), label: 'Yes, I have the results',
              width: 260, onPressed: () => choose(true)),
        ),
        const SizedBox(height: 12),
        Center(
          child: OutlinedButton(
            key: const Key('stressNo'),
            onPressed: () => choose(false),
            child: const Text('No, continue without it'),
          ),
        ),
      ],
    );
  }

  List<Widget> _formFields(DeepCheckForm form) => [
        if (_isHeart && _stressTest == false)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text('Check without a stress test: uses 7 readings, slightly less precise.',
                style: AppFonts.body(size: 12, color: AppColors.hint)),
          ),
        SavedDetailsCard(services: widget.services),
        const SizedBox(height: 8),
        TwoColumnGrid(children: [
          for (final q in form.numbers)
            LabeledNumberBox(
              key: Key(q.key),
              label: q.label,
              controller: _numbers[q.key]!,
              suffix: q.unit,
              decimal: q.decimal,
              min: q.min,
              max: q.max,
            ),
        ]),
        if (form.numbers.any((q) => q.key == 'weight_kg'))
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('BMI is calculated from this weight and your saved height.',
                style: AppFonts.body(size: 12, color: AppColors.hint)),
          ),
        const SizedBox(height: 14),
        if (_yesNo.isNotEmpty)
          YesNoTable(answers: _yesNo, onChanged: (q, v) => setState(() => _yesNo[q] = v)),
        const SizedBox(height: 8),
        // ---- drop-downs (Chest Pain Type, Resting ECG)
        for (final q in form.choices) ...[
          LabeledDropdown(
            label: q.label,
            value: _choices[q.key]!.label,
            options: [for (final o in q.options) o.label],
            onChanged: (label) =>
                setState(() => _choices[q.key] = q.options.firstWhere((o) => o.label == label)),
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
      ];
}
