// =============================================================================
// MODELS: plain data classes. No widgets here, just information.
// (In MVC terms this is the "M". Screens are the "V", services the "C".)
// =============================================================================
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The three diseases the app screens for (report Section 1.6).
/// An enum is a fixed list of choices, so a typo like "hart" is impossible.
enum Disease {
  heart('Heart Disease'),
  diabetes('Diabetes Mellitus'),
  stroke('Stroke');

  const Disease(this.label);

  /// The name shown on screen.
  final String label;
}

/// Low / moderate / high, worked out from a percentage.
enum RiskLevel {
  low('low', AppColors.riskLow),
  moderate('moderate', AppColors.riskModerate),
  high('high', AppColors.riskHigh);

  const RiskLevel(this.word, this.color);
  final String word;
  final Color color;

  /// Assumption (not in the report): below 30% low, 30-60% moderate, above 60% high.
  static RiskLevel fromPercent(double percent) {
    if (percent > 60) return RiskLevel.high;
    if (percent >= 30) return RiskLevel.moderate;
    return RiskLevel.low;
  }
}

/// One prediction: which disease, and how likely.
class RiskResult {
  const RiskResult({required this.disease, required this.percent, this.explanation});

  final Disease disease;
  final double percent;        // 0-100; the API gives one decimal (e.g. 70.4, 0.2)
  final String? explanation;   // deep checks: the API's notes + disclaimer

  RiskLevel get level => RiskLevel.fromPercent(percent);

  /// "50" for 50.0, "70.4" for 70.4: whole numbers without ".0", like the mockups.
  String get percentText =>
      percent == percent.roundToDouble() ? '${percent.toInt()}' : percent.toStringAsFixed(1);
}
