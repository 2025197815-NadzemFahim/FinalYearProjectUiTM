// The error popup required by the use cases' "exception flow" (e.g. wrong
// password, no connection, the database refused a save).
//
//   Login failed
//   Incorrect email or password.
//                              OK
//
// `await` it to wait until the user presses OK.
import 'package:flutter/material.dart';

Future<void> showErrorDialog(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK')),
      ],
    ),
  );
}
