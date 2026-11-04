// =============================================================================
// 6. QUICK PREDICTION RESULT INTERFACE (Figure 3.20)
//
//   <-
//   | Heart Disease  50%                 v |   <- opened (highest risk)
//   |   Your responses indicate ...        |
//   |          [ Deep Check ]              |
//   | Diabetes Mellitus  40%             > |   <- closed, tap to open
//   | Stroke  20%                        > |
//
// One ExpandableCard per disease, highest risk first (the service sorts them).
// "Deep Check" opens the Deep-Check Input form for THAT disease (Figure 3.25).
// =============================================================================
import 'package:flutter/material.dart';

import '../models/disease.dart';
import '../navigation/app_tabs.dart';
import '../services/app_services.dart';
import '../services/prediction_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/expandable_card.dart';
import '../widgets/phone_width.dart';
import '../widgets/primary_button.dart';
import 'deep_check_input_screen.dart';

class QuickPredictionResultScreen extends StatelessWidget {
  const QuickPredictionResultScreen({super.key, required this.services, required this.results});

  final AppServices services;
  final List<RiskResult> results;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const AppBottomNav(currentIndex: AppTabs.home),
      body: SafeArea(
        child: PhoneWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              const Align(alignment: Alignment.centerLeft, child: AppBackButton()),
              const SizedBox(height: 40),
              // One card per result. Only the first (highest risk) starts open.
              for (var i = 0; i < results.length; i++)
                ExpandableCard(
                  key: Key('quickResult-${results[i].disease.name}'),
                  title: results[i].disease.label,
                  trailingText: '${results[i].percentText}%',
                  initiallyExpanded: i == 0,
                  child: _CardBody(services: services, result: results[i]),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// What appears inside an opened card: the sentence and the Deep Check button.
class _CardBody extends StatelessWidget {
  const _CardBody({required this.services, required this.result});

  final AppServices services;
  final RiskResult result;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          PredictionService.quickSummary(result),
          textAlign: TextAlign.center,
          style: AppFonts.body(size: 15),
        ),
        const SizedBox(height: 32),
        PrimaryButton(
          key: Key('deepCheck-${result.disease.name}'),
          label: 'Deep Check',
          width: 126,
          fontSize: 14,
          height: 32,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DeepCheckInputScreen(services: services, disease: result.disease),
          )),
        ),
      ],
    );
  }
}
