// =============================================================================
// THEME: every colour, font and shared style used by the screens.
//
// Why one file? If the supervisor asks for a different green, you change ONE
// line here and every screen follows. Screens should say "AppColors.green",
// never "Color(0xFF1FA672)" directly.
// =============================================================================
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours picked from the Figma mockups (Section 3.5.4).
class AppColors {
  // A Color is written as 0xAARRGGBB: AA = opacity (FF = solid), then red, green, blue.
  static const green = Color(0xFF1FA672);        // buttons, waves, header, selected tab
  static const darkGreen = Color(0xFF2F5D3A);    // profile picture ring
  static const heading = Color(0xFF2A1215);      // "Hello" on the login screen
  static const text = Color(0xFF1C1C1C);         // normal text
  static const hint = Color(0xFFA0A0A0);         // placeholders, dates, grey subtitles
  static const iconGrey = Color(0xFF8A8A8A);     // icons inside input fields
  static const divider = Color(0xFFE6E6E6);      // thin lines inside cards
  static const tileIconBg = Color(0xFFE8E8E8);   // grey circle behind profile icons
  static const segmentTrack = Color(0xFFEEEEEE); // Male/Female toggle background
  static const radioBlue = Color(0xFF2F80ED);    // YES/NO radio buttons
  static const lavenderCard = Color(0xFFF4F2FE); // "Predict a Disease" card (Main)
  static const mintCard = Color(0xFFEAF7EE);     // "View Prediction History" card (Main)
  static const background = Colors.white;

  // Risk colours (assumption: the mockup shows 80% in red; lower risks get
  // calmer colours so the user can tell levels apart at a glance).
  static const riskHigh = Color(0xFFEE4A3B);
  static const riskModerate = Color(0xFFF2994A);
  static const riskLow = green;
}

/// Fonts used in the mockups:
///  - Poppins      -> normal UI text (buttons, labels, profile, home)
///  - Young Serif  -> the heavy serif headings ("Forgot Password?", "History",
///                    "Heart Disease", the YES/NO questions, card titles)
///  - Lato         -> the big "Hello" / "Create account" titles
///
/// google_fonts downloads each font the first time it is used (needs internet
/// once), then caches it. Tests switch this off with [useGoogleFonts] = false
/// so they don't need the internet.
class AppFonts {
  static bool useGoogleFonts = true;

  static TextStyle body({double size = 14, FontWeight weight = FontWeight.w400, Color? color}) {
    final style = TextStyle(fontSize: size, fontWeight: weight, color: color ?? AppColors.text);
    return useGoogleFonts ? GoogleFonts.poppins(textStyle: style) : style;
  }

  static TextStyle serif({double size = 16, FontWeight weight = FontWeight.w400, Color? color}) {
    final style = TextStyle(fontSize: size, fontWeight: weight, color: color ?? Colors.black);
    return useGoogleFonts ? GoogleFonts.youngSerif(textStyle: style) : style;
  }

  static TextStyle title({double size = 30, FontWeight weight = FontWeight.w700, Color? color}) {
    final style = TextStyle(fontSize: size, fontWeight: weight, color: color ?? AppColors.text);
    return useGoogleFonts ? GoogleFonts.lato(textStyle: style) : style;
  }
}

/// Shared shapes and shadows.
class AppTheme {
  /// Soft shadow under the rounded fields and cards ("floating" look in the mockups).
  /// blurRadius = how soft the edge is; offset = (x, y) - y: 4 pushes it downwards.
  static const List<BoxShadow> softShadow = [
    BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  /// The app-wide Material theme. Widgets that aren't given a style use these.
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.green, primary: AppColors.green),
      scaffoldBackgroundColor: AppColors.background,
      // Radio buttons: blue like the mockup's YES/NO circles
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? AppColors.radioBlue : AppColors.iconGrey),
      ),
    );
    if (!AppFonts.useGoogleFonts) return base; // tests: keep the built-in font
    // Every Text without its own style uses Poppins. (We pass the font NAME:
    // google_fonts 9 builds its TextTheme from the separate material_ui
    // package, which the Flutter SDK's ThemeData does not accept.)
    final poppins = GoogleFonts.poppins().fontFamily;
    return base.copyWith(textTheme: base.textTheme.apply(fontFamily: poppins));
  }
}
