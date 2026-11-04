// =============================================================================
// LIFESTYLE CHECK (readings 15-19): a short, retakeable questionnaire.
// Questions, levels and mappings approved at CHECKPOINT 6
// (docs/lifestyle_check_proposal.md, section A). After saving, the user sees
// their levels (e.g. "Semi-active"); the models receive the exact codes made in
// models/api_payloads.dart. Reminder to retake after 90 days (Main screen).
// =============================================================================
import 'package:flutter/material.dart';

import '../models/user_details.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/choice_question_field.dart';
import '../widgets/details_page.dart';
import '../widgets/labeled_box.dart';

class LifestyleCheckScreen extends StatefulWidget {
  const LifestyleCheckScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<LifestyleCheckScreen> createState() => _LifestyleCheckScreenState();
}

class _LifestyleCheckScreenState extends State<LifestyleCheckScreen> {
  final _formKey = GlobalKey<FormState>();
  late final LifestyleAnswers _saved = widget.services.profile.details.value.lifestyle;
  late bool? _smoked100 = _saved.smoked100;
  late bool? _smokesNow = _saved.smokesNow;
  late ActivityAnswer? _activity = _saved.activity;
  late FoodFrequency? _fruit = _saved.fruit;
  late FoodFrequency? _veg = _saved.vegetables;
  late bool? _drinks = _saved.drinksAlcohol;
  late final _perWeek = TextEditingController(text: _saved.drinksPerWeek?.toString() ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _perWeek.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return DetailsPage.showMissing(context);
    setState(() => _saving = true);
    final answers = LifestyleAnswers(
      smoked100: _smoked100,
      smokesNow: _smokesNow,
      activity: _activity,
      fruit: _fruit,
      vegetables: _veg,
      drinksAlcohol: _drinks,
      drinksPerWeek: _drinks == true ? int.parse(_perWeek.text) : null,
      updatedAt: DateTime.now(),
    );
    await widget.services.profile.saveLifestyle(answers);
    if (!mounted) return;
    setState(() => _saving = false); // stop the spinner before the dialog covers it
    await _showLevels(answers);
    if (mounted) Navigator.of(context).pop(true);
  }

  /// The user's levels: what they learn from the check.
  Future<void> _showLevels(LifestyleAnswers a) {
    final sex = widget.services.profile.details.value.profile.sex;
    final rows = [
      ('Smoking', a.smokingLevel!),
      ('Physical activity', a.activity!.level),
      ('Fruit', a.fruit!.daily ? 'Daily' : 'Less than daily'),
      ('Vegetables', a.vegetables!.daily ? 'Daily' : 'Less than daily'),
      ('Alcohol', a.alcoholLevel(sex)),
    ];
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your lifestyle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (name, level) in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(name, style: AppFonts.body(size: 14))),
                  Text(level, style: AppFonts.body(size: 14, weight: FontWeight.w600)),
                ]),
              ),
            const SizedBox(height: 8),
            Text('These answers pre-fill your checks. Retake anytime from Profile.',
                style: AppFonts.body(size: 12, color: AppColors.hint)),
          ],
        ),
        actions: [
          FilledButton(
              key: const Key('lifestyleDone'),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailsPage(
      title: 'Lifestyle check',
      subtitle: 'Five quick questions about your habits. Retake it whenever they change.',
      formKey: _formKey,
      saveKey: const Key('saveLifestyle'),
      saving: _saving,
      onSave: _save,
      children: [
        // 15. Smoking: two questions -> one level (proposal S1: cigarettes only)
        ChoiceQuestionField<bool>(
          key: const Key('smoked100'),
          question: 'Have you smoked at least 100 cigarettes (about 5 packs) in your whole life?',
          hint: 'Cigarettes only: vape / e-cigarettes are not counted.',
          initialValue: _smoked100,
          options: yesNoOptions,
          onChanged: (v) => _smoked100 = v,
        ),
        ChoiceQuestionField<bool>(
          key: const Key('smokesNow'),
          question: 'Do you smoke cigarettes now, every day or on some days?',
          initialValue: _smokesNow,
          options: yesNoOptions,
          onChanged: (v) => _smokesNow = v,
        ),
        // 16. Physical activity: 3 levels for the user, yes/no for the model
        ChoiceQuestionField<ActivityAnswer>(
          key: const Key('activity'),
          question: 'In the past 30 days, not counting your job, how often did you exercise?',
          hint: 'For example brisk walking, jogging, sports or gardening.',
          initialValue: _activity,
          options: [for (final a in ActivityAnswer.values) (a, a.label)],
          onChanged: (v) => _activity = v,
        ),
        // 17-18. Fruit and vegetables
        ChoiceQuestionField<FoodFrequency>(
          key: const Key('fruit'),
          question: 'How often do you eat fruit?',
          hint: 'Fresh, frozen or canned fruit, or 100% fruit juice.',
          initialValue: _fruit,
          options: [for (final f in FoodFrequency.values) (f, f.label)],
          onChanged: (v) => _fruit = v,
        ),
        ChoiceQuestionField<FoodFrequency>(
          key: const Key('vegetables'),
          question: 'How often do you eat vegetables?',
          hint: 'Including salad and beans.',
          initialValue: _veg,
          options: [for (final f in FoodFrequency.values) (f, f.label)],
          onChanged: (v) => _veg = v,
        ),
        // 19. Alcohol: "Do you drink?" first, the number only if yes
        ChoiceQuestionField<bool>(
          key: const Key('drinks'),
          question: 'Do you drink alcohol?',
          initialValue: _drinks,
          options: yesNoOptions,
          onChanged: (v) => setState(() => _drinks = v), // setState: shows/hides the next box
        ),
        if (_drinks == true) ...[
          Text('In a typical week, how many drinks?',
              style: AppFonts.body(size: 15, weight: FontWeight.w600)),
          Text('1 drink = 1 can of beer (330 ml), 1 glass of wine (150 ml) or 1 shot (45 ml).',
              style: AppFonts.body(size: 12, color: AppColors.hint)),
          const SizedBox(height: 8),
          FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 0.5,
            child: LabeledNumberBox(
                key: const Key('drinksPerWeek'), label: 'Drinks per week',
                controller: _perWeek, min: 1, max: 200),
          ),
          const SizedBox(height: 18),
        ],
      ],
    );
  }
}
