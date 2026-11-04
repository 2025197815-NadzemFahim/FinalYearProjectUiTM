// =============================================================================
// HISTORY SERVICE - DUMMY VERSION (kept in memory, lost when the app closes)
//
// Starts with sample entries like Figure 3.23 (Diagnosis 1-7 on four dates).
// New deep-check results are added with add(), so the History tab updates
// immediately. Later, replace this with reads/writes to Firestore
// users/{uid}/deepCheckResults (docs/DATABASE.md) - screens won't change.
// =============================================================================
import 'package:flutter/foundation.dart';

import '../models/disease.dart';
import '../models/history_entry.dart';
import 'prediction_service.dart';

class HistoryService {
  HistoryService() {
    entries.value = _sampleEntries();
  }

  /// A ValueNotifier: the History screen rebuilds automatically when it changes.
  final ValueNotifier<List<HistoryEntry>> entries = ValueNotifier(const []);

  /// Save a new deep-check result (flowchart: "Save the prediction result in Database").
  void add(RiskResult result) {
    final next = HistoryEntry(
      title: 'Diagnosis ${entries.value.length + 1}',
      result: result,
      // the API's own notes + disclaimer when there are some
      explanation: result.explanation ?? PredictionService.deepExplanation(result),
      date: DateTime.now(),
    );
    // Make a NEW list (newest first) instead of changing the old one, so the
    // notifier sees a different value and tells the screen to rebuild.
    entries.value = [next, ...entries.value];
  }

  static List<HistoryEntry> _sampleEntries() {
    final now = DateTime.now();
    // (days ago, disease, percent) for Diagnosis 7 down to Diagnosis 1
    final samples = <(int, Disease, double)>[
      (0, Disease.heart, 80),
      (40, Disease.diabetes, 62),
      (40, Disease.stroke, 35),
      (68, Disease.heart, 55),
      (68, Disease.diabetes, 28),
      (68, Disease.stroke, 18),
      (101, Disease.heart, 47),
    ];
    return [
      for (var i = 0; i < samples.length; i++)
        HistoryEntry(
          title: 'Diagnosis ${samples.length - i}',
          result: RiskResult(disease: samples[i].$2, percent: samples[i].$3),
          explanation: PredictionService.deepExplanation(
              RiskResult(disease: samples[i].$2, percent: samples[i].$3)),
          date: now.subtract(Duration(days: samples[i].$1)),
        ),
    ];
  }
}
