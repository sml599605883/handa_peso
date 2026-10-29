import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../app/widgets/design_back_button.dart';
import 'credit_review_poller.dart';

String creditReviewProductId(Object? arguments) {
  if (arguments is! Map) return '';
  final nested = arguments['payload'];
  final payload = nested is Map ? nested : null;
  for (final key in const <String>[
    'productId',
    'cotype',
    'highlands',
    'knife',
  ]) {
    for (final source in <Map?>[arguments, payload]) {
      final value = source?[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
  }
  return '';
}

/// 设计稿 04-02 里承载百分比文案的起始块宽度（轨道 303x12，文案块 32x12）。
///
/// 0% 时填充块正好 32 宽、文案右侧留 6，复刻设计稿那一帧；进度增长后文案跟着
/// 填充块的头部一起右移，所以这个宽度同时是填充块的最小宽度。
const double _progressChipWidth = 32.0;

/// 百分比文案距填充块头部（右端）的距离，取自设计稿 04-02：文案右沿距
/// 起始块右沿 6（750 稿 12px）。
const double _progressLabelTrailing = 6.0;

/// 进度条填充宽度（设计坐标，单位与 [trackWidth] 相同）。
///
/// 填充宽度必须由真实进度驱动，和百分比文案同源：0% 保留承载文案的起始块，
/// 100% 正好铺满轨道（不溢出），中间按进度线性增长。只改文案不改宽度会让
/// 「99%」停在起始位置（缺陷 reczz28SjrY3cEPW）。
double creditReviewProgressFillWidth({
  required double trackWidth,
  required int progress,
  double minWidth = _progressChipWidth,
}) {
  if (trackWidth <= 0) return 0;
  final ratio = progress.clamp(0, 100) / 100;
  // 轨道比起始块还窄时，下限退到轨道宽度，避免 clamp 的上下界反转。
  final lower = minWidth < trackWidth ? minWidth : trackWidth;
  return (trackWidth * ratio).clamp(lower, trackWidth);
}

class CreditReviewPage extends StatefulWidget {
  const CreditReviewPage({
    this.poller,
    this.progressDelayGenerator,
    this.progressIncrementGenerator,
    super.key,
  });

  final CreditReviewPoller? poller;
  final Duration Function()? progressDelayGenerator;
  final int Function(int currentProgress)? progressIncrementGenerator;

  @override
  State<CreditReviewPage> createState() => _CreditReviewPageState();
}

class _CreditReviewPageState extends State<CreditReviewPage> {
  static const _designWidth = 375.0;
  static const _illustrationWidth = 194.0;
  static const _progressWidth = 303.0;
  static const _progressHeight = 12.0;
  static const _messageWidth = 311.0;
  static const _backLeft = 14.0;
  static const _backTop = 56.0;
  static const _backSize = 24.0;

  static const _illustrationAsset = 'assets/credit_review_illustration.png';

  static final Random _random = Random();

  Timer? _progressTimer;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    final productId = creditReviewProductId(Get.arguments);
    if (productId.isNotEmpty) {
      final poller =
          widget.poller ??
          (Get.isRegistered<CreditReviewPoller>()
              ? Get.find<CreditReviewPoller>()
              : null);
      poller?.start(productId);
    }
    _scheduleProgress();
  }

  void _scheduleProgress() {
    if (_progress >= 99) return;
    final delay =
        widget.progressDelayGenerator?.call() ??
        Duration(seconds: _random.nextInt(3) + 1);
    _progressTimer = Timer(delay, _advanceProgress);
  }

  void _advanceProgress() {
    if (!mounted) return;
    final increment =
        widget.progressIncrementGenerator?.call(_progress) ??
        _random.nextInt(11) + 5;
    setState(() {
      _progress = (_progress + increment).clamp(0, 99);
    });
    _scheduleProgress();
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / _designWidth;
          double px(num value) => value * scale;
          // 填充与百分比文案读同一个 _progress：文字到 99% 时填充也要到 99%。
          final progressFillWidth = creditReviewProgressFillWidth(
            trackWidth: _progressWidth,
            progress: _progress,
          );
          // 返回键与其它二级页面一致：设计坐标 (14, 56)，刘海屏按安全区下移。
          final safeTop = scale == 0
              ? 0.0
              : MediaQuery.paddingOf(context).top / scale;
          final backTop = _backTop + max(0.0, safeTop - _backTop + 8);

          final content = SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.fromLTRB(px(32), px(195), px(32), px(32)),
              child: Column(
                children: [
                  SizedBox(
                    width: px(_illustrationWidth),
                    height: px(_illustrationWidth),
                    child: const Image(
                      key: Key('credit-review-illustration'),
                      image: AssetImage(_illustrationAsset),
                      fit: BoxFit.fill,
                    ),
                  ),
                  SizedBox(height: px(20)),
                  SizedBox(
                    key: const Key('credit-review-progress'),
                    width: px(_progressWidth),
                    height: px(_progressHeight),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.creditReviewTrack,
                              borderRadius: BorderRadius.circular(px(2)),
                            ),
                          ),
                        ),
                        Container(
                          key: const Key('credit-review-progress-fill'),
                          width: px(progressFillWidth),
                          height: px(_progressHeight),
                          alignment: Alignment.centerRight,
                          padding: EdgeInsets.only(
                            left: px(2),
                            right: px(_progressLabelTrailing),
                          ),
                          decoration: BoxDecoration(
                            gradient: AppColors.creditReviewProgressGradient,
                            borderRadius: BorderRadius.circular(px(2)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '$_progress%',
                              key: const Key('credit-review-percent'),
                              maxLines: 1,
                              style: TextStyle(
                                color: AppColors.textOnPrimary,
                                fontSize: px(8),
                                fontFamily: 'Roboto',
                                fontWeight: FontWeight.w400,
                                height: 10 / 8,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: px(14)),
                  SizedBox(
                    key: const Key('credit-review-message'),
                    width: px(_messageWidth),
                    height: px(40),
                    child: Text(
                      'Calculating your credit limit, just 30\n'
                      'seconds Please wait patiently',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.heroValue,
                        fontSize: px(16),
                        fontFamily: 'Helvetica',
                        fontWeight: FontWeight.w400,
                        height: 20 / 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          return Stack(
            children: [
              content,
              Positioned(
                left: px(_backLeft),
                top: px(backTop),
                width: px(_backSize),
                height: px(_backSize),
                child: const DesignBackButton(),
              ),
            ],
          );
        },
      ),
    );
  }
}
