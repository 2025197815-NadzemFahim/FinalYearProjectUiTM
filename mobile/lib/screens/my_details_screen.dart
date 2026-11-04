// =============================================================================
// MY DETAILS (readings 3-9): stable facts, asked once and editable from Profile.
// Approved at CHECKPOINT 5/6: docs/input_readings.md, docs/lifestyle_check_proposal.md.
// Age and sex (readings 1-2) and the contact number are asked ONLY at Create
// Account (decision 2026-11-04); this screen just shows them.
//
// Pops with `true` when saved, so the "complete your details" flow can continue.
// =============================================================================
import 'package:flutter/material.dart';

import '../models/user_details.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/choice_question_field.dart';
import '../widgets/details_page.dart';
import '../widgets/labeled_box.dart';

class MyDetailsScreen extends StatefulWidget {
  const MyDetailsScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<MyDetailsScreen> createState() => _MyDetailsScreenState();
}

class _MyDetailsScreenState extends State<MyDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _height = TextEditingController(text: _num(_saved.heightCm));
  late final _income = TextEditingController(text: _num(_saved.incomeMonthlyRm));

  // Start from what is already saved, so this screen also works for editing.
  late final UserProfile _saved = widget.services.profile.details.value.profile;
  late Education? _education = _saved.education;
  late bool? _coverage = _saved.healthCoverage;
  late bool? _married = _saved.everMarried;
  late WorkType? _work = _saved.workType;
  late Residence? _residence = _saved.residence;
  bool _saving = false;

  static String _num(double? v) =>
      v == null ? '' : (v == v.roundToDouble() ? v.toInt().toString() : '$v');

  @override
  void dispose() {
    _height.dispose();
    _income.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return DetailsPage.showMissing(context);
    setState(() => _saving = true);
    // withDetails keeps the age, sex and contact from Create Account
    await widget.services.profile.saveProfile(_saved.withDetails(
      heightCm: double.parse(_height.text),
      education: _education!,
      incomeMonthlyRm: double.parse(_income.text),
      healthCoverage: _coverage!,
      everMarried: _married!,
      workType: _work!,
      residence: _residence!,
    ));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final age = _saved.ageOn(DateTime.now());
    final fromAccount = age == null
        ? 'Age and sex: not found (they are entered at Create Account).'
        : 'Age $age · ${_saved.sex == 'male' ? 'Male' : 'Female'} (from your account)';
    return DetailsPage(
      title: 'My details',
      subtitle: 'Asked once and used in every check. You can change them anytime in Profile.',
      formKey: _formKey,
      saveKey: const Key('saveMyDetails'),
      saving: _saving,
      onSave: _save,
      children: [
        // 1-2. Age and sex: shown only, asked at Create Account
        Text(fromAccount, key: const Key('fromAccount'),
            style: AppFonts.body(size: 13, color: AppColors.hint)),
        const SizedBox(height: 18),
        // 3. Height + 5. income: two number boxes side by side
        TwoColumnGrid(children: [
          LabeledNumberBox(
              key: const Key('height'), label: 'Height', controller: _height,
              suffix: 'CM', decimal: true, min: 90, max: 250),
          LabeledNumberBox(
              key: const Key('income'), label: 'Household income / month', controller: _income,
              suffix: 'RM', min: 0, max: 1000000),
        ]),
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 18),
          child: Text('Income: the total for everyone in your home. It is only used as a general '
              'social factor and stays private.',
              style: AppFonts.body(size: 12, color: AppColors.hint)),
        ),
        // 4. Education (table E)
        ChoiceQuestionField<Education>(
          key: const Key('education'),
          question: 'Highest education completed',
          initialValue: _education,
          options: [for (final e in Education.values) (e, e.label)],
          onChanged: (v) => _education = v,
        ),
        // 6. Health coverage, option (i)
        ChoiceQuestionField<bool>(
          key: const Key('coverage'),
          question: 'Do you have health coverage?',
          hint: 'Yes if you are a Malaysian citizen (public healthcare), or have insurance/takaful '
              'or an employer panel clinic.',
          initialValue: _coverage,
          options: yesNoOptions,
          onChanged: (v) => _coverage = v,
        ),
        // 7. Ever married
        ChoiceQuestionField<bool>(
          key: const Key('married'),
          question: 'Have you ever been married?',
          hint: 'Divorced or widowed also counts as yes.',
          initialValue: _married,
          options: yesNoOptions,
          onChanged: (v) => _married = v,
        ),
        // 8. Work type (W1)
        ChoiceQuestionField<WorkType>(
          key: const Key('work'),
          question: 'Your main type of work over your working life',
          hint: 'Retired or not working now? Choose the job you had for most of your life.',
          initialValue: _work,
          options: [for (final w in WorkType.values) (w, w.label)],
          onChanged: (v) => _work = v,
        ),
        // 9. Residence
        ChoiceQuestionField<Residence>(
          key: const Key('residence'),
          question: 'Where do you live?',
          initialValue: _residence,
          options: [for (final r in Residence.values) (r, r.label)],
          onChanged: (v) => _residence = v,
        ),
      ],
    );
  }
}
