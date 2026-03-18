import 'package:flutter/material.dart';

class AppColors {
  // ── Brand (same in both modes) ─────────────────
  static const cherry   = Color(0xFF9B1B42);
  static const cherryBg = Color(0xFFFFEEF2);
  static const green    = Color(0xFF4CAF50);
  static const white    = Color(0xFFFFFFFF);

  // ── Semantic (mode-aware) ──────────────────────
  static Color bg(BuildContext context) =>
      _dark(context) ? const Color(0xFF121212) : const Color(0xFFEEEEF3);

  static Color card(BuildContext context) =>
      _dark(context) ? const Color(0xFF1E1E1E) : const Color(0xFFFFFFFF);

  static Color cardAlt(BuildContext context) =>
      _dark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F8);

  static Color text(BuildContext context) =>
      _dark(context) ? const Color(0xFFFFFFFF) : const Color(0xFF1A1A1A);

  static Color subtext(BuildContext context) =>
      _dark(context) ? Colors.grey.shade400 : Colors.grey.shade600;

  static Color divider(BuildContext context) =>
      _dark(context) ? Colors.grey.shade800 : Colors.grey.shade100;

  static Color inputFill(BuildContext context) =>
      _dark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);

  static bool _dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}