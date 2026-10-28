import 'package:flutter/material.dart';

class AdminColors {
  const AdminColors._();

  static const Color bg = Color(0xFFF8F9FA);
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE5E7EB);
  static const Color textPrimary = Color(0xFF2C3E50);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color blue = Color(0xFF1A5276);
  static const Color blue2 = Color(0xFF2E86C1);
  static const Color green = Color(0xFF27AE60);
  static const Color amber = Color(0xFFF39C12);
  static const Color red = Color(0xFFE74C3C);
  static const Color purple = Color(0xFF9B59B6);
}

class AdminText {
  const AdminText._();

  static TextStyle get title => const TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AdminColors.textPrimary,
        height: 1.2,
      );

  static TextStyle get sectionTitle => const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AdminColors.textPrimary,
        height: 1.3,
      );

  static TextStyle get body => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AdminColors.textPrimary,
        height: 1.5,
      );

  static TextStyle get small => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AdminColors.textSecondary,
        height: 1.4,
      );

  static TextStyle get caption => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AdminColors.textSecondary,
        letterSpacing: 0.2,
      );

  static TextStyle get label => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AdminColors.textPrimary,
        letterSpacing: 0.4,
      );

  static TextStyle get button => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AdminColors.textPrimary,
      );
}

class AdminSpace {
  const AdminSpace._();

  static const double xxs = 12;
  static const double sm = 16;
  static const double md = 16;
  static const double lg = 20;
}

class AdminBreakpoints {
  const AdminBreakpoints._();

  static const double mobile = 600;
  static const double tablet = 900;
}
