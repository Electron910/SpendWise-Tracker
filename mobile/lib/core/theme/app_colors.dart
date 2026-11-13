import 'package:flutter/material.dart';

/// SpendWise Design System Color Tokens
/// Visual Direction:
/// - Deep navy, white, and subtle indigo foundation.
/// - Emerald green for income and positive financial indicators.
/// - Restrained red for expenses and warnings.
class AppColors {
  const AppColors._();

  // Brand Foundation
  static const Color navyPrimary = Color(0xFF0F172A);
  static const Color navySecondary = Color(0xFF1E293B);
  static const Color indigoAccent = Color(0xFF4F46E5);
  static const Color indigoSoft = Color(0xFFEEF2FF);

  // Financial Semantic Colors
  static const Color emeraldIncome = Color(0xFF10B981);
  static const Color emeraldSoft = Color(0xFFD1FAE5);
  static const Color expenseRed = Color(0xFFEF4444);
  static const Color expenseSoft = Color(0xFFFEE2E2);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color warningSoft = Color(0xFFFEF3C7);

  // Light Theme Surfaces
  static const Color lightBackground = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // Dark Theme Surfaces
  static const Color darkBackground = Color(0xFF0B1120);
  static const Color darkSurface = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
}

class AppSpacing {
  const AppSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppRadius {
  const AppRadius._();

  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
}
