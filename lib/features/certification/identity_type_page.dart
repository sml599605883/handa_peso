import 'dart:async';

import 'package:flutter/material.dart';
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
import 'widgets/identity_retention_guard.dart';

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

class _IdentityTypePageState extends State<IdentityTypePage>
    with IdentityRetentionGuard<IdentityTypePage> {
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

  /// 调用方（认证清单）带进来的完成标记，随流程一路传下去。
  IdentityFlowOutcome? _outcome;

  @override
  String get retentionScene => '0';

  @override
  String get retentionProductId => _productId;

  @override
  GatewayClient get retentionApiClient => _apiClient;

  @override
  ImageProvider<Object>? get retentionImageProvider =>
      widget.retentionImageProvider;

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

  /// 风控埋点的全局订单号（文档字段 `redecorates`）。
  ///
  /// 产品详情 `recurs.redecorates` 在打开本页之前已由 `ProductDetailLoader` 写进
  /// 会话缓存：下一步认证由 `AppNavigator` 先拉详情再打开，认证清单入口也会在
  /// 第一步之前补拉一次。因此这里直接读缓存即可，不会为埋点再发一次详情请求。
  String get _reportOrderNo =>
      _apiClient.settings.localSession.productFlowOrderNo.trim();

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
        orderNo: _reportOrderNo,
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
      // 与上传页同理：保存成功后结果页可能已切到下一项并把本页移除，不能再
      // 多退一层去顶掉刚打开的人脸页。
      if (!mounted || _outcome?.completed != true) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      leaveRetentionGuardedPage();
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: retentionCanPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(handleRetentionExit());
      },
      child: IdentityPageScaffold(
        gradient: AppColors.identityTypePageGradient,
        builder: (context, metrics) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            IdentityPageHeader(
              metrics: metrics,
              title: IdentityStrings.pageTitle,
              onBack: handleRetentionExit,
            ),
            SizedBox(height: metrics.size(44)),
            _buildBody(metrics),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(IdentityMetrics metrics) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 120),
        child: Center(child: CircularProgressIndicator()),
      );
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
    return Column(
      children: <Widget>[
        for (var index = 0; index < groups.length; index++) ...<Widget>[
          _IdentityTypeGroup(
            key: Key('identity-type-group-$index'),
            data: groups[index],
            metrics: metrics,
            onSelect: _select,
          ),
          if (index != groups.length - 1)
            SizedBox(height: metrics.size(_groupGap)),
        ],
      ],
    );
  }

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
    required this.metrics,
    required this.onSelect,
    super.key,
  });

  final _IdentityTypeGroupData data;
  final IdentityMetrics metrics;
  final ValueChanged<IdentityCardType> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        // 横幅有一半压在卡片上沿之外，不能裁剪。
        clipBehavior: Clip.none,
        children: <Widget>[
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              metrics.size(_buttonLeft - IdentityDesign.typeCardBorder),
              metrics.size(
                IdentityDesign.typeButtonTop - IdentityDesign.typeCardBorder,
              ),
              metrics.size(_buttonRight - IdentityDesign.typeCardBorder),
              metrics.size(12),
            ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (
                  var index = 0;
                  index < data.types.length;
                  index++
                ) ...<Widget>[
                  _IdentityTypeButton(
                    type: data.types[index],
                    metrics: metrics,
                    onTap: () => onSelect(data.types[index]),
                  ),
                  if (index != data.types.length - 1)
                    SizedBox(
                      height: metrics.size(
                        IdentityDesign.typeButtonPitch -
                            IdentityDesign.typeButtonHeight,
                      ),
                    ),
                ],
              ],
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

  /// 设计稿按钮宽 332，卡片内右侧剩 9。
  static const double _buttonRight =
      IdentityDesign.cardWidth - _buttonLeft - IdentityDesign.typeButtonWidth;

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
        width: double.infinity,
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
