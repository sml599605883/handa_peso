/// 放款账户列表用到的切图。
///
/// 蓝湖原始素材名是「编组 3」「矩形备份」等无语义名称，这里按用途统一改成
/// snake_case，页面只引用语义化资源。
abstract final class PayoutAccountAssets {
  static const String addBanner = 'assets/payout_account_add_banner.png';
  static const String cardHeader = 'assets/payout_account_card_header.png';
  static const String checkboxSelected =
      'assets/payout_account_checkbox_selected.png';
  static const String checkboxUnselected =
      'assets/payout_account_checkbox_unselected.png';
}

/// 设计稿 04-01 的几何参数（画布 375x939）。
abstract final class PayoutAccountDesign {
  static const double pageWidth = 375;
  static const double pageHeight = 939;

  /// 标题下方新增账户横幅。
  static const double bannerTopGap = 12;
  static const double bannerHeight = 44;
  static const double bannerToFirstSection = 14;

  /// 分组标题与卡片。
  static const double sectionTitleHeight = 30;
  static const double sectionTitleSize = 20;
  static const double firstTitleToCardGap = 13;
  static const double secondTitleToCardGap = 15;
  static const double titleToCardGap = 14;
  static const double sectionGap = 9;
  static const double laterSectionGap = 10;

  /// 账户卡片。
  static const double cardRadius = 14;
  static const double cardHeaderHeight = 64;
  static const double cardBodyHeight = 86;
  static const double cardBodyWithNoteHeight = 138;
  static const double cardPaddingY = 3;
  static const double accountLabelSize = 16;
  static const double accountLabelHeight = 20;
  static const double accountValueSize = 24;
  static const double accountValueHeight = 28;
  static const double accountLabelToValue = 4;
  static const double accountValueToDivider = 31;
  static const double dividerToNote = 9;
  static const double noteLineHeight = 14;
  static const double noteHeight = 28;
  static const double cardPaddingX = 20;
  static const double dividerInset = 14;

  /// 卡片头部的银行标识与勾选状态。
  static const double logoBoxSize = 30;
  static const double logoSize = 28;
  static const double bankNameSize = 18;
  static const double checkboxSize = 16;

  /// 底部提交按钮与页面收尾。
  static const double submitTopGap = 20;
  static const double submitWidth = 220;
  static const double submitHeight = 52;
  static const double submitRadius = 26;
  static const double submitSize = 20;
  static const double bottomPadding = 54;
}
