// =============================================================================
// TUTORIAL (Health guides, task U5): one guide = one topic in
// assets/tutorials.json, e.g. "Measuring your blood pressure".
//
//   TutorialTopic     id, title, summary, icon, usedFor, video, sections
//   TutorialSection   a heading with a paragraph and/or bullet points
//   TutorialVideo     a title + link (no link yet = "coming soon" placeholder)
//
// The text lives in the JSON file, so you can change or add guides without
// touching Dart code. fromJson() turns the JSON into these classes.
// =============================================================================
import 'package:flutter/material.dart';

/// The guide ids the app uses (they must exist in assets/tutorials.json).
/// Names instead of plain text, so a typo is a compile error, not a dead link.
class Guides {
  static const bloodPressure = 'blood-pressure';
  static const weightBmi = 'weight-bmi';
  static const cholesterol = 'cholesterol';
  static const bloodSugar = 'blood-sugar';
  static const stressTest = 'stress-test';
  static const chestPainEcg = 'chest-pain-ecg';
  static const readingResults = 'reading-results';
  static const healthyHabits = 'healthy-habits';
  static const strokeFast = 'stroke-fast';
  static const infections = 'infections';
}

class TutorialTopic {
  const TutorialTopic({
    required this.id,
    required this.title,
    required this.summary,
    required this.icon,
    required this.usedFor,
    required this.sections,
    this.video,
  });

  final String id;          // "blood-pressure": used by help icons and banners
  final String title;
  final String summary;     // one line, shown in the list
  final IconData icon;
  final String usedFor;     // which fields of the app this guide helps with
  final List<TutorialSection> sections;
  final TutorialVideo? video;

  /// The icon names the JSON may use. (Flutter needs every icon written in the
  /// code, so it can't look one up from any text.) Add a name here to use it.
  static const icons = <String, IconData>{
    'bloodPressure': Icons.speed,
    'bloodSugar': Icons.bloodtype,
    'brain': Icons.psychology,
    'ecg': Icons.monitor_heart,
    'heart': Icons.favorite,
    'lab': Icons.science,
    'results': Icons.insights,
    'scale': Icons.monitor_weight,
    'shield': Icons.health_and_safety,
    'treadmill': Icons.directions_run,
  };

  factory TutorialTopic.fromJson(Map<String, dynamic> json) {
    final video = json['video'];
    return TutorialTopic(
      id: json['id'] as String,
      title: json['title'] as String,
      summary: json['summary'] as String? ?? '',
      icon: icons[json['icon']] ?? Icons.menu_book, // unknown name -> a book
      usedFor: json['usedFor'] as String? ?? '',
      video: video is Map<String, dynamic> ? TutorialVideo.fromJson(video) : null,
      sections: [
        for (final s in json['sections'] as List? ?? const [])
          TutorialSection.fromJson(s as Map<String, dynamic>),
      ],
    );
  }
}

class TutorialSection {
  const TutorialSection({required this.heading, this.text, this.bullets = const []});

  final String heading;
  final String? text;          // a paragraph (optional)
  final List<String> bullets;  // bullet points (optional)

  factory TutorialSection.fromJson(Map<String, dynamic> json) {
    return TutorialSection(
      heading: json['heading'] as String? ?? '',
      text: json['text'] as String?,
      bullets: [for (final b in json['bullets'] as List? ?? const []) '$b'],
    );
  }
}

class TutorialVideo {
  const TutorialVideo({required this.title, this.url});

  final String title;
  final String? url; // null = not recorded yet

  factory TutorialVideo.fromJson(Map<String, dynamic> json) {
    return TutorialVideo(title: json['title'] as String? ?? 'Video', url: json['url'] as String?);
  }
}
