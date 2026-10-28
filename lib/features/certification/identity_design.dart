import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';

/// 证件认证流程用到的切图。
///
/// 返回键复用登录页的同款切片（设计稿 24x24，与本项目其它二级页面一致）；其余
/// 四张来自 03 系列设计稿，按语义重命名，避免 `编组 3@3x` 这类无语义文件名。
abstract final class IdentityAssets {
  /// 左上角返回键（设计稿 `label_1`）。
  static const String back = 'assets/login/login_back.png';

  /// 顶部引导文案右侧的钱袋插画（设计稿 `编组 3` 92x81）。
  static const String moneyBag = 'assets/identity_header_money_bag.png';

  /// 演示卡片正文：示意证件 + 分隔线 + 三张错误示范（设计稿 `编组 9` 328x312）。
  static const String demoCard = 'assets/identity_demo_card.png';

  /// 人脸识别页演示卡片：示意人像 + 分隔线 + 三张错误示范（设计稿 `编组 11` 328x312）。
  static const String faceDemoCard = 'assets/face_recognition_demo_card.png';

  /// 证件类型按钮底板（设计稿 `矩形` 332x56）。
  static const String idTypeButton = 'assets/identity_id_type_button.png';

  /// 证件类型分组横幅（设计稿 `编组 5` 349x66，与首页借款卡片头部同一张切片）。
  static const String idTypeRibbon = 'assets/home_loan_card_header.png';

  /// 横幅右侧的箭头指示（设计稿 `编组 9备份 4` 18x10）。
  static const String ribbonChevron = 'assets/identity_ribbon_chevron.png';

  /// 个人信息输入框右侧的箭头（设计稿 03-03）。
  static const String fieldChevron = 'assets/personal_information_chevron.png';
}

/// 证件认证流程的几何常量。
///
/// 数值全部是设计画布上的原始值：上传/认证方式/成功三页是 375x812，证件类型
/// 选择页是 375x988（比一屏更高，交给滚动承接）。换算到设备尺寸走 [IdentityMetrics]。
abstract final class IdentityDesign {
  static const double pageWidth = 375;
  static const double pageHeight = 812;

  /// 返回键与标题（设计稿 24x24 @ y=56、20 号字 @ y=58）。
  static const double backLeft = 14;
  static const double backTop = 56;
  static const double backSize = 24;
  static const double titleTop = 58;
  static const double titleHeight = 30;
  static const double titleSize = 20;

  /// 顶部引导文案（设计稿 `text-group_1` 238x48 @ (14, 106)）与钱袋插画
  /// （设计稿 `box_1` 92x81 @ (256, 90)）。
  static const double heroLeft = 14;
  static const double heroTop = 106;
  static const double heroWidth = 238;
  static const double heroLineHeight = 24;
  static const double heroSize = 20;
  static const double moneyBagLeft = 256;
  static const double moneyBagTop = 90;
  static const double moneyBagWidth = 92;
  static const double moneyBagHeight = 81;

  /// 页面卡片与卡片头部（设计稿外层卡片从 y=186 开始，标题层是卡片顶部）。
  static const double cardLeft = 14;
  static const double cardWidth = 347;
  static const double cardRadius = 14;

  /// 上传页标题层（设计稿 `矩形` 347x46 @ (14,186)）。
  static const double uploadPillHeight = 46;

  /// 上传证件页的整张卡片（设计稿 `矩形` 347x397 @ (14,186)）与卡片内的
  /// 演示切图（设计稿 `编组 9` 328x312 @ (19, 250)）。
  static const double demoLeft = 19;
  static const double demoWidth = 328;
  static const double demoHeight = 312;

  /// 上传成功页整张卡片（设计稿 `矩形` 347x254 @ (14,186)）、证件图（设计稿 `block_6`
  /// 307x167）与三条识别信息（347x48，行距 62）。
  static const double resultPillHeight = 46;
  static const double resultPhotoLeft = 34;
  static const double resultPhotoWidth = 307;
  static const double resultPhotoHeight = 167;
  static const double resultRowHeight = 48;
  static const double resultRowRadius = 8;
  static const double resultRowBorder = 1;
  static const double resultRowPadding = 13;
  static const double resultLabelWidth = 89;

  /// 底部主按钮（设计稿 220x52、圆角 26、暖橙渐变）。
  static const double submitWidth = 220;
  static const double submitHeight = 52;
  static const double submitRadius = 26;
  static const double submitSize = 20;

  /// 证件类型选择页：两张 347x374 的分组卡片、两组横幅与一列 332x56 的按钮。
  static const double typeCardTop = 134;
  static const double typeCardSecondTop = 560;
  static const double typeCardHeight = 374;
  static const double typeCardRadius = 25;
  static const double typeCardBorder = 2;
  static const double typeButtonLeft = 20;
  static const double typeButtonTop = 32;
  static const double typeButtonWidth = 332;
  static const double typeButtonHeight = 56;
  static const double typeButtonPitch = 68;
  static const double typeButtonSize = 20;

  /// 分组横幅：整体 349x66 的切片叠在卡片上沿之外，标题与箭头按设计稿摆位。
  static const double ribbonLeft = 12;
  static const double ribbonWidth = 349;
  static const double ribbonHeight = 66;
  static const double ribbonOffset = 32;
  static const double ribbonLabelLeft = 56;
  static const double ribbonLabelTop = 21;
  static const double ribbonLabelSize = 16;
  static const double ribbonLabelHeight = 19;
  static const double ribbonChevronLeft = 276;
  static const double ribbonChevronTop = 27;
  static const double ribbonChevronWidth = 18;
  static const double ribbonChevronHeight = 10;

  /// 认证方式选择弹层（设计稿 `section_7` / `block_3`）：遮罩 50% 黑，白底弹层
  /// 从设计坐标 504 起、圆角 24、内边距 14/24/9。
  static const double sheetTop = 504;
  static const double sheetHeight = 812 - sheetTop;
  static const double sheetRadius = 24;
  static const double sheetPaddingTop = 14;
  static const double sheetPaddingSide = 24;
  static const double sheetPaddingBottom = 9;
  static const double sheetBackGap = 24;
  static const double sheetRowTop = 62;
  static const double sheetRowGap = 20;
  static const double sheetRowHeight = 48;
  static const double sheetRowRadius = 8;
  static const double sheetRowSize = 16;
  static const double sheetSubmitGap = 24;
  static const double sheetMarkerSize = 10;
  static const double sheetMarkerRight = -1;
  static const double sheetMarkerCenterOffset = -5;

  /// 弹层内容宽度：面板 375 减掉两侧各 24 的内边距。
  static const double sheetContentWidth = pageWidth - sheetPaddingSide * 2;

  /// 生日选择弹层（设计稿 03-02 - 个人信息-日期选择）。
  ///
  /// 面板从设计坐标 344 起、高 468；滚轮 5 行、行距 60，居中一行（y=544）盖一条
  /// 327x48 的选中条；Submit 与取图弹层同在 y=706。
  static const double birthdaySheetTop = 344;
  static const double birthdaySheetHeight = pageHeight - birthdaySheetTop;
  static const double birthdayWheelTop = 50;
  static const double birthdayWheelHeight = 300;
  static const double birthdayWheelRowPitch = 60;
  static const double birthdayBandTop = 176;
  static const double birthdayBandHeight = 48;
  static const double birthdaySubmitTop = 362;
}

/// 证件流程的 iPhone 适配参数。
///
/// 页面正文按屏宽扣除左右间距后铺排；图片和装饰按自身宽高比缩放，表单与卡片
/// 使用内容高度。缩放只用于图标、间距和控件最小尺寸，并限制在合理范围内。
class IdentityMetrics {
  const IdentityMetrics({
    required this.screenWidth,
    this.safeTop = 0,
    this.safeBottom = 0,
  });

  /// 实际屏幕宽度（逻辑像素）。
  final double screenWidth;

  /// 设备顶部安全区（逻辑像素）。
  final double safeTop;

  /// 设备底部安全区（逻辑像素）。
  final double safeBottom;

  /// 以屏宽为基准，但限制在合理范围内，避免窄屏控件过小或平板无限放大。
  double get scale => (screenWidth / IdentityDesign.pageWidth).clamp(0.85, 1.2);

  /// 页面正文的实际宽度。左右各留 14 设计点，并保留安全上限。
  double get contentWidth =>
      math.min(math.max(0, screenWidth - 28 * scale), 480);

  double get headerShift =>
      math.max(0, safeTop + size(8) - size(IdentityDesign.backTop));

  /// 宽度 / 高度 / 字号 / 圆角 / 描边：乘同一个系数。
  double size(num designValue) => designValue * scale;

  /// 横向位置。
  double x(num designX) => designX * scale;

  /// 纵向位置。
  double y(num designY) => designY * scale;
}

/// 证件流程的页面骨架：整屏底色 + 可滚动 + 点击空白收键盘，并把 [IdentityMetrics]
/// 交给页面 builder。
class IdentityPageScaffold extends StatelessWidget {
  const IdentityPageScaffold({
    required this.gradient,
    required this.builder,
    super.key,
  });

  final Gradient gradient;

  final Widget Function(BuildContext context, IdentityMetrics metrics) builder;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = IdentityMetrics(
              screenWidth: constraints.maxWidth,
              safeTop: MediaQuery.paddingOf(context).top,
              safeBottom: MediaQuery.paddingOf(context).bottom,
            );
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              // 撑满整个视口：只包一层 DecoratedBox 时它会跟着滚动内容的高度
              // 收缩，内容短的页面（上传页/上传成功页）底部会露出 Scaffold 的
              // 默认底色，而设计稿的背景是铺满全屏的。
              child: SizedBox.expand(
                child: DecoratedBox(
                  key: const Key('identity-background'),
                  decoration: BoxDecoration(gradient: gradient),
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.only(
                      bottom: math.max(
                        metrics.size(24),
                        metrics.safeBottom + metrics.size(24),
                      ),
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: metrics.contentWidth,
                        child: builder(context, metrics),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class IdentityPageHeader extends StatelessWidget {
  const IdentityPageHeader({
    required this.metrics,
    required this.title,
    this.onBack,
    this.showBack = true,
    super.key,
  });

  final IdentityMetrics metrics;
  final String title;
  final VoidCallback? onBack;

  /// 为 false 时不摆放返回键（两侧留同样宽度的占位，标题仍然居中）。
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final shift = metrics.headerShift;
    return Padding(
      padding: EdgeInsets.only(top: shift),
      child: SizedBox(
        height: metrics.size(90),
        child: Padding(
          padding: EdgeInsets.only(top: metrics.size(IdentityDesign.titleTop)),
          child: SizedBox(
            height: metrics.size(IdentityDesign.titleHeight),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (showBack)
                  Transform.translate(
                    offset: Offset(0, -metrics.size(2)),
                    child: SizedBox(
                      width: metrics.size(IdentityDesign.backSize),
                      height: metrics.size(IdentityDesign.backSize),
                      child: IdentityBackButton(onBack: onBack),
                    ),
                  )
                else
                  SizedBox(
                    width: metrics.size(IdentityDesign.backSize),
                    height: metrics.size(IdentityDesign.backSize),
                  ),
                Expanded(
                  child: Center(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.identityTitle,
                        fontSize: metrics.size(IdentityDesign.titleSize),
                        fontWeight: FontWeight.w700,
                        height:
                            IdentityDesign.titleHeight /
                            IdentityDesign.titleSize,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: metrics.size(IdentityDesign.backSize),
                  height: metrics.size(IdentityDesign.backSize),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 认证流程顶部引导：左侧渐变提示文案 + 右侧钱袋插画。
///
/// 这个组件只负责设计稿 03 系列顶部引导区，后续认证页直接传入页面文案即可
/// 复用，无需重复摆放插画与描边文字。
class IdentityHeroBanner extends StatelessWidget {
  const IdentityHeroBanner({
    required this.text,
    required this.metrics,
    this.top,
    this.maxLines,
    this.minFontSize = IdentityDesign.heroSize,
    this.maxFontSize = IdentityDesign.heroSize,
    super.key,
  });

  final String text;
  final IdentityMetrics metrics;
  final Widget? top;
  final int? maxLines;
  final double minFontSize;
  final double maxFontSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('identity-hero-banner'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (top != null) ...<Widget>[
                top!,
                SizedBox(height: metrics.size(14)),
              ] else
                SizedBox(height: metrics.size(16)),
              IdentityHeroText(
                text: text,
                metrics: metrics,
                maxLines: maxLines,
                minFontSize: minFontSize,
                maxFontSize: maxFontSize,
              ),
            ],
          ),
        ),
        SizedBox(width: metrics.size(9)),
        SizedBox(
          width: metrics.size(IdentityDesign.moneyBagWidth),
          height: metrics.size(IdentityDesign.moneyBagHeight),
          child: const Image(
            image: AssetImage(IdentityAssets.moneyBag),
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
  }
}

/// 流程内统一使用的页面文案。
abstract final class IdentityStrings {
  /// 三页共用的标题（设计稿 `text_3`）。
  static const String pageTitle = 'ID Verification';
  static const String facePageTitle = 'Document verification';

  /// 上传页与成功页的顶部引导（设计稿 `text-group_1`）。
  static const String heroCopy = 'Snap your valid ID Clear photo, quick check.';

  static const String uploadCardTitle = 'Demonstration!';
  static const String resultCardTitle = 'Successfully!';

  static const String recommendedRibbon = 'Recommended ID Type!';
  static const String otherRibbon = 'Other Options!';

  static const String submit = 'Submit';
  static const String next = 'Next';
  static const String retry = 'Retry';
  static const String camera = 'Camera';
  static const String album = 'Album';

  static const String fullNameLabel = 'Full Name';
  static const String idNumberLabel = 'ID No.';
  static const String birthdayLabel = 'Date of Birth';

  static const String loadFailed = 'Unable to load ID types.';
  static const String emptyTypes = 'No ID types are available.';
  static const String uploadFailed = 'Upload failed';
  static const String saveFailed = 'Unable to save your ID information.';
  static const String photoFailed = 'Unable to read the selected photo.';
  static const String cameraPermissionTitle = 'Camera Permission Off';
  static const String cameraPermissionBody =
      'Camera access is disabled. Please allow access before taking your ID '
      'photo and facial image.';
}

/// 左上角返回键：与其它二级页面同款切片，没有可返回的页面时回到外壳。
class IdentityBackButton extends StatelessWidget {
  const IdentityBackButton({this.onBack, super.key});

  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('identity-back'),
      behavior: HitTestBehavior.opaque,
      onTap: onBack ?? _defaultBack,
      child: const Image(image: AssetImage(IdentityAssets.back)),
    );
  }

  static void _defaultBack() {
    final navigator = Get.key.currentState;
    if (navigator?.canPop() ?? false) {
      navigator!.pop();
      return;
    }
    AppNavigator.toMain();
  }
}

/// 顶部引导文案：设计稿是「渐变填充 + 1px 描边」的斜体黑体。
///
/// Flutter 没有文字描边，这里用两层同位置文本叠出来：底层描边、上层渐变填充。
class IdentityHeroText extends StatelessWidget {
  const IdentityHeroText({
    required this.text,
    required this.metrics,
    this.maxLines,
    this.minFontSize = IdentityDesign.heroSize,
    this.maxFontSize = IdentityDesign.heroSize,
    super.key,
  });

  final String text;
  final IdentityMetrics metrics;
  final int? maxLines;
  final double minFontSize;
  final double maxFontSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fontSize = _resolveFontSize(context, constraints);
        final base = TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          height: IdentityDesign.heroLineHeight / IdentityDesign.heroSize,
        );
        final overflow = maxLines == null
            ? TextOverflow.clip
            : TextOverflow.ellipsis;
        return Stack(
          children: <Widget>[
            Text(
              text,
              maxLines: maxLines,
              overflow: overflow,
              style: base.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = metrics.size(1)
                  ..color = AppColors.identityHeroTextStroke,
              ),
            ),
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (rect) =>
                  AppColors.identityHeroTextGradient.createShader(rect),
              child: Text(
                text,
                maxLines: maxLines,
                overflow: overflow,
                style: base.copyWith(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  double _resolveFontSize(BuildContext context, BoxConstraints constraints) {
    final maximum = metrics.size(math.max(minFontSize, maxFontSize));
    if (maxLines == null || minFontSize >= maxFontSize) return maximum;

    final minimum = metrics.size(minFontSize);
    final lineHeight = IdentityDesign.heroLineHeight / IdentityDesign.heroSize;
    for (
      var designSize = maxFontSize;
      designSize >= minFontSize;
      designSize -= 1
    ) {
      final fontSize = metrics.size(designSize);
      final effectiveStyle = DefaultTextStyle.of(context).style.merge(
        TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          height: lineHeight,
        ),
      );
      final painter = TextPainter(
        text: TextSpan(text: text, style: effectiveStyle),
        maxLines: maxLines,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        locale: Localizations.maybeLocaleOf(context),
      )..layout(maxWidth: constraints.maxWidth);
      if (!painter.didExceedMaxLines) return fontSize;
    }
    return minimum;
  }
}

/// 卡片头部的浅米色面板：`🤩` + 标题（设计稿 `block_1` / `block_5`）。
///
/// 上传页的标题层叠在整张卡片顶部（卡片本身从同一个 y 坐标开始），因此标题
/// 和下面的示范内容属于同一张卡片，不会在连接处露出背景缺口。
class IdentityCardHeader extends StatelessWidget {
  const IdentityCardHeader({
    required this.title,
    required this.metrics,
    this.height = IdentityDesign.uploadPillHeight,
    this.attachedToCard = false,
    super.key,
  });

  final String title;
  final IdentityMetrics metrics;
  final double height;

  /// 作为外卡片的顶部时，只画上方圆角和左/上/右描边，避免连接处出现第二道边。
  final bool attachedToCard;

  @override
  Widget build(BuildContext context) {
    final radius = metrics.size(IdentityDesign.cardRadius);
    return Container(
      width: double.infinity,
      height: metrics.size(height),
      decoration: BoxDecoration(
        color: AppColors.identityPanelSurface,
        borderRadius: attachedToCard
            ? BorderRadius.vertical(top: Radius.circular(radius))
            : BorderRadius.circular(radius),
        border: attachedToCard
            ? Border(
                top: BorderSide(
                  color: AppColors.identityCardBorder,
                  width: metrics.size(1),
                ),
                left: BorderSide(
                  color: AppColors.identityCardBorder,
                  width: metrics.size(1),
                ),
                right: BorderSide(
                  color: AppColors.identityCardBorder,
                  width: metrics.size(1),
                ),
              )
            : Border.all(
                color: AppColors.identityCardBorder,
                width: metrics.size(1),
              ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('🤩', style: TextStyle(fontSize: metrics.size(24), height: 1)),
          SizedBox(width: metrics.size(6)),
          Text(
            title,
            style: TextStyle(
              color: AppColors.identityTitle,
              fontSize: metrics.size(IdentityDesign.heroSize),
              fontWeight: FontWeight.w700,
              letterSpacing: -metrics.size(1),
              height: 30 / IdentityDesign.heroSize,
            ),
          ),
        ],
      ),
    );
  }
}

/// 页面底部的主按钮（设计稿 220x52 的暖橙渐变胶囊）。
class IdentitySubmitButton extends StatelessWidget {
  const IdentitySubmitButton({
    required this.onPressed,
    required this.metrics,
    this.label = IdentityStrings.submit,
    this.width = IdentityDesign.submitWidth,
    super.key,
  });

  final VoidCallback? onPressed;
  final IdentityMetrics metrics;
  final String label;
  final double width;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(
      metrics.size(IdentityDesign.submitRadius),
    );
    return SizedBox(
      width: metrics.size(width),
      height: math.max(48, metrics.size(IdentityDesign.submitHeight)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: onPressed == null ? null : AppColors.homeWarmGradient,
          color: onPressed == null ? AppColors.progressMutedAction : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: metrics.size(IdentityDesign.submitSize),
                  fontWeight: FontWeight.w700,
                  height: 24 / IdentityDesign.submitSize,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 底部弹层面板：取图弹层（03-01）与日期弹层（03-02）共用。
///
/// 白底、顶部圆角 24、`0 -1 8 rgba(0,0,0,0.1)` 的阴影，内边距 14 / 24 / 9，
/// 贴着屏幕底边；遮罩由调用方在 `showGeneralDialog` 的 `barrierColor` 上给。
class IdentityBottomPanel extends StatelessWidget {
  const IdentityBottomPanel({
    required this.height,
    required this.metrics,
    required this.panelKey,
    required this.child,
    super.key,
  });

  /// 面板在设计坐标下的高度。
  final double height;
  final IdentityMetrics metrics;

  /// 白色面板本体的 key（几何断言按它取矩形，取外层包装会拿到整屏）。
  final Key panelKey;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        key: panelKey,
        width: metrics.screenWidth,
        height: metrics.size(height),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(metrics.size(IdentityDesign.sheetRadius)),
          ),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.identitySheetShadow,
              offset: Offset(0, -metrics.size(1)),
              blurRadius: metrics.size(8),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          metrics.size(IdentityDesign.sheetPaddingSide),
          metrics.size(IdentityDesign.sheetPaddingTop),
          metrics.size(IdentityDesign.sheetPaddingSide),
          metrics.size(IdentityDesign.sheetPaddingBottom),
        ),
        child: child,
      ),
    );
  }
}

/// 弹层左上角的返回箭头。
///
/// 设计稿这一枚是纯箭头（没有白底方块），与本项目其它返回键不是同一张切图，也没有
/// 导出对应切片，因此这里用与设计稿同色（`#7F4209`）、同粗细的折线画出来。
class IdentityPanelBackButton extends StatelessWidget {
  const IdentityPanelBackButton({required this.metrics, this.onTap, super.key});

  final IdentityMetrics metrics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final side = metrics.size(IdentityDesign.backSize);
    return SizedBox(
      width: side,
      height: side,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap ?? () => Navigator.of(context).pop(),
        child: CustomPaint(
          painter: _ChevronPainter(
            color: AppColors.identitySheetMarker,
            strokeWidth: metrics.size(1.5),
          ),
        ),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(size.width * 0.62, size.height * 0.16)
      ..lineTo(size.width * 0.30, size.height * 0.5)
      ..lineTo(size.width * 0.62, size.height * 0.84);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}
