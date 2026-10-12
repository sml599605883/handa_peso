import 'package:flutter/widgets.dart';

/// 将设计稿数值从 375dp 参考画布等比缩放到当前设备。
///
/// 在保持设计交付稿像素级间距/字体的同时，避免魔法缩放系数散落在
/// 各个 widget 树中。
abstract final class ScreenAdapter {
  static const double designWidth = 375;
  static const double designHeight = 812;
  static const double _maxScale = 1.35;

  static double? _scale;

  static bool get isInitialized => _scale != null;

  static void init(BuildContext context) => initForSize(MediaQuery.sizeOf(context));

  static void initForSize(Size size) {
    _scale = (size.width / designWidth).clamp(0.85, _maxScale);
  }

  static double width(num designValue) => designValue * _requireScale();

  static double height(num designValue) => designValue * _requireScale();

  static double font(num designValue) => width(designValue);

  static void resetForTest() => _scale = null;

  static double _requireScale() {
    final scale = _scale;
    if (scale == null) {
      throw StateError('ScreenAdapter must be initialised before use.');
    }
    return scale;
  }
}
