import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../../core/report/report_scene.dart';
import '../../core/report/report_service.dart';
import 'identity_design.dart';
import 'identity_models.dart';
import 'widgets/identity_retention_dialog.dart';

/// 证件类型选择（设计稿 03 - 认证流程模块-展开）。
///
/// 两组横幅卡片：服务端下发的推荐证件与其它可选证件。选中后进入上传页，并把证件
/// code 透传下去——上传接口的 `scarriest` 就是它。
///
/// 风控埋点：文档里「认证选择」的开始时间是**进入选择页**，结束时间才是用户选中
/// 证件，因此这里在 `initState` 取一次时钟，用户点击时上报（场景 2）。
class IdentityTypePage extends StatefulWidget {
  const IdentityTypePage({this.retentionImageProvider, super.key});

  /// 测试时注入本地图片，避免挽留弹窗依赖网络。
  final ImageProvider<Object>? retentionImageProvider;

  @override
  State<IdentityTypePage> createState() => _IdentityTypePageState();
}

class _IdentityTypePageState extends State<IdentityTypePage> {
  late final GatewayClient _apiClient = Get.find<GatewayClient>();

  /// 用户申请的产品 ID；从申请入口一路带下来。
  String _productId = '';

  /// 场景 2 的开始时间：进入本页的时刻。
  late final int _sceneStartSeconds = ReportService.nowSeconds();

  IdentityTypeOptions? _options;
  String? _error;
  bool _loading = true;

  /// 正在跳转：连点只保留一次。
  bool _opening = false;

  /// 挽留接口请求中：连点返回只保留一次。
  bool _checkingRetention = false;

  /// 流程正常完成时放行返回，避免再次触发挽留。
  bool _allowPop = false;

  /// 调用方（认证清单）带进来的完成标记，随流程一路传下去。
  IdentityFlowOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _outcome = IdentityFlowOutcome.of(Get.arguments);
    final arguments = Get.arguments;
    if (arguments is Map) {
      _productId = arguments['productId']?.toString().trim() ?? '';
    }
    _load();
  }

  ReportService? get _reporter =>
      Get.isRegistered<ReportService>() ? Get.find<ReportService>() : null;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reply = await _apiClient.fetchBasicProfile(productId: _productId);
      if (!mounted) return;
      setState(() {
        _options = IdentityTypeOptions.fromReply(reply);
        _loading = false;
      });
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      if (!mounted) return;
      setState(() {
        _error = IdentityStrings.loadFailed;
        _loading = false;
      });
    }
  }

  Future<void> _select(IdentityCardType type) async {
    if (_opening) return;
    _opening = true;
    unawaited(
      _reporter?.reportScene(
        scene: ReportScene.certificationChoice,
        productId: _productId,
        startedAtSeconds: _sceneStartSeconds,
      ),
    );
    AnalyticsService.logEvent(AppEvents.certificationStepCompleted, {
      'step': 'Identity',
      'cardType': type.code,
    });
    try {
      await Get.toNamed<void>(
        AppRoutes.certificationIdentityUpload,
        arguments: <String, dynamic>{
          'productId': _productId,
          'cardType': type.code,
          if (_outcome != null) IdentityFlowOutcome.argumentKey: _outcome,
        },
      );
      // 证件信息保存成功时由上传成功页打勾；这里负责把整条流程退出到认证清单。
      if (!mounted || _outcome?.completed != true) return;
      _leave();
    } finally {
      _opening = false;
    }
  }

  /// 只有证件类型选择页的返回会请求挽留弹窗。
  Future<void> _requestExit() async {
    if (_checkingRetention || _allowPop) return;
    _checkingRetention = true;
    IdentityRetentionPrompt? prompt;
    await EasyLoading.show();
    try {
      final reply = await _apiClient.fetchRetentionPrompt(
        scene: '0',
        productId: _productId,
      );
      prompt = IdentityRetentionPrompt.fromReply(reply);
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
    } finally {
      await EasyLoading.dismiss();
      _checkingRetention = false;
    }
    if (!mounted) return;
    if (prompt?.shouldShow == true) {
      final stay = await showIdentityRetentionDialog(
        context,
        prompt: prompt!,
        imageProvider: widget.retentionImageProvider,
      );
      if (!mounted || stay) return;
    }
    _leave();
  }

  /// 放行一次程序化返回；`PopScope` 在下一帧才会拿到新值。
  void _leave() {
    if (_allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Get.back<void>();
    });
  }

  @override
  Widget build(BuildContext context) {
    final canvasHeight = _canvasHeight(_options);
    return PopScope<void>(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestExit());
      },
      child: IdentityPageScaffold(
        gradient: AppColors.identityTypePageGradient,
        designHeight: canvasHeight,
        builder: (context, metrics) => IdentityPageChrome(
          metrics: metrics,
          contentTop: IdentityDesign.typeCardTop,
          onBack: _requestExit,
          child: SizedBox(
            height: metrics.size(canvasHeight - IdentityDesign.typeCardTop),
            child: _buildBody(metrics),
          ),
        ),
      ),
    );
  }

  /// 画布高度随证件数量变化。
  ///
  /// 设计稿的 5 + 5 正好是 988；服务端给 6 项时（线上就是这么发的）卡片变高，
  /// 画布必须一起长高，否则多出来的部分滚不到、第二张卡片会被截断。
  double _canvasHeight(IdentityTypeOptions? options) {
    final heights = <double>[
      if (options != null && options.recommended.isNotEmpty)
        _cardHeight(options.recommended.length),
      if (options != null && options.others.isNotEmpty)
        _cardHeight(options.others.length),
    ];
    if (heights.isEmpty) return IdentityDesign.typePageHeight;
    return IdentityDesign.typeCardTop +
        heights.fold<double>(0, (sum, value) => sum + value) +
        (heights.length - 1) * _groupGap +
        _bottomMargin;
  }

  /// 底部留白：设计稿画布 988 - 正文起点 134 - 两组 5 项卡片 800 = 54。
  static const double _bottomMargin = 54;

  Widget _buildBody(IdentityMetrics metrics) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final options = _options;
    if (options == null || options.isEmpty) {
      return _IdentityFeedback(
        message: _error ?? IdentityStrings.emptyTypes,
        onRetry: _load,
        metrics: metrics,
      );
    }
    final groups = <_IdentityTypeGroupData>[
      if (options.recommended.isNotEmpty)
        _IdentityTypeGroupData(
          ribbon: IdentityStrings.recommendedRibbon,
          types: options.recommended,
        ),
      if (options.others.isNotEmpty)
        _IdentityTypeGroupData(
          ribbon: IdentityStrings.otherRibbon,
          types: options.others,
        ),
    ];
    // 每张卡片的高度随证件数量变化：5 项时正好是设计稿的 374。
    final heights = groups
        .map((group) => _cardHeight(group.types.length))
        .toList(growable: false);
    final height =
        heights.fold<double>(0, (sum, value) => sum + value) +
        (groups.length - 1) * _groupGap;
    return SizedBox(
      width: double.infinity,
      height: metrics.size(height),
      child: Stack(
        // 横幅压在第一张卡片上沿之外，不能被裁剪。
        clipBehavior: Clip.none,
        children: <Widget>[
          for (var index = 0; index < groups.length; index++)
            Positioned(
              left: metrics.x(IdentityDesign.cardLeft),
              top: metrics.y(
                heights.take(index).fold<double>(0, (sum, v) => sum + v) +
                    index * _groupGap,
              ),
              child: _IdentityTypeGroup(
                key: Key('identity-type-group-$index'),
                data: groups[index],
                height: heights[index],
                metrics: metrics,
                onSelect: _select,
              ),
            ),
        ],
      ),
    );
  }

  /// 一张证件卡片的高度：顶部 32 + n 行 68 的节距 + 底部 14
  /// （5 项 = 32 + 4*68 + 56 + 14 = 设计稿的 374）。
  static double _cardHeight(int count) =>
      102 + (count - 1) * IdentityDesign.typeButtonPitch;

  /// 两组卡片之间的竖直间距（设计稿 508 -> 560）。
  static const double _groupGap =
      IdentityDesign.typeCardSecondTop -
      IdentityDesign.typeCardTop -
      IdentityDesign.typeCardHeight;
}

class _IdentityTypeGroupData {
  const _IdentityTypeGroupData({required this.ribbon, required this.types});

  final String ribbon;
  final List<IdentityCardType> types;
}

/// 一组证件：347x374 的浅米色卡片 + 压在卡片上沿的横幅 + 一列 332x56 的按钮。
class _IdentityTypeGroup extends StatelessWidget {
  const _IdentityTypeGroup({
    required this.data,
    required this.height,
    required this.metrics,
    required this.onSelect,
    super.key,
  });

  final _IdentityTypeGroupData data;
  final double height;
  final IdentityMetrics metrics;
  final ValueChanged<IdentityCardType> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: metrics.size(IdentityDesign.cardWidth),
      height: metrics.size(height),
      child: Stack(
        // 横幅有一半压在卡片上沿之外，不能裁剪。
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: AppColors.identityPanelSurface,
                borderRadius: BorderRadius.circular(
                  metrics.size(IdentityDesign.typeCardRadius),
                ),
                border: Border.all(
                  color: AppColors.identityCardBorder,
                  width: metrics.size(IdentityDesign.typeCardBorder),
                ),
              ),
            ),
          ),
          for (var index = 0; index < data.types.length; index++)
            Positioned(
              left: metrics.size(_buttonLeft),
              top: metrics.size(
                IdentityDesign.typeButtonTop +
                    index * IdentityDesign.typeButtonPitch,
              ),
              child: _IdentityTypeButton(
                type: data.types[index],
                metrics: metrics,
                onTap: () => onSelect(data.types[index]),
              ),
            ),
          Positioned(
            left: metrics.size(_ribbonLeft),
            top: metrics.size(-IdentityDesign.ribbonOffset),
            child: _IdentityTypeRibbon(
              key: const Key('identity-type-ribbon'),
              label: data.ribbon,
              metrics: metrics,
            ),
          ),
        ],
      ),
    );
  }

  /// 按钮在卡片内的左偏移（设计稿 20 - 14）。
  static const double _buttonLeft =
      IdentityDesign.typeButtonLeft - IdentityDesign.cardLeft;

  /// 横幅在卡片内的左偏移（设计稿 12 - 14）。
  static const double _ribbonLeft =
      IdentityDesign.ribbonLeft - IdentityDesign.cardLeft;
}

class _IdentityTypeRibbon extends StatelessWidget {
  const _IdentityTypeRibbon({
    required this.label,
    required this.metrics,
    super.key,
  });

  final String label;
  final IdentityMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: metrics.size(IdentityDesign.ribbonWidth),
      height: metrics.size(IdentityDesign.ribbonHeight),
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            child: Image(
              image: AssetImage(IdentityAssets.idTypeRibbon),
              fit: BoxFit.fill,
            ),
          ),
          Positioned(
            left: metrics.size(
              IdentityDesign.ribbonLabelLeft - IdentityDesign.ribbonLeft,
            ),
            top: metrics.size(IdentityDesign.ribbonLabelTop),
            height: metrics.size(IdentityDesign.ribbonLabelHeight),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: metrics.size(IdentityDesign.ribbonLabelSize),
                  height: 1,
                ),
              ),
            ),
          ),
          Positioned(
            left: metrics.size(
              IdentityDesign.ribbonChevronLeft - IdentityDesign.ribbonLeft,
            ),
            top: metrics.size(IdentityDesign.ribbonChevronTop),
            width: metrics.size(IdentityDesign.ribbonChevronWidth),
            height: metrics.size(IdentityDesign.ribbonChevronHeight),
            child: const Image(
              image: AssetImage(IdentityAssets.ribbonChevron),
              fit: BoxFit.fill,
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityTypeButton extends StatelessWidget {
  const _IdentityTypeButton({
    required this.type,
    required this.metrics,
    required this.onTap,
  });

  final IdentityCardType type;
  final IdentityMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: Key('identity-type-${type.code}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: metrics.size(IdentityDesign.typeButtonWidth),
        height: metrics.size(IdentityDesign.typeButtonHeight),
        child: Stack(
          alignment: Alignment.center,
          children: <Widget>[
            const Positioned.fill(
              child: Image(
                image: AssetImage(IdentityAssets.idTypeButton),
                fit: BoxFit.fill,
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: metrics.size(16)),
              child: Text(
                type.label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: metrics.size(IdentityDesign.typeButtonSize),
                  fontWeight: FontWeight.w700,
                  height: 24 / IdentityDesign.typeButtonSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 加载失败 / 没有可选项时的提示。
class _IdentityFeedback extends StatelessWidget {
  const _IdentityFeedback({
    required this.message,
    required this.onRetry,
    required this.metrics,
  });

  final String message;
  final VoidCallback onRetry;
  final IdentityMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: metrics.size(32)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: metrics.size(14),
              ),
            ),
            SizedBox(height: metrics.size(12)),
            IdentitySubmitButton(
              metrics: metrics,
              label: IdentityStrings.retry,
              width: 140,
              onPressed: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}
