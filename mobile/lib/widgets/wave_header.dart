// The green wave shapes from the Login and Create Account mockups.
//
// CustomPaint + CustomPainter is how Flutter draws free-form shapes:
// you describe a Path (lines and curves) and it is filled with a colour.
// Path coordinates are written as fractions of the box (w * 0.8 = 80% across),
// so the shape stretches to fit any screen width.
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Top-left wave. Login uses the full width; Create Account a smaller one
/// (widthFactor 0.6 = the wave's box is 60% of the screen width).
class WaveHeader extends StatelessWidget {
  const WaveHeader({super.key, this.height = 150, this.widthFactor = 1.0});

  final double height;
  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: FractionallySizedBox(
        widthFactor: widthFactor,
        child: SizedBox(height: height, child: CustomPaint(painter: _TopWavePainter())),
      ),
    );
  }
}

class _TopWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(w * 0.80, 0)                                                   // along the top edge
      ..cubicTo(w * 0.62, h * 0.10, w * 0.55, h * 0.55, w * 0.38, h * 0.80)  // curve down
      ..cubicTo(w * 0.26, h * 0.98, w * 0.10, h * 0.92, 0, h * 0.62)         // back up to the left edge
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false; // shape never changes
}

/// Bottom-left wave on the Create Account mockup.
class BottomCornerWave extends StatelessWidget {
  const BottomCornerWave({super.key, this.width = 130, this.height = 190});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, height: height, child: CustomPaint(painter: _BottomWavePainter()));
  }
}

class _BottomWavePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, 0)                                                      // starts on the left edge
      ..cubicTo(w * 0.35, h * 0.08, w * 0.30, h * 0.40, w * 0.40, h * 0.62)
      ..cubicTo(w * 0.50, h * 0.85, w * 0.85, h * 0.90, w, h)             // sweeps to the bottom
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(path, Paint()..color = AppColors.green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
