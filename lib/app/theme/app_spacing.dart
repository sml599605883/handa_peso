/// Spacing and radius tokens.
///
/// The design system is built on an 8dp grid; every value here is a multiple of
/// 8 so layouts stay visually consistent across screens.
abstract final class AppSpacing {
  /// Optical hairline used only to nudge icon/text baselines.
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 40;
  static const double xxl = 56;

  static const double screenPadding = sm;
  static const double cardPadding = sm;
}

abstract final class AppRadius {
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double pill = 999;
}
