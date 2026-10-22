/// 绑卡页的语义化切图。
abstract final class BindCardAssets {
  static const String fieldChevron = 'assets/personal_information_chevron.png';

  static const List<BindCardTypeArtwork> typeArtwork = <BindCardTypeArtwork>[
    BindCardTypeArtwork(
      selected: 'assets/bind_card_type_ewallet_selected.png',
      unselected: 'assets/bind_card_type_ewallet_unselected.png',
      width: 20,
      height: 20,
    ),
    BindCardTypeArtwork(
      selected: 'assets/bind_card_type_bank_selected.png',
      unselected: 'assets/bind_card_type_bank_unselected.png',
      width: 21,
      height: 17,
    ),
    BindCardTypeArtwork(
      selected: 'assets/bind_card_type_cash_selected.png',
      unselected: 'assets/bind_card_type_cash_unselected.png',
      width: 21,
      height: 17,
    ),
  ];
}

class BindCardTypeArtwork {
  const BindCardTypeArtwork({
    required this.selected,
    required this.unselected,
    required this.width,
    required this.height,
  });

  final String selected;
  final String unselected;
  final double width;
  final double height;
}

/// 设计稿 03-05 的 375x812 几何参数。
abstract final class BindCardDesign {
  static const double minimumPageHeight = 812;

  static const double headerTop = 58;
  static const double titleHeight = 30;
  static const double titleSize = 20;
  static const double backLeft = 14;
  static const double backTop = 56;
  static const double backSize = 24;

  static const double progressLeft = 14;
  static const double progressTop = 102;
  static const double progressWidth = 224;

  static const double heroTop = 123;
  static const double heroHeight = 81;

  static const double typeLeft = 14;
  static const double typeTop = 219;
  static const double typeWidth = 112;
  static const double typeHeight = 58;
  static const double typeGap = 6;
  static const double typeRadius = 14;
  static const double typeLabelSize = 12;
  static const double typeLabelHeight = 14;

  static const double cardLeft = 14;
  static const double cardTop = 291;
  static const double cardWidth = 347;
  static const double cardRadius = 14;
  static const double cardPadding = 13;
  static const double cardPaddingY = 19;
  static const double fieldPitch = 14;
  static const double labelHeight = 20;
  static const double labelSize = 16;
  static const double fieldGap = 10;
  static const double fieldHeight = 48;
  static const double fieldRadius = 10;
  static const double fieldSize = 16;
  static const double groupHintTopGap = 10;
  static const double groupHintHeight = 24;

  static const double alertTopGap = 20;
  static const double alertHeight = 48;
  static const double alertRadius = 14;
  static const double alertTextSize = 12;
  static const double alertTextHeight = 14;

  static const double submitTopGap = 20;
  static const double submitBottomInset = 54;

  static const String alertCopy =
      'Double-check your account details to avoid errors and ensure a '
      'smooth transaction.';
  static const String cashHintCopy =
      'Please confirm your payout account details to ensure successful fund '
      'disbursement.';
  static const String defaultHeroCopy =
      'Tell us more about yourself to speed up your approval.';

  static double cardHeight({required int fieldCount, required bool showsHint}) {
    if (fieldCount <= 0) return 180;
    return 40 +
        labelHeight +
        fieldGap +
        fieldHeight +
        (fieldCount - 1) * (fieldPitch + labelHeight + fieldGap + fieldHeight) +
        (showsHint ? groupHintTopGap + groupHintHeight : 0);
  }
}
