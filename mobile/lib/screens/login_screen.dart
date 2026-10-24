// =============================================================================
// 1. LOGIN INTERFACE (Figure 3.15) - use case "Login" (Table 3.11)
//
// StatefulWidget because things change while the screen is open: what's typed,
// whether the password is visible, whether we're waiting for Firebase.
// (A StatelessWidget can only draw what it's given; it can't change itself.)
// =============================================================================
import 'package:flutter/material.dart';

import '../services/app_services.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';
import '../widgets/rounded_field.dart';
import '../widgets/wave_header.dart';
import 'create_account_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.services});

  final AppServices services;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // A Form groups fields so they can be validated together (FR-04).
  final _formKey = GlobalKey<FormState>();
  // Controllers hold the text typed into each field.
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _hidePassword = true;
  bool _loading = false;

  @override
  void dispose() {
    // Controllers use memory; release them when the screen closes.
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------- actions
  Future<void> _submit() async {
    if (_loading) return;                              // ignore double taps
    if (!_formKey.currentState!.validate()) return;    // shows the red field errors
    FocusScope.of(context).unfocus();                  // close the keyboard

    setState(() => _loading = true);                   // setState = "change and redraw"
    String? error;
    try {
      await widget.services.auth.signIn(email: _email.text, password: _password.text);
      // On success there is nothing else to do: AuthGate sees the new user and
      // replaces this screen with the Main screen by itself.
    } on AuthFailure catch (e) {
      error = e.message;
    }
    if (!mounted) return;                    // screen already gone (successful login)
    setState(() => _loading = false);        // stop the spinner BEFORE the popup
    if (error != null) await showErrorDialog(context, 'Login failed', error);
  }

  // Navigator.push opens a new screen ON TOP of this one (back arrow returns).
  void _openForgotPassword() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ForgotPasswordScreen(services: widget.services)));

  void _openCreateAccount() => Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CreateAccountScreen(services: widget.services)));

  // ----------------------------------------------------------------- layout
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Stack = layers: the wave behind, the form on top.
      body: Stack(
        children: [
          const WaveHeader(),
          SafeArea( // keeps content clear of the phone's notch / status bar
            child: Center(
              // Scrolls up when the keyboard opens instead of overflowing.
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420), // tidy on tablets/web
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 60),
                          Text('Hello',
                              textAlign: TextAlign.center,
                              style: AppFonts.title(size: 64, color: AppColors.heading)),
                          const SizedBox(height: 12),
                          Text('Sign in to your account',
                              textAlign: TextAlign.center,
                              style: AppFonts.body(size: 18)),
                          const SizedBox(height: 40),
                          RoundedField(
                            fieldKey: const Key('email'),
                            controller: _email,
                            hint: 'E-mail',
                            icon: Icons.email,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            validator: validateEmail,
                          ),
                          const SizedBox(height: 24),
                          RoundedField(
                            fieldKey: const Key('password'),
                            controller: _password,
                            hint: 'Password',
                            icon: Icons.lock,
                            obscure: _hidePassword,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            onSubmitted: (_) => _submit(),   // Enter key logs in
                            validator: (v) =>
                                (v ?? '').isEmpty ? 'Please enter your password.' : null,
                            suffix: PasswordEyeButton(
                              hidden: _hidePassword,
                              onPressed: () => setState(() => _hidePassword = !_hidePassword),
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton(
                              onPressed: _openForgotPassword,
                              child: Text('Forgot your password?',
                                  style: AppFonts.body(size: 14, color: AppColors.hint)),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: PrimaryButton(
                              key: const Key('login'),
                              label: 'Log in',
                              uppercase: true,
                              loading: _loading,
                              onPressed: _submit,
                            ),
                          ),
                          const SizedBox(height: 48),
                          // Wrap = a Row that moves to a new line instead of
                          // overflowing when the screen is very narrow.
                          Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              Text("Don't have an account? ", style: AppFonts.body(size: 14)),
                              GestureDetector( // makes plain text tappable
                                onTap: _openCreateAccount,
                                child: Text('Create',
                                    style: AppFonts.body(size: 14)
                                        .copyWith(decoration: TextDecoration.underline)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Small helpers shared by Login, Create Account and Forgot Password.
// (Top-level functions/classes: any file that imports this one can use them.)
// -----------------------------------------------------------------------------

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Validator for email fields. Returns an error message, or null if OK.
String? validateEmail(String? value) {
  final v = value?.trim() ?? '';
  if (v.isEmpty) return 'Please enter your email.';
  if (!_emailPattern.hasMatch(v)) return 'Please enter a valid email.';
  return null;
}

/// The eye icon that shows/hides a password.
class PasswordEyeButton extends StatelessWidget {
  const PasswordEyeButton({super.key, required this.hidden, required this.onPressed});
  final bool hidden;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: hidden ? 'Show password' : 'Hide password',
      icon: Icon(hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          color: AppColors.iconGrey, size: 20),
      onPressed: onPressed,
    );
  }
}

/// The error popup required by the use cases' "exception flow".
Future<void> showErrorDialog(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('OK'))],
    ),
  );
}
