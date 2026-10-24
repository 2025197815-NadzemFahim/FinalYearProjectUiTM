// The "label above a rounded white box" pattern from the Quick Prediction and
// Deep-Check input mockups, e.g.
//            Age                   Sex
//      [    58     ]          [   Male   ]
//
// Three widgets live here because they share the same look:
//   LabeledNumberBox  - a box you type a number into
//   LabeledChoiceBox  - a box with a small drop-down (Sex)
//   TwoColumnGrid     - lays any boxes out two per row
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// The white rounded "pill" behind every box. Change the look of ALL boxes here.
class _Pill extends StatelessWidget {
  const _Pill({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Container = a box you can size, colour, round and shadow.
    return Container(
      height: 52,                                   // box height
      alignment: Alignment.center,                  // centre the content inside
      padding: const EdgeInsets.symmetric(horizontal: 12), // space inside the box
      decoration: BoxDecoration(
        color: Colors.white,                        // box colour
        borderRadius: BorderRadius.circular(18),    // corner roundness
        boxShadow: AppTheme.softShadow,             // the soft shadow
      ),
      child: child,
    );
  }
}

/// Label + box you type a number into.
class LabeledNumberBox extends StatelessWidget {
  const LabeledNumberBox({
    super.key,
    required this.label,
    required this.controller,
    this.suffix,
    this.decimal = false,
    this.readOnly = false,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? suffix;      // "KG", "CM" - shown after the number
  final bool decimal;        // allow 41.5 (true) or whole numbers only (false)
  final bool readOnly;       // BMI is calculated, not typed
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    // Column stacks its children top to bottom: label, gap, box.
    return Column(
      children: [
        // FittedBox shrinks a long label ("Major Vessel Number") to stay on one line.
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1, style: AppFonts.body(size: 15)),
        ),
        const SizedBox(height: 8), // vertical gap between label and box
        _Pill(
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            onChanged: onChanged,
            textAlign: TextAlign.center,
            style: AppFonts.body(size: 15),
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            // Only allow digits (and one dot if decimal) to be typed.
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(decimal ? r'^\d*\.?\d*' : r'^\d*')),
            ],
            // Field must not be empty when the form is submitted.
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            decoration: InputDecoration(
              border: InputBorder.none,           // the pill already draws the box
              isDense: true,
              suffixText: suffix,
              suffixStyle: AppFonts.body(size: 15),
              errorStyle: const TextStyle(height: 0.8, fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }
}

/// Label + box with a drop-down (used for Sex).
class LabeledChoiceBox extends StatelessWidget {
  const LabeledChoiceBox({
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
      children: [
        Text(label, textAlign: TextAlign.center, style: AppFonts.body(size: 15)),
        const SizedBox(height: 8),
        _Pill(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              alignment: Alignment.center,
              icon: const SizedBox.shrink(), // mockup shows no arrow in this box
              style: AppFonts.body(size: 15),
              // .map turns each option text into a menu item.
              items: options
                  .map((o) => DropdownMenuItem(value: o, alignment: Alignment.center, child: Text(o)))
                  .toList(),
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

/// Places widgets two per row, like the mockup's left and right columns.
/// An odd one out (e.g. BMI) sits alone on the left of the last row.
class TwoColumnGrid extends StatelessWidget {
  const TwoColumnGrid({super.key, required this.children, this.gap = 28, this.rowGap = 18});

  final List<Widget> children;
  final double gap;     // space between the two columns
  final double rowGap;  // space between rows

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      final right = i + 1 < children.length ? children[i + 1] : const SizedBox.shrink();
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expanded = "take an equal share of the row's width".
          Expanded(child: children[i]),
          SizedBox(width: gap),
          Expanded(child: right),
        ],
      ));
      if (i + 2 < children.length) rows.add(SizedBox(height: rowGap));
    }
    return Column(children: rows);
  }
}
