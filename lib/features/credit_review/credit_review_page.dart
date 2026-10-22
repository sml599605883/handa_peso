import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
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

          return SingleChildScrollView(
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
                          width: px(32),
                          height: px(_progressHeight),
                          alignment: Alignment.centerLeft,
                          padding: EdgeInsets.only(left: px(15), right: px(2)),
                          decoration: BoxDecoration(
                            gradient: AppColors.creditReviewProgressGradient,
                            borderRadius: BorderRadius.circular(px(2)),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
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
        },
      ),
    );
  }
}
