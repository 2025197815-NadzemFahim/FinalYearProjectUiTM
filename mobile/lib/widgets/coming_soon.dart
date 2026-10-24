// A short message for buttons whose screen has no mockup in Section 3.5.4
// (Edit Profile, My Activity, Settings, Privacy & Security, health articles).
// Tapping them works and tells the user why nothing opens, instead of doing nothing.
import 'package:flutter/material.dart';

void showComingSoon(BuildContext context, String feature) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar() // remove any message already showing
    ..showSnackBar(SnackBar(content: Text('$feature is not designed yet.')));
}
