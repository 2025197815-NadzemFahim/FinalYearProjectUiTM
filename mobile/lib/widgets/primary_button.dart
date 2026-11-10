// The green button used on almost every mockup:
// LOG IN, Create Account, Reset Password, Check, Deep Check.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.width = 166,    // most mockup buttons are about this wide
    this.height = 48,
    this.uppercase = false,
    this.fontSize = 15,
  });

  final String label;
  final VoidCallback? onPressed; // the function that runs on tap (null = disabled)
  final bool loading;            // shows a spinner instead of the label
  final double width;
  final double height;
  final bool uppercase;          // "LOG IN" is all caps in the mockup
  final double fontSize;         // label text size

  @override
  Widget build(BuildContext context) {
    // SizedBox fixes the button's size. Change width/height to resize it.
    return SizedBox(
      width: width,
      height: height,
      child: FilledButton(
        // While loading, pass null so the button is disabled (no double taps).
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.green,            // button colour
          foregroundColor: Colors.white,                // text colour
          disabledBackgroundColor: AppColors.green.withValues(alpha: 0.6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), // corner roundness
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
              )
            // FittedBox shrinks the label if the button is too narrow for it,
            // so it never wraps onto a second line.
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  uppercase ? label.toUpperCase() : label,
                  maxLines: 1,
                  style: AppFonts.body(size: fontSize, weight: FontWeight.w600, color: Colors.white),
                ),
              ),
      ),
    );
  }
}
