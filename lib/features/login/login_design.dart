import 'package:flutter/widgets.dart';

/// 登录页（设计稿 01-02 - 登录）的坐标与切图。
///
/// 数值都是 375x812 设计画布上的原始值，缩放由 `DesignCanvas` 统一处理，
/// 这里只负责「设计稿上量到多少就写多少」。
abstract final class LoginDesign {
  /// 设计画布尺寸。
  static const Size canvas = Size(375, 812);

  /// 画布对应的状态栏高度（iPhone 13 mini 一档）。
  static const double canvasTopInset = 50;

  /// 返回键：设计稿里是状态栏下方 8pt，且是唯一贴着状态栏的可点元素。
  static const double backLeft = 14;
  static const double backTop = 58;
  static const double backInset = backTop - canvasTopInset;
  static const double backSize = 24;

  /// 卡片切图（含卡片本体、缎带、回形针、闪电）。
  ///
  /// 切图是 @3x 导出的，导出原点落在 682（不能被 3 整除）上；按整数设计坐标
  /// 摆放会把整块位图重采样、发虚，所以这里直接按切图的 @3x 网格给坐标，
  /// 在 375x812 的三倍屏上与设计稿逐像素对齐。
  static const double cardArtLeft = 36 / 3;
  static const double cardArtTop = 682 / 3;
  static const double cardArtWidth = 349;
  static const double cardArtHeight = 368;

  /// 卡片本体（切图里那块米色圆角矩形）在设计稿里的位置，表单就摆在这里面。
  static const double cardBodyLeft = 14;
  static const double cardBodyTop = 259;
  static const double cardBodyWidth = 347;
  static const double cardBodyHeight = 336;

  /// 缎带上的「APP NAME」文字层。
  static const double appNameLeft = 19;
  static const double appNameTop = 236;
  static const double appNameWidth = 305;
  static const double appNameHeight = 43;

  /// 主按钮。
  static const double submitLeft = 50;
  static const double submitTop = 619;
  static const double submitWidth = 274;
  static const double submitHeight = 52;

  /// 切图资源。
  static const String backgroundAsset = 'assets/login/login_background.png';
  static const String cardAsset = 'assets/login/login_card.png';
  static const String backAsset = 'assets/login/login_back.png';
  static const String checkboxOn = 'assets/login/login_checkbox_checked.png';
  static const String checkboxOff = 'assets/login/login_checkbox_unchecked.png';

  /// 按设计坐标摆放一个元素。
  static Positioned place(
    double left,
    double top,
    double width,
    double height,
    Widget child,
  ) {
    return Positioned(
      left: left,
      top: top,
      width: width,
      height: height,
      child: child,
    );
  }
}
