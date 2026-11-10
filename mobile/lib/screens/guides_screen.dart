// =============================================================================
// HEALTH GUIDES (Tutorial section, task U5) - no mockup in Section 3.5.4
//
//   <-
//   Health guides                             <- serif title, like My details
//   How to take your readings...              <- grey subtitle
//   | (icon) Measuring your blood pressure > |
//   |        Get a reading you can trust...  |
//   | (icon) Weight, height and BMI        > |
//
// Opened from Profile. The banners on Main and the (?) icons next to form
// fields open one guide directly (navigation/guides.dart).
// =============================================================================
import 'package:flutter/material.dart';

import '../models/tutorial.dart';
import '../services/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/phone_width.dart';
import 'guide_screen.dart';

class GuidesScreen extends StatefulWidget {
  const GuidesScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  // Kept in a variable (not called inside build), so a redraw doesn't load again.
  late Future<List<TutorialTopic>> _topics = widget.services.tutorials.topics();

  void _retry() => setState(() => _topics = widget.services.tutorials.topics());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PhoneWidth(
          // FutureBuilder: draws one thing while loading, another when done.
          child: FutureBuilder<List<TutorialTopic>>(
            future: _topics,
            builder: (context, snapshot) {
              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                children: [
                  const Align(alignment: Alignment.centerLeft, child: AppBackButton()),
                  Text('Health guides', style: AppFonts.serif(size: 30)),
                  const SizedBox(height: 4),
                  Text('How to take your readings, and what your results mean.',
                      style: AppFonts.body(size: 13, color: AppColors.hint)),
                  const SizedBox(height: 24),

                  if (snapshot.hasError)
                    _LoadError(onRetry: _retry)
                  else if (!snapshot.hasData)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else
                    for (final topic in snapshot.data!) ...[
                      _GuideCard(
                        topic: topic,
                        onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => GuideScreen(topic: topic))),
                      ),
                      const SizedBox(height: 12), // space between cards
                    ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One white card: icon in a mint circle, title, one-line summary, chevron.
class _GuideCard extends StatelessWidget {
  const _GuideCard({required this.topic, required this.onTap});

  final TutorialTopic topic;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: AppTheme.softShadow,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: Key('guide-${topic.id}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.mintCard,
                  child: Icon(topic.icon, color: AppColors.green),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(topic.title, style: AppFonts.body(size: 15, weight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(topic.summary, style: AppFonts.body(size: 12, color: AppColors.hint)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shown if the guides file could not be read (should not happen: it is inside the app).
class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.error_outline, size: 48, color: AppColors.riskHigh),
        const SizedBox(height: 12),
        Text('The guides could not be opened.',
            textAlign: TextAlign.center, style: AppFonts.body(size: 14)),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
      ],
    );
  }
}
