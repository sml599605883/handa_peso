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

  /// 首页卡片容器（设计稿 02-01 及 02-02）：浅米色面板 + 描边。
  static const homeCardSurface = Color(0xFFFFF0E5);
  static const homeCardBorder = Color(0xFFEBDBCA);

  /// 卡片内深色金额面板的纵向渐变（暗棕 → 亮棕 → 暗棕）。
  static const homeAmountPanelGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF4A2D1F), Color(0xFF6E4A3A), Color(0xFF4C2E20)],
  );

  /// 卡片内的白色条款条与推荐卡片底色。
  static const homeCardRow = Color(0xFFFFF9F2);
  static const homeCardDivider = Color(0xFFEBE7E2);

  /// 「My unlocked limit」票据内的额度筹码。
  static const homeChipSurface = Color(0xFFFDDCC3);
  static const homeChipText = Color(0xFF7F4209);
  static const homeChipLockedSurface = Color(0xFFD9D6D2);
  static const homeChipLockedText = Color(0xFF9B948D);

  /// 已达成额度筹码 / 推荐列表高亮按钮共用的暖橙渐变。
  static const homeWarmGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFFE39149), Color(0xFF9E3E10)],
  );

  /// 分期期数徽标与推荐卡片按钮的状态色。
  static const homePeriodBadge = Color(0xFFA15719);
  static const homePeriodLabel = Color(0xFF716F5F);
  static const homeApplyNormal = Color(0xFFFE4545);
  static const homeApplyDisabled = Color(0xFFBCB7B2);

  /// 推荐卡片头部「More」按钮底色。
  static const homeMoreSurface = Color(0xFFE9D0A4);

  /// 商品 Logo 缺失时的占位方块。
  static const homeLogoPlaceholder = Color(0xFFD8D8D8);
  static const homeLogoPlaceholderBorder = Color(0xFF979797);

  // 借款进度（设计稿 02- 贷款-订单进度）
  /// 进度卡片底板：奶油色面板 + 1px 描边，两侧各切一个票券缺口。
  static const progressCardSurface = Color(0xFFFFF9F2);
  static const progressCardBorder = Color(0xFFEBE7E2);

  /// 卡片里的日期 / 金额数据块。
  static const progressValueSurface = Color(0xFFFFFFFF);
  static const progressValueLabel = Color(0xFF716F5F);
  static const progressValueText = Color(0xFF151200);

  /// 产品 Logo 缺失时的占位方块。
  static const progressLogoSurface = Color(0xFFD8D8D8);
  static const progressLogoBorder = Color(0xFF979797);

  /// 卡片按钮（设计稿 02- 贷款-订单进度）：主按钮是暖橙渐变，次要按钮是灰色。
  /// 卡片里的两枚按钮铺的是同款切片，这里保留色值给空态的 Apply Now 按钮。
  static const progressPrimaryGradient = LinearGradient(
    begin: Alignment.centerRight,
    end: Alignment.centerLeft,
    colors: [Color(0xFFE39149), Color(0xFF9E3E10)],
  );
  static const progressMutedAction = Color(0xFFBCB7B2);

  // 登录页（设计稿 01-02 - 登录）
  /// 表单标签、「+63」右侧的占位提示等次要文字。
  static const loginLabelText = Color(0xFF716F5F);

  /// 输入框内已输入内容。
  static const loginInputText = Color(0xFF151200);

  /// 「+63」与「Get Code」的品牌棕。
  static const loginAccentText = Color(0xFF7F4209);

  /// 「Get Code」按钮底色。
  static const loginCodeButtonSurface = Color(0xFFF3AF95);

  /// 倒计时按钮与不可提交状态主按钮的灰色底。
  static const loginDisabledSurface = Color(0xFFBCB7B2);

  /// 登录页背景的收尾色 #F7C5A7，与整页切图 `login_background.png` 的底边
  /// 同色：比设计稿 375x812 更高的机型，用它在切图下方补齐滚动区域。
  static const loginBackgroundBottom = Color(0xFFF7C5A7);

  /// 提示浮层底色：设计稿里是 64% 黑，叠在任意背景上。（见 `lib/app/widgets/app_hint.dart`）
  static const hintSurface = Color(0xA3000000);

  // 个人中心 / 账号 / 订单列表（设计稿 07-01 个人中心、05-01 订单列表）
  /// 这三页共用的页面底色：顶部鲑鱼色 → 奶油色 → 纯白到底。
  ///
  /// 设计稿画布是 375x812：`0` 处 `#F6BB9F`、`200` 处 `#FEE8C4`、`420` 处已经到
  /// 纯白（画布再往下就是白的）。这三个位置换算成画布比例铺满整页，这样任何
  /// 机型都是「顶部一段暖色、中段就到白」，不会在中间接出一条色带。
  static const accountPageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFF6BB9F), Color(0xFFFEE8C4), Color(0xFFFFFFFF)],
    stops: [0, 0.246, 0.517],
  );

  /// 个人中心头部卡片与设置页主按钮共用的暖橙渐变（设计稿 `矩形`：
  /// 右侧浅橙 → 左侧深棕，2px 白描边）。与首页卡片同款，故与
  /// [homeWarmGradient] 取同一组色值。
  static const accountWarmGradient = homeWarmGradient;

  /// 个人中心快捷入口（All / Outstanding / Settled）的文案色。
  static const accountEntryLabel = Color(0xFF716F5F);

  /// 设置页顶部弧形面板上的应用名（设计稿 `text-wrapper_3`）。
  static const accountCurtainTitle = Color(0xFF011706);

  /// 设置页版本号文案（设计稿 `V1.1.1`）与设置页次要按钮底色。
  static const accountVersionLabel = Color(0xFF716F5F);
  static const accountMutedAction = progressMutedAction;

  /// 设置页卡片底板与描边（设计稿 `box_4`：`#FFF9F2` + `#EBDBCA`）。
  static const accountCardSurface = progressCardSurface;
  static const accountCardBorder = homeCardBorder;

  /// 退出 / 注销挽留弹窗的遮罩（设计稿 `section_1` 是 50% 黑）。
  static const accountDialogBarrier = Color(0x80000000);

  /// 底部导航栏的向上阴影（设计稿 07-01 `box_7`：`0 -1 8 rgba(0,0,0,0.1)`）。
  static const tabBarShadow = Color(0x1A000000);

  // 订单列表（设计稿 05-01 - 订单列表-有订单 / -暂无订单）
  /// 筛选条轨道与未选中文案（设计稿 `group_3` / `text_6`）。
  static const ordersFilterTrack = Color(0xFFDAB495);
  static const ordersFilterLabel = Color(0xFFFBEADB);

  /// 筛选条选中项的文案色。
  static const ordersFilterActiveLabel = Color(0xFF151200);

  /// 订单状态标签：待还款 / 逾期共用的红橙渐变（设计稿 `矩形` 94x22，
  /// 底部 `#FF4542` → 中部 `#F9302E` → 顶部 `#E62014`）。
  static const ordersStatusDangerGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xFFFF4542), Color(0xFFF9302E), Color(0xFFE62014)],
    stops: [0, 0.46, 1],
  );

  /// 终态（已结清）状态标签的灰底灰字。
  static const ordersStatusNeutralSurface = Color(0xFFE5DDD5);
  static const ordersStatusNeutralLabel = Color(0xFFAFAD9F);

  /// 订单卡片底与描边、产品 Logo 占位：与借款进度卡片同款色值。
  static const ordersCardSurface = progressCardSurface;
  static const ordersCardBorder = progressCardBorder;
  static const ordersCardDivider = progressCardBorder;
  static const ordersLogoSurface = progressLogoSurface;
  static const ordersLogoBorder = progressLogoBorder;
  static const ordersActionGradient = progressPrimaryGradient;

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
