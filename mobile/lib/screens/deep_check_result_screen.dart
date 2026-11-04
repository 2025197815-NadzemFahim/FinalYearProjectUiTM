// =============================================================================
// 8. DEEP-CHECK RESULT INTERFACE (Figure 3.22)
//
//          ( check mark in a circle )
//                    80%                 <- coloured by risk level
//   | Heart Disease                    v |
//   |  Based on your deep check ...      |   <- explanation + disclaimer
//
// Opened in two ways:
//  - right after a deep check (from the Home tab)  -> tab = AppTabs.home
//  - from a History card                           -> tab = AppTabs.history
// The mockup has no back arrow: use the bottom bar (or the phone's back gesture).
// =============================================================================
import 'package:flutter/material.dart';

import '../models/disease.dart';
import '../navigation/app_tabs.dart';
import '../services/prediction_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/expandable_card.dart';
import '../widgets/phone_width.dart';

class DeepCheckResultScreen extends StatelessWidget {
  const DeepCheckResultScreen({
    super.key,
    required this.result,
    this.explanation,
    this.tab = AppTabs.home,
  });

  final RiskResult result;
  final String? explanation; // null -> build it from the result
  final int tab;             // which bottom-bar icon is green

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: AppBottomNav(currentIndex: tab),
      body: SafeArea(
        child: PhoneWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
            children: [
              // ---- the big circle with the tick
              Center(
                child: Container(
                  width: 175,
                  height: 175,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF2D3748), width: 1.5), // circle line
                  ),
                  child: const Icon(Icons.check, size: 90, color: Color(0xFF2D3748)),
                ),
              ),
              const SizedBox(height: 12),
              // ---- the percentage
              Text(
                '${result.percentText}%',
                key: const Key('deepPercent'),
                textAlign: TextAlign.center,
                // Colour comes from the risk level: red high, orange moderate, green low.
                style: AppFonts.body(size: 64, color: result.level.color),
              ),
              const SizedBox(height: 16),
              ExpandableCard(
                title: result.disease.label,
                initiallyExpanded: true,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Text(
                    explanation ?? result.explanation ?? PredictionService.deepExplanation(result),
                    textAlign: TextAlign.center,
                    style: AppFonts.body(size: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
