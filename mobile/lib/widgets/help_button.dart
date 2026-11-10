// The small grey (?) next to a field label, e.g.  "Resting BP (?)".
// Tapping it opens the guide that explains how to get that reading.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class HelpButton extends StatelessWidget {
  const HelpButton({super.key, required this.onTap, this.tooltip = 'How to get this reading'});

  final VoidCallback onTap;
  final String tooltip; // shown on long-press, and read out by screen readers

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      // InkResponse = a round tap ripple, larger than the small icon itself,
      // so it is easy to hit with a finger.
      child: InkResponse(
        onTap: onTap,
        radius: 18,
        child: const Padding(
          padding: EdgeInsets.all(4),
          child: Icon(Icons.help_outline, size: 17, color: AppColors.hint),
        ),
      ),
    );
  }
}
