// =============================================================================
// 9. HISTORY INTERFACE (Figure 3.23) - the History tab
//
//   History
//   Today
//   | Diagnosis 7                    (->) |
//   10 May
//   | Diagnosis 6                    (->) |
//   | Diagnosis 5                    (->) |
//
// Past deep-check results, newest first, grouped under a date heading.
// Tapping a card opens the full result (the Deep-Check Result screen).
// They are read from the database at login; pull the list down to read again.
//
// Assumption: the mockup leaves the line under "Diagnosis N" empty; here it
// shows the disease and percentage so the cards can be told apart.
// =============================================================================
import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../navigation/app_tabs.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../utils/date_text.dart';
import '../widgets/phone_width.dart';
import 'deep_check_result_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final history = services.history;

    // Redraws whenever the list, the loading flag or the error changes
    // (e.g. a new deep check was added) - no setState needed here.
    return ListenableBuilder(
      listenable: Listenable.merge([history.entries, history.loading, history.error]),
      builder: (context, _) {
        final entries = history.entries.value;
        final error = history.error.value;

        return SafeArea(
          child: PhoneWidth(
            // RefreshIndicator: pull the list down to read it again.
            child: RefreshIndicator(
              onRefresh: history.refresh,
              child: ListView(
                // Lets the pull work even when the list is too short to scroll.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
                children: [
                  Text('History', style: AppFonts.serif(size: 40)),
                  const SizedBox(height: 8),

                  // At most one of these three messages:
                  if (error != null)
                    _LoadError(message: error, onRetry: history.refresh)
                  else if (entries.isEmpty && history.loading.value)
                    const Padding(
                      padding: EdgeInsets.only(top: 60),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (entries.isEmpty)
                    const _NoResultsYet(),

                  for (var i = 0; i < entries.length; i++) ...[
                    // Show a date heading only when the date changes from the card above.
                    if (i == 0 || !DateText.sameDay(entries[i].date, entries[i - 1].date))
                      Padding(
                        padding: EdgeInsets.fromLTRB(8, i == 0 ? 8 : 18, 0, 6),
                        child: Text(DateText.day(entries[i].date),
                            style: AppFonts.body(size: 15, color: AppColors.hint)),
                      ),
                    _HistoryCard(services: services, entry: entries[i]),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// One white card: "Diagnosis N", a thin line, the result, and the arrow.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.services, required this.entry});

  final AppServices services;
  final HistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    final r = entry.result;
    return Container(
      margin: const EdgeInsets.only(bottom: 14), // space between cards
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('history-${entry.title}'),
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DeepCheckResultScreen(
              services: services,
              result: r,
              explanation: entry.explanation,
              tab: AppTabs.history, // keep the History icon green
            ),
          )),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.title, style: AppFonts.serif(size: 15)),
                      const Divider(height: 10, color: AppColors.divider),
                      Text('${r.disease.label} · ${r.percentText}%',
                          style: AppFonts.body(size: 13, color: AppColors.hint)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_circle_right_outlined, size: 34, color: Color(0xFF2D3748)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown when the user has no saved results yet.
class _NoResultsYet extends StatelessWidget {
  const _NoResultsYet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(Icons.history, size: 48, color: AppColors.hint),
          const SizedBox(height: 12),
          Text('No predictions yet.',
              textAlign: TextAlign.center, style: AppFonts.body(size: 15, color: AppColors.hint)),
          const SizedBox(height: 4),
          Text('Your deep-check results will appear here.',
              textAlign: TextAlign.center, style: AppFonts.body(size: 13, color: AppColors.hint)),
        ],
      ),
    );
  }
}

/// Shown when the history could not be read (e.g. no internet), with a retry button.
class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          const Icon(Icons.cloud_off, size: 48, color: AppColors.riskHigh),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center, style: AppFonts.body(size: 14)),
          const SizedBox(height: 16),
          OutlinedButton(
            key: const Key('historyRetry'),
            onPressed: onRetry,
            child: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}
