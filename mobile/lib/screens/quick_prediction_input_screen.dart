// =============================================================================
// 5. QUICK PREDICTION INPUT INTERFACE (Figure 3.19, updated for task U4)
//
//   <-
//   | Using your saved details        > |   <- profile, history, lifestyle (15 readings)
//     Weight [70 KG]        BMI [24.2]      <- BMI = weight + saved height
//     Poor mental-health days [0]   Poor physical-health days [0]
//   General Health [Good v]
//   Couldn't see a doctor because of cost?   NO (o)  YES ( )
//                 [ Check ]
//
// The model needs 20 readings. 15 come from the saved details (asked once), so
// this screen only asks the 5 that change (docs/input_readings.md, section 7).
// ApiPayloads.quick() builds the exact API request from both.
// Flow (Figure 3.25): Check -> AI model -> Quick Prediction Result.
// =============================================================================
import 'package:flutter/material.dart';

import '../models/api_payloads.dart';
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

  // Weight starts at the last value typed (it changes, so it is asked every time).
  late final _weight = TextEditingController(
      text: widget.services.profile.details.value.lastWeightKg?.toString() ?? '');
  final _bmi = TextEditingController();
  final _mentalDays = TextEditingController(text: '0');
  final _physicalDays = TextEditingController(text: '0');
  String _generalHealth = 'Good';

  static const _skippedQuestion = "Needed a doctor in the past 12 months but couldn't, "
      'because of cost?';
  final Map<String, bool> _yesNo = {_skippedQuestion: false};

  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _updateBmi();
  }

  @override
  void dispose() {
    for (final c in [_weight, _bmi, _mentalDays, _physicalDays]) {
      c.dispose();
    }
    super.dispose();
  }

  /// BMI = weight (kg) / height (m)^2, with the height saved in My details.
  void _updateBmi() {
    final kg = double.tryParse(_weight.text);
    final cm = widget.services.profile.details.value.profile.heightCm;
    _bmi.text = (kg == null || cm == null) ? '' : ApiPayloads.bmi(kg, cm).toStringAsFixed(1);
  }

  Future<void> _check() async {
    if (_loading || !_formKey.currentState!.validate()) return;
    final services = widget.services;
    // Safety net: the details must be complete before a prediction can be built.
    if (!await ensureDetailsComplete(context, services) || !mounted) return;
    setState(() => _loading = true);

    final weight = double.parse(_weight.text);
    final payload = ApiPayloads.quick(
      services.profile.details.value,
      QuickCheckAnswers(
        weightKg: weight,
        generalHealth: generalHealthOptions.indexOf(_generalHealth) + 1, // 1 excellent ... 5 poor
        poorMentalDays: int.parse(_mentalDays.text),
        poorPhysicalDays: int.parse(_physicalDays.text),
        skippedDoctorCost: _yesNo[_skippedQuestion]!,
      ),
      DateTime.now(),
    );
    await services.profile.saveLastWeight(weight);

    List<RiskResult>? results;
    try {
      results = await services.predictions.quickPredict(payload);
    } catch (e) {
      // e.g. no internet once the real backend is connected
      if (mounted) await showErrorDialog(context, 'Prediction failed', '$e');
    }
    if (!mounted) return;
    setState(() => _loading = false);
    if (results == null) return;

    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => QuickPredictionResultScreen(services: services, results: results!),
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
                SavedDetailsCard(services: widget.services),
                const SizedBox(height: 8),
                Text('Today', style: AppFonts.serif(size: 18)),
                const SizedBox(height: 12),
                // ---- the per-check readings, two per row
                TwoColumnGrid(
                  children: [
                    LabeledNumberBox(
                      key: const Key('weight'),
                      label: 'Weight',
                      controller: _weight,
                      suffix: 'KG',
                      decimal: true,
                      min: 20,
                      max: 350,
                      onChanged: (_) => setState(_updateBmi),
                    ),
                    LabeledNumberBox(label: 'BMI', controller: _bmi, readOnly: true),
                    LabeledNumberBox(
                      key: const Key('mentalDays'),
                      label: 'Poor mental-health days',
                      controller: _mentalDays,
                      min: 0,
                      max: 30,
                    ),
                    LabeledNumberBox(
                      key: const Key('physicalDays'),
                      label: 'Poor physical-health days',
                      controller: _physicalDays,
                      min: 0,
                      max: 30,
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Days in the past 30 days when your mental / physical health was not good.',
                      style: AppFonts.body(size: 12, color: AppColors.hint)),
                ),
                const SizedBox(height: 18),
                LabeledDropdown(
                  label: 'In general, your health is',
                  value: _generalHealth,
                  options: generalHealthOptions,
                  onChanged: (v) => setState(() => _generalHealth = v),
                ),
                const SizedBox(height: 18),
                YesNoTable(
                  answers: _yesNo,
                  onChanged: (question, value) => setState(() => _yesNo[question] = value),
                ),
                const SizedBox(height: 40),
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
