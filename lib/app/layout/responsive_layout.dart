import 'dart:math' as math;

/// Shared metrics for screens designed on a 375-point content width.
class AppResponsiveMetrics {
  const AppResponsiveMetrics({
    required this.screenWidth,
    required this.safeTop,
    required this.safeBottom,
    this.designHorizontalInset = 14,
    this.maxContentWidth = 480,
  });

  static const double designWidth = 375;

  final double screenWidth;
  final double safeTop;
  final double safeBottom;
  final double designHorizontalInset;
  final double maxContentWidth;

  /// Keep phone controls close to their design size on narrow and wide phones.
  double get scale => (screenWidth / designWidth).clamp(0.85, 1.2);

  double get horizontalInset => designHorizontalInset * scale;

  double get contentWidth =>
      math.min(math.max(0, screenWidth - horizontalInset * 2), maxContentWidth);

  double value(num designValue) => designValue * scale;

  /// Matches the certification design: content begins eight points below the
  /// status bar, but never higher than the original 56-point back-button row.
  double get headerShift => math.max(0, safeTop - value(56) + value(8));
}
