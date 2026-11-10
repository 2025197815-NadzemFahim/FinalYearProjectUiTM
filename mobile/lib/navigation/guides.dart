// Opening one Health guide by its id (assets/tutorials.json), from anywhere:
// the (?) icons next to form fields, the banners and cards on Main.
//
//   openGuide(context, services, Guides.bloodPressure);
import 'package:flutter/material.dart';

import '../screens/guide_screen.dart';
import '../services/app_services.dart';

export '../models/tutorial.dart' show Guides; // so callers get the ids with openGuide

Future<void> openGuide(BuildContext context, AppServices services, String id) async {
  final topic = await services.tutorials.topic(id);
  if (!context.mounted) return;

  if (topic == null) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('This guide is not available.')));
    return;
  }
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => GuideScreen(topic: topic)));
}
