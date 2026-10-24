// The YES/NO radio table from the Quick Prediction and Deep-Check mockups:
//                                      NO   YES
//   High Blood Pressure?               ( )  (o)
//   High Cholesterol?                  ( )  (o)
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class YesNoTable extends StatelessWidget {
  const YesNoTable({super.key, required this.answers, required this.onChanged});

  /// Question -> current answer (true = YES). The parent screen owns this map.
  final Map<String, bool> answers;
  /// Called with (question, newAnswer) when a radio is tapped.
  final void Function(String question, bool value) onChanged;

  static const double _answerColumnWidth = 56; // width of the NO and YES columns

  @override
  Widget build(BuildContext context) {
    final header = AppFonts.serif(size: 15);
    return Column(
      children: [
        // Header row: empty space on the left, then "NO" and "YES".
        Row(
          children: [
            const Spacer(), // Spacer pushes the next widgets to the right
            SizedBox(width: _answerColumnWidth, child: Center(child: Text('NO', style: header))),
            SizedBox(width: _answerColumnWidth, child: Center(child: Text('YES', style: header))),
          ],
        ),
        // One row per question. "for ... in" inside a list repeats the widget.
        for (final question in answers.keys)
          // RadioGroup gives both radios in the row a shared value: picking one
          // un-picks the other.
          RadioGroup<bool>(
            groupValue: answers[question],
            onChanged: (v) {
              if (v != null) onChanged(question, v);
            },
            child: Row(
              children: [
                Expanded(child: Text(question, style: AppFonts.serif(size: 15))),
                const SizedBox(
                  width: _answerColumnWidth,
                  child: Radio<bool>(value: false),
                ),
                const SizedBox(
                  width: _answerColumnWidth,
                  child: Radio<bool>(value: true),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
