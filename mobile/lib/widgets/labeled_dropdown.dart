// The square-cornered drop-downs from the mockups: "Smoking Status",
// "General Health Self Rating", "Chest Pain Type". Serif label above,
// thin grey border, small arrow on the right.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class LabeledDropdown extends StatelessWidget {
  const LabeledDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start, // left-align label and box
      children: [
        Text(label, style: AppFonts.serif(size: 15)),
        const SizedBox(height: 8),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider, width: 1.2), // thin grey border
            borderRadius: BorderRadius.circular(2),                   // almost square corners
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.hint),
              style: AppFonts.body(size: 14, color: AppColors.hint),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) {
                if (v != null) onChanged(v);
              },
            ),
          ),
        ),
      ],
    );
  }
}
