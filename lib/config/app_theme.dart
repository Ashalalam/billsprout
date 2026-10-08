import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// BillSprout Design System
/// ─────────────────────────────────────────────────────────────────────────
/// Fonts:
///   Headings / Titles  → Poppins  (rounded, confident, healthcare-friendly)
///   Body / Labels      → Nunito   (open, warm, highly legible at small sizes)
///
/// Type scale (sp):
///   displayLarge   28  page-level hero titles
///   headlineMedium 22  section headers
///   headlineSmall  18  sub-section headers
///   titleLarge     16  card/dialog titles
///   titleMedium    14  list item primaries, labels
///   titleSmall     13  secondary labels
///   bodyLarge      15  regular body text
///   bodyMedium     13  secondary body, descriptions
///   bodySmall      12  captions, table cells
///   labelLarge     14  button text
///   labelMedium    12  chip labels, badges
///   labelSmall     11  micro labels, hints
/// ─────────────────────────────────────────────────────────────────────────
class AppTheme {
  // ── Brand colours ─────────────────────────────────────────────────────────
  static const Color primaryBlue    = Color(0xFF182B68);
  static const Color accentOrange   = Color(0xFFF57C00);
  static const Color lightBackground= Color(0xFFF4F6FA);
  static const Color cardSurface    = Colors.white;
  static const Color textDark       = Color(0xFF1A1A2E);
  static const Color textMuted      = Color(0xFF6B7280);
  static const Color successGreen   = Color(0xFF16A34A);
  static const Color warningAmber   = Color(0xFFD97706);
  static const Color errorRed       = Color(0xFFDC2626);
  static const Color dividerColor   = Color(0xFFE5E7EB);

  // ── Font helpers ───────────────────────────────────────────────────────────
  static TextStyle _poppins({
    required double size,
    FontWeight weight = FontWeight.w600,
    Color color = textDark,
    double height = 1.3,
  }) =>
      GoogleFonts.poppins(
          fontSize: size, fontWeight: weight, color: color, height: height);

  static TextStyle _nunito({
    required double size,
    FontWeight weight = FontWeight.w400,
    Color color = textDark,
    double height = 1.5,
  }) =>
      GoogleFonts.nunito(
          fontSize: size, fontWeight: weight, color: color, height: height);

  // ── Full TextTheme ─────────────────────────────────────────────────────────
  static TextTheme get _textTheme => TextTheme(
        // ── Display ──
        displayLarge:  _poppins(size: 28, weight: FontWeight.w700),
        displayMedium: _poppins(size: 24, weight: FontWeight.w700),
        displaySmall:  _poppins(size: 20, weight: FontWeight.w700),

        // ── Headlines ──
        headlineLarge:  _poppins(size: 22, weight: FontWeight.w700),
        headlineMedium: _poppins(size: 20, weight: FontWeight.w600),
        headlineSmall:  _poppins(size: 18, weight: FontWeight.w600),

        // ── Titles ──
        titleLarge:  _poppins(size: 16, weight: FontWeight.w600),
        titleMedium: _nunito(size: 14, weight: FontWeight.w700),
        titleSmall:  _nunito(size: 13, weight: FontWeight.w600),

        // ── Body ──
        bodyLarge:   _nunito(size: 15, weight: FontWeight.w400),
        bodyMedium:  _nunito(size: 13, weight: FontWeight.w400),
        bodySmall:   _nunito(size: 12, weight: FontWeight.w400, color: textMuted),

        // ── Labels ──
        labelLarge:  _nunito(size: 14, weight: FontWeight.w700),
        labelMedium: _nunito(size: 12, weight: FontWeight.w600),
        labelSmall:  _nunito(size: 11, weight: FontWeight.w500, color: textMuted),
      );

  // ── Main theme ─────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary:   primaryBlue,
        secondary: accentOrange,
        surface:   cardSurface,
        error:     errorRed,
      ),
      scaffoldBackgroundColor: lightBackground,
      textTheme: _textTheme,
    );

    return base.copyWith(
      // ── AppBar ──────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: _poppins(
          size: 16,
          weight: FontWeight.w700,
          color: Colors.white,
        ),
        toolbarHeight: 60,
      ),

      // ── Cards ───────────────────────────────────────────────────────────
      // cardTheme: CardThemeData(
      //   color: cardSurface,
      //   elevation: 1,
      //   shadowColor: Colors.black.withOpacity(0.06),
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.circular(14),
      //     side: const BorderSide(color: Color(0xFFE5E7EB), width: 0.8),
      //   ),
      // ),

      // ── Elevated buttons ─────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),

      // ── Outlined buttons ─────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryBlue,
          side: const BorderSide(color: primaryBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Text buttons ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryBlue,
          textStyle: GoogleFonts.nunito(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),

      // ── Input fields ──────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: textMuted,
        ),
        hintStyle: GoogleFonts.nunito(
          fontSize: 13,
          color: const Color(0xFFBCC0C9),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: errorRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: errorRed, width: 2),
        ),
      ),

      // ── Chips ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        labelStyle: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // ── Bottom navigation ─────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: primaryBlue,
        unselectedItemColor: textMuted,
        selectedLabelStyle: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),

      // ── Navigation rail ───────────────────────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme:
            const IconThemeData(color: primaryBlue, size: 24),
        unselectedIconTheme:
            const IconThemeData(color: Color(0xFF9CA3AF), size: 22),
        selectedLabelTextStyle: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: primaryBlue,
        ),
        unselectedLabelTextStyle: GoogleFonts.nunito(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textMuted,
        ),
        labelType: NavigationRailLabelType.all,
      ),

      // ── Tab bar ───────────────────────────────────────────────────────────
      // tabBarTheme: TabBarThemeData(
      //   labelStyle: GoogleFonts.nunito(
      //     fontSize: 13,
      //     fontWeight: FontWeight.w700,
      //   ),
      //   unselectedLabelStyle: GoogleFonts.nunito(
      //     fontSize: 13,
      //     fontWeight: FontWeight.w500,
      //   ),
      //   labelColor: primaryBlue,
      //   unselectedLabelColor: textMuted,
      //   indicatorColor: primaryBlue,
      //   indicatorSize: TabBarIndicatorSize.tab,
      //   dividerColor: dividerColor,
      // ),

      // ── Snackbar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        contentTextStyle: GoogleFonts.nunito(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      // dialogTheme: DialogThemeData(
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.circular(16),
      //   ),
      //   titleTextStyle: GoogleFonts.poppins(
      //     fontSize: 17,
      //     fontWeight: FontWeight.w700,
      //     color: textDark,
      //   ),
      //   contentTextStyle: GoogleFonts.nunito(
      //     fontSize: 14,
      //     fontWeight: FontWeight.w400,
      //     color: textDark,
      //     height: 1.5,
      //   ),
      //   elevation: 4,
      // ),

      // ── List tiles ────────────────────────────────────────────────────────
      listTileTheme: ListTileThemeData(
        titleTextStyle: GoogleFonts.nunito(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: textDark,
        ),
        subtitleTextStyle: GoogleFonts.nunito(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: textMuted,
          height: 1.4,
        ),
      ),

      // ── Drawer ────────────────────────────────────────────────────────────
      drawerTheme: const DrawerThemeData(
        backgroundColor: Colors.white,
        elevation: 4,
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E7EB),
        thickness: 0.8,
        space: 1,
      ),
    );
  }
}
