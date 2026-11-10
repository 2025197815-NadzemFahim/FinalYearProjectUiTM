// Keeps a screen phone-shaped on wide windows (Chrome, tablets).
//
// On a phone this does nothing visible. In a 1400-pixel-wide browser it stops
// the boxes from stretching across the whole window: the content stays at most
// [maxWidth] wide, centred. Change maxWidth to make every screen wider/narrower.
import 'package:flutter/material.dart';

class PhoneWidth extends StatelessWidget {
  const PhoneWidth({super.key, required this.child, this.maxWidth = 480});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        // "constraints" = the rules a child must follow. Here: never wider than maxWidth.
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
