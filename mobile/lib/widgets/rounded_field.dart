// The pill-shaped, shadowed input from the login mockup.
// Reusable: the Create Account and Edit Profile screens can use it too.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

class RoundedField extends StatelessWidget {
  const RoundedField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.validator,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
    this.fieldKey,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;
  final Key? fieldKey;
  final List<TextInputFormatter>? inputFormatters; // e.g. digits only for Age

  @override
  Widget build(BuildContext context) {
    const radius = BorderRadius.all(Radius.circular(28));
    // The shadow sits on a DecoratedBox behind the field; the field itself
    // draws the white pill. Validation errors appear under the pill.
    return Stack(
      children: [
        Container(
          height: 56,
          decoration: const BoxDecoration(
            borderRadius: radius,
            color: Colors.white,
            boxShadow: AppTheme.softShadow,
          ),
        ),
        TextFormField(
          key: fieldKey,
          controller: controller,
          obscureText: obscure,
          validator: validator,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onFieldSubmitted: onSubmitted,
          inputFormatters: inputFormatters,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: AppFonts.body(size: 15, color: AppColors.hint),
            prefixIcon: Icon(icon, color: AppColors.iconGrey, size: 20),
            // The space reserved for the icon (default 48 wide). Smaller = more
            // room for text, so "First name" fits in the half-width boxes.
            prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            suffixIcon: suffix,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            border: const OutlineInputBorder(borderRadius: radius, borderSide: BorderSide.none),
            errorBorder: const OutlineInputBorder(
                borderRadius: radius, borderSide: BorderSide(color: Colors.redAccent)),
            focusedErrorBorder: const OutlineInputBorder(
                borderRadius: radius, borderSide: BorderSide(color: Colors.redAccent, width: 1.5)),
            focusedBorder: const OutlineInputBorder(
                borderRadius: radius, borderSide: BorderSide(color: AppColors.green, width: 1.5)),
          ),
        ),
      ],
    );
  }
}
