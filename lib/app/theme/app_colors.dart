import 'package:flutter/material.dart';

/// Brand and semantic colour tokens.
///
/// Widgets must reference these tokens instead of hard-coded hex values so a
/// rebrand or dark-mode pass is a single-file change.
abstract final class AppColors {
  // Brand
  static const primary = Color(0xFF0F7B6C);
  static const primaryDark = Color(0xFF0A5A4F);
  static const primarySoft = Color(0xFFE3F3F0);
  static const accent = Color(0xFFF2A93B);
  static const accentSoft = Color(0xFFFDF1DD);

  // Surfaces
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF4F7F6);
  static const pageBackground = Color(0xFFF4F7F6);
  static const divider = Color(0xFFE6ECEA);
  static const border = Color(0xFFD8E2DF);

  // Text
  static const textStrong = Color(0xFF10201C);
  static const textPrimary = Color(0xFF2B3A36);
  static const textSecondary = Color(0xFF66756F);
  static const textMuted = Color(0xFF9BA8A4);
  static const textOnPrimary = Color(0xFFFFFFFF);
  static const onPrimaryMuted = Color(0xCCFFFFFF);
  static const onPrimaryOverlay = Color(0x33FFFFFF);

  // Status
  static const success = Color(0xFF1B9C6B);
  static const warning = Color(0xFFE08A1E);
  static const danger = Color(0xFFE0483C);
  static const info = Color(0xFF2F80ED);

  // Bottom navigation (design 02-01 tabbar)
  static const tabActive = Color(0xFF7F4209);
  static const tabInactive = Color(0xFF716F5F);

  // Effects
  static const shadow = Color(0x140F2B25);
  static const barrier = Color(0x66000000);

  // Gradients
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
}
