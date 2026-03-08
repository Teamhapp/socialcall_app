import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary brand colors
  static const Color primary = Color(0xFFFF4D79);       // hot pink
  static const Color primaryDark = Color(0xFFE0305A);
  static const Color primaryLight = Color(0xFFFF80A0);

  // Secondary accent
  static const Color accent = Color(0xFFFF8C42);        // warm orange
  static const Color accentLight = Color(0xFFFFB07A);

  // Backgrounds
  static const Color background = Color(0xFF0F0F1A);    // deep dark purple
  static const Color surface = Color(0xFF1A1A2E);
  static const Color card = Color(0xFF22223A);
  static const Color cardLight = Color(0xFF2A2A45);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B0C8);
  static const Color textHint = Color(0xFF6B6B8A);

  // Status colors
  static const Color online = Color(0xFF2ECC71);
  static const Color offline = Color(0xFF95A5A6);
  static const Color busy = Color(0xFFE74C3C);
  static const Color warning = Color(0xFFF39C12);

  // Call colors
  static const Color callGreen = Color(0xFF27AE60);
  static const Color callRed = Color(0xFFE74C3C);

  // Wallet / money
  static const Color gold = Color(0xFFFFD700);
  static const Color goldLight = Color(0xFFFFF3CD);

  // Divider / border
  static const Color border = Color(0xFF2E2E50);
  static const Color divider = Color(0xFF1E1E38);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFF4D79), Color(0xFFFF8C42)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [Color(0xFF0F0F1A), Color(0xFF1A1A2E)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF22223A), Color(0xFF1A1A2E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient hostCardGradient = LinearGradient(
    colors: [Colors.transparent, Color(0xCC000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
