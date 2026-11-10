// =============================================================================
// ONE HEALTH GUIDE (Tutorial section, task U5) - no mockup in Section 3.5.4
//
//   <-
//   (icon)
//   Measuring your blood pressure           <- serif title
//   [ Helps with: Resting BP ]              <- grey chip
//   [        > video placeholder        ]   <- 16:9 box
//   Before you measure                      <- section heading
//   • No coffee, exercise or smoking...     <- bullets / paragraph
//   ...
//   General health information, not medical advice.
//
// Everything shown comes from assets/tutorials.json (models/tutorial.dart).
// =============================================================================
import 'package:flutter/material.dart';

import '../models/tutorial.dart';
import '../theme/app_theme.dart';
import '../widgets/app_back_button.dart';
import '../widgets/phone_width.dart';

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, required this.topic});

  final TutorialTopic topic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PhoneWidth(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            children: [
              const Align(alignment: Alignment.centerLeft, child: AppBackButton()),
              CircleAvatar(
                radius: 26,
                backgroundColor: AppColors.mintCard,
                child: Icon(topic.icon, color: AppColors.green, size: 28),
              ),
              const SizedBox(height: 12),
              Text(topic.title, style: AppFonts.serif(size: 26)),
              const SizedBox(height: 8),
              if (topic.usedFor.isNotEmpty) _UsedForChip(text: topic.usedFor),
              const SizedBox(height: 20),

              if (topic.video != null) ...[
                _VideoBox(video: topic.video!),
                const SizedBox(height: 24),
              ],

              for (final section in topic.sections) _Section(section: section),

              const SizedBox(height: 8),
              Text('General health information, not medical advice. '
                  'Ask a doctor or pharmacist about your own readings.',
                  style: AppFonts.body(size: 12, color: AppColors.hint)),
            ],
          ),
        ),
      ),
    );
  }
}

/// "Helps with: Resting BP (Heart deep check)" in a small grey rounded box.
class _UsedForChip extends StatelessWidget {
  const _UsedForChip({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.segmentTrack,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('Helps with: $text', style: AppFonts.body(size: 12)),
      ),
    );
  }
}

/// The video area. No video recorded yet (url is null) -> a placeholder.
///
/// To play real videos later: put a link in "url" in tutorials.json, add the
/// url_launcher package (flutter pub add url_launcher) and open it with
/// launchUrl(Uri.parse(video.url!)) when this box is tapped.
class _VideoBox extends StatelessWidget {
  const _VideoBox({required this.video});
  final TutorialVideo video;

  @override
  Widget build(BuildContext context) {
    final hasLink = video.url != null;

    // AspectRatio keeps the box 16:9 (like a video) at any screen width.
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        key: const Key('videoPlaceholder'),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(colors: [Color(0xFF2F5D3A), AppColors.green]),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_outline, color: Colors.white70, size: 56),
            const SizedBox(height: 8),
            Text(video.title,
                textAlign: TextAlign.center,
                style: AppFonts.body(size: 14, weight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 4),
            Text(hasLink ? video.url! : 'Video coming soon',
                textAlign: TextAlign.center,
                style: AppFonts.body(size: 12, color: Colors.white70)),
          ],
        ),
      ),
    );
  }
}

/// A heading, then the paragraph and/or the bullet points.
class _Section extends StatelessWidget {
  const _Section({required this.section});
  final TutorialSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.heading, style: AppFonts.body(size: 16, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          if (section.text != null)
            Text(section.text!, style: AppFonts.body(size: 14, color: Colors.black87)),
          for (final bullet in section.bullets)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              // The dot and the text in a Row, so a long bullet wraps under its
              // own text instead of under the dot.
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: AppFonts.body(size: 14)),
                  Expanded(child: Text(bullet, style: AppFonts.body(size: 14, color: Colors.black87))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
