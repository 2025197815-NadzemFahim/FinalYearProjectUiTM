// A question with tappable answers, used by My details, Medical history and the
// Lifestyle check:
//
//   Do you smoke cigarettes now?
//   ( Yes ) ( No )                      <- short answers: chips side by side
//
//   Highest education completed
//   ( ) No formal schooling             <- long answers: one per line
//   (o) SPM (completed Form 5)
//
// It is a FormField, so Form.validate() shows "Please choose an answer" under any
// unanswered question, just like the number boxes. <T> is the answer type
// (bool, an enum, ...): the widget works for any of them.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ChoiceQuestionField<T> extends FormField<T> {
  ChoiceQuestionField({
    super.key,
    required String question,
    required List<(T, String)> options, // (value, label shown)
    required ValueChanged<T> onChanged,
    super.initialValue,
    String? hint,                        // small grey explanation under the question
  }) : super(
          validator: (v) => v == null ? 'Please choose an answer' : null,
          builder: (state) {
            final long = options.any((o) => o.$2.length > 18);
            void pick(T v) {
              state.didChange(v); // updates the field AND clears its error
              onChanged(v);
            }

            final selectedColor = AppColors.green.withValues(alpha: 0.15);
            return Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(question, style: AppFonts.body(size: 15, weight: FontWeight.w600)),
                  if (hint != null) ...[
                    const SizedBox(height: 2),
                    Text(hint, style: AppFonts.body(size: 12, color: AppColors.hint)),
                  ],
                  const SizedBox(height: 8),
                  if (long)
                    // One option per line, so long Malaysian labels stay readable.
                    for (final (value, label) in options)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: state.value == value ? selectedColor : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                            side: BorderSide(
                                color: state.value == value ? AppColors.green : AppColors.divider),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => pick(value),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              child: Row(children: [
                                Icon(state.value == value
                                        ? Icons.radio_button_checked
                                        : Icons.radio_button_unchecked,
                                    size: 20,
                                    color: state.value == value ? AppColors.green : AppColors.hint),
                                const SizedBox(width: 10),
                                Expanded(child: Text(label, style: AppFonts.body(size: 14))),
                              ]),
                            ),
                          ),
                        ),
                      )
                  else
                    // Short answers: chips side by side (Wrap moves to a new line if needed).
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      for (final (value, label) in options)
                        ChoiceChip(
                          label: Text(label),
                          selected: state.value == value,
                          selectedColor: selectedColor,
                          side: BorderSide(
                              color: state.value == value ? AppColors.green : AppColors.divider),
                          labelStyle: AppFonts.body(size: 14),
                          showCheckmark: false,
                          onSelected: (_) => pick(value),
                        ),
                    ]),
                  if (state.hasError)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(state.errorText!,
                          style: AppFonts.body(size: 12, color: Colors.redAccent)),
                    ),
                ],
              ),
            );
          },
        );
}

/// Yes/No is the most common question, so it gets a shortcut.
List<(bool, String)> get yesNoOptions => const [(true, 'Yes'), (false, 'No')];
