// =============================================================================
// MEDICAL HISTORY (readings 10-14): "Has a doctor ever told you...", asked once,
// editable from Profile. Wording follows the BRFSS questions the model was trained
// on (docs/lifestyle_check_proposal.md, section C), so the answers mean the same.
// =============================================================================
import 'package:flutter/material.dart';

import '../models/user_details.dart';
import '../services/app_services.dart';
import '../widgets/choice_question_field.dart';
import '../widgets/details_page.dart';

class MedicalHistoryScreen extends StatefulWidget {
  const MedicalHistoryScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<MedicalHistoryScreen> createState() => _MedicalHistoryScreenState();
}

class _MedicalHistoryScreenState extends State<MedicalHistoryScreen> {
  final _formKey = GlobalKey<FormState>();
  late final MedicalHistory _saved = widget.services.profile.details.value.history;
  late bool? _highBp = _saved.highBloodPressure;
  late bool? _highChol = _saved.highCholesterol;
  late bool? _cholChecked = _saved.cholesterolChecked5y;
  late bool? _heart = _saved.heartDisease;
  late bool? _walking = _saved.difficultyWalking;
  bool _saving = false;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return DetailsPage.showMissing(context);
    setState(() => _saving = true);
    await widget.services.profile.saveHistory(MedicalHistory(
      highBloodPressure: _highBp,
      highCholesterol: _highChol,
      cholesterolChecked5y: _cholChecked,
      heartDisease: _heart,
      difficultyWalking: _walking,
      updatedAt: DateTime.now(),
    ));
    if (mounted) Navigator.of(context).pop(true);
  }

  // One yes/no question; `set` stores the answer in the matching variable.
  Widget _q(String key, String question, bool? value, ValueChanged<bool> set, {String? hint}) =>
      ChoiceQuestionField<bool>(
        key: Key(key),
        question: question,
        hint: hint,
        initialValue: value,
        options: yesNoOptions,
        onChanged: set,
      );

  @override
  Widget build(BuildContext context) {
    return DetailsPage(
      title: 'Medical history',
      subtitle: 'Has a doctor, nurse or other health professional ever told you...',
      formKey: _formKey,
      saveKey: const Key('saveHistory'),
      saving: _saving,
      onSave: _save,
      children: [
        _q('highBp', '...that you have high blood pressure?', _highBp, (v) => _highBp = v,
            hint: 'Not counting only during pregnancy. "Borderline" counts as No.'),
        _q('highChol', '...that your blood cholesterol is high?', _highChol, (v) => _highChol = v),
        _q('cholChecked', 'Have you had your cholesterol checked in the last 5 years?',
            _cholChecked, (v) => _cholChecked = v),
        _q('heartDisease', '...that you have heart disease?', _heart, (v) => _heart = v,
            hint: 'For example coronary heart disease, a heart attack or angina.'),
        _q('walking', 'Do you have serious difficulty walking or climbing stairs?', _walking,
            (v) => _walking = v),
      ],
    );
  }
}
