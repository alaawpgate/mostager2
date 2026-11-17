import 'package:flutter/material.dart';

/// الهوية البصرية الرسمية لنظام مُستأجِر
class AppColors {
  // Primary Teal Palette
  static const Color primary = Color(0xFF0D9488);
  static const Color primaryDark = Color(0xFF0F766E);
  static const Color primaryLight = Color(0xFF14B8A6);
  static const Color primarySurface = Color(0xFFCCFBF1);

  // Dark Navy & Slate (Sidebar & Luxury Dark Themes)
  static const Color bgDark = Color(0xFF0B1324);
  static const Color bgDarkCard = Color(0xFF111C35);
  static const Color bgDarkSurface = Color(0xFF1E293B);

  // Light Canvas Palette
  static const Color bgLight = Color(0xFFF8FAFC);
  static const Color cardLight = Colors.white;
  static const Color borderLight = Color(0xFFE2E8F0);

  // Aliases for convenience
  static const Color background = bgLight;
  static const Color border = borderLight;
  static const Color secondary = bgDarkCard;

  // Typography Colors
  static const Color textMain = Color(0xFF0F172A);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textLight = Colors.white;

  // Status & Accent Colors
  static const Color success = Color(0xFF10B981);
  static const Color successSurface = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningSurface = Color(0xFFFEF3C7);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerSurface = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF06B6D4);
  static const Color infoSurface = Color(0xFFCFFAFE);
  static const Color whatsApp = Color(0xFF25D366);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF0D9488), Color(0xFF0F766E)],
    begin: Alignment.topRight,
    end: Alignment.bottomLeft,
  );

  static const LinearGradient darkHeaderGradient = LinearGradient(
    colors: [Color(0xFF0B1324), Color(0xFF111C35)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
