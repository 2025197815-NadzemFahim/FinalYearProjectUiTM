// =============================================================================
// MY ACTIVITY (Profile -> My Activity) - no mockup in Section 3.5.4
//
//   <-
//   My Activity
//   Your saved checks and your details at a glance.
//   | Your deep checks                        |
//   | (heart) Heart Disease            72.4%  |   <- the latest result, coloured
//   |         2 checks · latest: Today        |
//   | (drop)  Diabetes Mellitus            -  |
//   |         No checks yet                   |
//   |           [ See all in History ]        |
//   | Your details                            |
//   | (card) My details          Complete  >  |
//   | (bag)  Medical history     Complete  >  |
//   | (run)  Lifestyle check   Retake due  >  |
//
// Everything here is READ from what the app already has: the History results
// (HistoryService) and the saved details (ProfileService). Nothing new is
// stored. Quick predictions are not saved (report 3.5.1), so they are not counted.
// =============================================================================
import 'package:flutter/material.dart';

import '../models/disease.dart';
import '../models/history_entry.dart';
import '../models/user_details.dart';
import '../navigation/app_tabs.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../utils/date_text.dart';
import '../widgets/info_page.dart';
import 'lifestyle_check_screen.dart';
import 'medical_history_screen.dart';
import 'my_details_screen.dart';

class MyActivityScreen extends StatelessWidget {
  const MyActivityScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final history = services.history;

    // Redraw when the results or the saved details change (e.g. after a save).
    return ListenableBuilder(
      listenable: Listenable.merge([
        history.entries,
        history.loading,
        history.error,
        services.profile.details,
      ]),
      builder: (context, _) => InfoPage(
        title: 'My Activity',
        subtitle: 'Your saved checks and your details at a glance.',
        children: [
          _ChecksCard(services: services),
          _DetailsCard(services: services),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------ deep checks

/// "Your deep checks": one row per disease with its latest result.
class _ChecksCard extends StatelessWidget {
  const _ChecksCard({required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final history = services.history;
    final entries = history.entries.value; // newest first
    final error = history.error.value;

    return InfoCard(
      title: 'Your deep checks',
      children: [
        // 1. the results could not be read (and there is nothing to show)
        if (error != null && entries.isEmpty) ...[
          Text(error, style: AppFonts.body(size: 13, color: AppColors.riskHigh)),
          TextButton(onPressed: history.refresh, child: const Text('Try again')),
        ]

        // 2. still reading them
        else if (history.loading.value && entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          )

        // 3. the normal case
        else ...[
          for (final disease in Disease.values) _diseaseRow(disease, entries),
          const SizedBox(height: 4),
          Center(
            child: TextButton(
              key: const Key('activitySeeHistory'),
              onPressed: () => AppTabs.goTo(context, AppTabs.history),
              child: const Text('See all in History'),
            ),
          ),
        ],

        Text(
          'Quick predictions are not saved, so they are not counted here.',
          style: AppFonts.body(size: 12, color: AppColors.hint),
        ),
      ],
    );
  }

  /// One disease: its latest result and how many checks were saved.
  Widget _diseaseRow(Disease disease, List<HistoryEntry> all) {
    // [all] is newest first, so the first one found is the latest.
    final checks = all.where((e) => e.result.disease == disease).toList();

    if (checks.isEmpty) {
      return InfoRow(
        key: Key('activity-${disease.name}'),
        icon: disease.icon,
        label: disease.label,
        value: '-',
        note: 'No checks yet',
      );
    }

    final latest = checks.first;
    final count = checks.length == 1 ? '1 check' : '${checks.length} checks';
    return InfoRow(
      key: Key('activity-${disease.name}'),
      icon: disease.icon,
      label: disease.label,
      value: '${latest.result.percentText}%',
      valueColor: latest.result.level.color, // green / orange / red, like History
      note: '$count · latest: ${DateText.day(latest.date)}',
    );
  }
}

// ---------------------------------------------------------------- details

/// "Your details": is each part answered, and when was it last updated?
class _DetailsCard extends StatelessWidget {
  const _DetailsCard({required this.services});

  final AppServices services;

  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final details = services.profile.details.value;
    final history = details.history;
    final lifestyle = details.lifestyle;

    return InfoCard(
      title: 'Your details',
      children: [
        InfoRow(
          key: const Key('activityMyDetails'),
          icon: Icons.badge,
          label: 'My details',
          value: details.profile.isComplete ? 'Complete' : 'Not finished',
          valueColor: details.profile.isComplete ? AppColors.green : AppColors.riskHigh,
          onTap: () => _open(context, MyDetailsScreen(services: services)),
        ),
        InfoRow(
          key: const Key('activityHistory'),
          icon: Icons.medical_services,
          label: 'Medical history',
          value: history.isComplete ? 'Complete' : 'Not finished',
          valueColor: history.isComplete ? AppColors.green : AppColors.riskHigh,
          note: _updated(history.updatedAt),
          onTap: () => _open(context, MedicalHistoryScreen(services: services)),
        ),
        _lifestyleRow(context, lifestyle),
      ],
    );
  }

  /// The Lifestyle check goes out of date after 90 days, so it has three states.
  Widget _lifestyleRow(BuildContext context, LifestyleAnswers lifestyle) {
    final String status;
    final Color color;
    String? note = _updated(lifestyle.updatedAt);

    if (!lifestyle.isComplete) {
      status = 'Not finished';
      color = AppColors.riskHigh;
    } else if (lifestyle.needsRetake(DateTime.now())) {
      status = 'Retake due';
      color = AppColors.riskModerate;
    } else {
      status = 'Up to date';
      color = AppColors.green;
      final next = lifestyle.updatedAt!.add(LifestyleAnswers.retakeAfter);
      note = '$note\nNext retake: ${DateText.day(next)}';
    }

    return InfoRow(
      key: const Key('activityLifestyle'),
      icon: Icons.directions_run,
      label: 'Lifestyle check',
      value: status,
      valueColor: color,
      note: note,
      onTap: () => _open(context, LifestyleCheckScreen(services: services)),
    );
  }

  /// "Last updated: 3 November" (null when it was never saved).
  static String? _updated(DateTime? when) =>
      when == null ? null : 'Last updated: ${DateText.day(when)}';
}
