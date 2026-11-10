// The plain black "<-" arrow at the top-left of Forgot Password, the Quick
// Prediction screens and the Deep-Check Input screen.
import 'package:flutter/material.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Back',
      icon: const Icon(Icons.arrow_back, size: 30, color: Colors.black),
      // Navigator.pop closes the current screen and shows the one underneath.
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}
