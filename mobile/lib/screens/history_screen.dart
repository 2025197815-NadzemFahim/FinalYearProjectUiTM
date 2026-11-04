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
//
// Assumption: the mockup leaves the line under "Diagnosis N" empty; here it
// shows the disease and percentage so the cards can be told apart.
// =============================================================================
import 'package:flutter/material.dart';

import '../models/history_entry.dart';
import '../navigation/app_tabs.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/phone_width.dart';
import 'deep_check_result_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    // ValueListenableBuilder redraws the list whenever HistoryService.add()
    // saves a new result - no setState needed here.
    return ValueListenableBuilder<List<HistoryEntry>>(
      valueListenable: services.history.entries,
      builder: (context, entries, _) {
        return SafeArea(
          child: PhoneWidth(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              children: [
                Text('History', style: AppFonts.serif(size: 40)),
                const SizedBox(height: 8),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text('No predictions yet.',
                        textAlign: TextAlign.center,
                        style: AppFonts.body(size: 15, color: AppColors.hint)),
                  ),
                for (var i = 0; i < entries.length; i++) ...[
                  // Show a date heading only when the date changes from the card above.
                  if (i == 0 || !_sameDay(entries[i].date, entries[i - 1].date))
                    Padding(
                      padding: EdgeInsets.fromLTRB(8, i == 0 ? 8 : 18, 0, 6),
                      child: Text(_dateHeading(entries[i].date),
                          style: AppFonts.body(size: 15, color: AppColors.hint)),
                    ),
                  _HistoryCard(entry: entries[i]),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static const _months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  /// "Today", "10 May", or "10 May 2025" for earlier years.
  static String _dateHeading(DateTime d) {
    final now = DateTime.now();
    if (_sameDay(d, now)) return 'Today';
    final text = '${d.day} ${_months[d.month - 1]}';
    return d.year == now.year ? text : '$text ${d.year}';
  }
}

/// One white card: "Diagnosis N", a thin line, the result, and the arrow.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.entry});
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
