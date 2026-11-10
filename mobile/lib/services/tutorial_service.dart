// =============================================================================
// TUTORIAL SERVICE: loads the Health guides from assets/tutorials.json.
//
// The file is part of the app (an "asset", listed in pubspec.yaml), so it works
// offline. It is read once, the first time a guide is needed, and then kept.
//
//   topics()        all guides, in the order of the file
//   topic('id')     one guide, or null if there is no guide with that id
// =============================================================================
import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/tutorial.dart';

class TutorialService {
  /// [bundle]: where to read the file from. Leave it out (the app's own assets);
  /// tests can pass a different one.
  TutorialService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/tutorials.json';

  final AssetBundle _bundle;
  Future<List<TutorialTopic>>? _topics; // the loaded guides (null = not loaded yet)

  /// All guides. "??=" = only load the first time; later calls reuse the result.
  Future<List<TutorialTopic>> topics() => _topics ??= _load();

  /// The guide with this [id], e.g. 'blood-pressure' (null if there is none).
  Future<TutorialTopic?> topic(String id) async {
    for (final t in await topics()) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<List<TutorialTopic>> _load() async {
    try {
      final text = await _bundle.loadString(assetPath);
      final json = jsonDecode(text) as Map<String, dynamic>;
      return [
        for (final t in json['topics'] as List) TutorialTopic.fromJson(t as Map<String, dynamic>),
      ];
    } catch (e) {
      _topics = null; // forget the failure, so "Try again" really tries again
      rethrow;
    }
  }
}
