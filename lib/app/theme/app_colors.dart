import 'package:flutter/material.dart';

/// 品牌与语义化颜色令牌。
///
/// widget 必须引用这些令牌，而不是硬编码的十六进制色值，
/// 这样品牌换肤或深色模式改造只需改动单个文件。
abstract final class AppColors {
  // 品牌色
  static const primary = Color(0xFF0F7B6C);
  static const primaryDark = Color(0xFF0A5A4F);
  static const primarySoft = Color(0xFFE3F3F0);
  static const accent = Color(0xFFF2A93B);
  static const accentSoft = Color(0xFFFDF1DD);

  // 表面色
  static const surface = Color(0xFFFFFFFF);
  static const surfaceMuted = Color(0xFFF4F7F6);

  /// 页面级背景渐变（设计稿 06-01）。顶部为鲑鱼色头部色调，中部是奶油色
  /// 平台区，底部再回暖为桃色。
  static const pageBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFF09D87),
      Color(0xFFFEE9C3),
      Color(0xFFFEE9C3),
      Color(0xFFF7C5A7),
    ],
    stops: [0, 0.56, 0.86, 1],
  );
  static const divider = Color(0xFFE6ECEA);
  static const border = Color(0xFFD8E2DF);

  // 文字
  static const textStrong = Color(0xFF10201C);
  static const textPrimary = Color(0xFF2B3A36);
  static const textSecondary = Color(0xFF66756F);
  static const textMuted = Color(0xFF9BA8A4);
  static const textOnPrimary = Color(0xFFFFFFFF);
  static const onPrimaryMuted = Color(0xCCFFFFFF);
  static const onPrimaryOverlay = Color(0x33FFFFFF);

  // 状态
  static const success = Color(0xFF1B9C6B);
  static const warning = Color(0xFFE08A1E);
  static const danger = Color(0xFFE0483C);
  static const info = Color(0xFF2F80ED);

  // 底部导航（设计稿 02-01 tabbar）
  static const tabActive = Color(0xFF7F4209);
  static const tabInactive = Color(0xFF716F5F);

  // 首页主借款卡片（设计稿 02-01）
  static const heroLabel = Color(0xFF716F5F);
  static const heroValue = Color(0xFF151200);
  static const heroDivider = Color(0xFFC2B5A3);
  static const heroCaption = Color(0xFFA55826);

  /// 应用于深色卡片面板上金额的银色渐变。
  static const heroAmountGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFDACECB), Color(0xFFFEFCFD), Color(0xFFD1C2BE)],
    stops: [0, 0.44, 1],
  );
  static const heroAmountShadow = Color(0xFF201100);

  // 效果
  static const shadow = Color(0x140F2B25);
  static const barrier = Color(0x66000000);

  // 渐变
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, primaryDark],
  );
}
