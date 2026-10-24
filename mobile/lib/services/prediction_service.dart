// =============================================================================
// PREDICTION SERVICE - DUMMY VERSION
//
// Returns the sample results shown in the mockups so every screen can be tried
// without the AI backend. The screens only call these two functions, so later
// you replace the BODIES with HTTP calls to the FastAPI backend
// (POST /predict/quick and POST /predict/deep/{disease}) and no screen changes.
// =============================================================================
import '../models/disease.dart';

class PredictionService {
  /// Quick Prediction (Model 1). Returns all three diseases, highest risk first
  /// (report Section 1.6: "display the list ... highest to the lowest").
  Future<List<RiskResult>> quickPredict(Map<String, Object> answers) async {
    await Future.delayed(const Duration(milliseconds: 600)); // pretend network delay
    final results = [
      // Sample values from Figure 3.20
      const RiskResult(disease: Disease.heart, percent: 50),
      const RiskResult(disease: Disease.diabetes, percent: 40),
      const RiskResult(disease: Disease.stroke, percent: 20),
    ];
    results.sort((a, b) => b.percent.compareTo(a.percent)); // highest first
    return results;
  }

  /// Deep Check (Model 2) for one disease.
  Future<RiskResult> deepCheck(Disease disease, Map<String, Object> answers) async {
    await Future.delayed(const Duration(milliseconds: 600));
    // Sample values: 80% for heart comes from Figure 3.22; the others are made up.
    final percent = switch (disease) {
      Disease.heart => 80,
      Disease.diabetes => 62,
      Disease.stroke => 35,
    };
    return RiskResult(disease: disease, percent: percent);
  }

  /// Short sentence for the Quick Prediction Result cards (Figure 3.20).
  static String quickSummary(RiskResult r) =>
      'Your responses indicate a ${r.level.word} risk of ${r.disease.label.toLowerCase()}. '
      'Continue to the deep check for a more detailed evaluation.';

  /// Paragraph for the Deep-Check Result screen (Figure 3.22), ending with the
  /// disclaimer the report requires ("a screening estimate, not a diagnosis").
  static String deepExplanation(RiskResult r) =>
      'Based on your deep check responses, the model estimates ${_article(r.percent)} ${r.percent}% '
      'likelihood of elevated ${r.disease.label.toLowerCase()} risk, reflecting patterns '
      'across key indicators such as blood pressure, cholesterol, and lifestyle habits. '
      'This is a screening estimate, not a diagnosis. We recommend consulting a '
      'healthcare professional for further evaluation.';

  /// "an 80%", "an 8%", "an 11%", "an 18%" but "a 50%" (by how the number sounds).
  static String _article(int p) =>
      (p == 8 || p == 11 || p == 18 || (p >= 80 && p <= 89)) ? 'an' : 'a';
}
