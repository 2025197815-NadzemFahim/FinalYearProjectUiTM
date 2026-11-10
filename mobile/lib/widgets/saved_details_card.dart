// The "Using your saved details" card at the top of Quick Prediction and
// Deep-Check. Closed by default (one line); opened, it lists what will be sent
// and has Edit buttons. It listens to ProfileService, so after an edit it
// updates by itself.
//
//   | Using your saved details    updated 29 Oct    > |
import 'package:flutter/material.dart';

import '../models/user_details.dart';
import '../screens/lifestyle_check_screen.dart';
import '../screens/medical_history_screen.dart';
import '../screens/my_details_screen.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import 'expandable_card.dart';

class SavedDetailsCard extends StatelessWidget {
  const SavedDetailsCard({super.key, required this.services});

  final AppServices services;

  static String _yn(bool? v) => v == null ? '-' : (v ? 'Yes' : 'No');
  static String _date(DateTime? d) => d == null ? '' : '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<UserDetails>(
      valueListenable: services.profile.details,
      builder: (context, d, _) {
        final p = d.profile, h = d.history, l = d.lifestyle;
        final rows = <(String, String)>[
          ('Age, sex', '${p.ageOn(DateTime.now()) ?? '-'}, ${p.sex ?? '-'}'),
          ('Height', p.heightCm == null ? '-' : '${p.heightCm!.toStringAsFixed(0)} cm'),
          ('High blood pressure', _yn(h.highBloodPressure)),
          ('High cholesterol', _yn(h.highCholesterol)),
          ('Heart disease', _yn(h.heartDisease)),
          ('Smoking', l.smokingLevel ?? '-'),
          ('Physical activity', l.activity?.level ?? '-'),
          ('Alcohol', l.isComplete ? l.alcoholLevel(p.sex) : '-'),
        ];
        void open(Widget screen) =>
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
        return ExpandableCard(
          key: const Key('savedDetailsCard'),
          title: 'Using your saved details',
          trailingText: l.updatedAt == null ? null : 'updated ${_date(l.updatedAt)}',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (name, value) in rows)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(children: [
                    Expanded(child: Text(name, style: AppFonts.body(size: 13, color: AppColors.hint))),
                    Text(value, style: AppFonts.body(size: 13)),
                  ]),
                ),
              const SizedBox(height: 10),
              Wrap(spacing: 4, children: [
                TextButton(onPressed: () => open(MyDetailsScreen(services: services)),
                    child: const Text('Edit my details')),
                TextButton(onPressed: () => open(MedicalHistoryScreen(services: services)),
                    child: const Text('Edit history')),
                TextButton(onPressed: () => open(LifestyleCheckScreen(services: services)),
                    child: const Text('Retake lifestyle')),
              ]),
            ],
          ),
        );
      },
    );
  }
}
