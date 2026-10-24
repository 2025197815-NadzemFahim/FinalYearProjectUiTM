import 'disease.dart';

/// One saved deep-check result, shown on the History screen (Figure 3.23).
/// Matches the DeepCheckResult entity in the ERD: disease, risk %, explanation, date.
class HistoryEntry {
  const HistoryEntry({
    required this.title,
    required this.result,
    required this.explanation,
    required this.date,
  });

  final String title;        // "Diagnosis 7" in the mockup
  final RiskResult result;   // disease + percentage
  final String explanation;  // the paragraph shown on the result screen
  final DateTime date;       // used to group the list ("Today", "10 May"...)
}
