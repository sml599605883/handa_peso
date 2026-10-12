/// 间距与圆角令牌。
///
/// 设计系统基于 8dp 网格；此处每个数值都是 8 的倍数，
/// 以保证各页面布局的视觉一致性。
abstract final class AppSpacing {
  /// 仅用于微调图标/文字基线的视觉细线间距。
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
