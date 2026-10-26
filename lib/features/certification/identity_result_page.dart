import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_text_selection_menu.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../../core/report/report_scene.dart';
import '../../core/report/report_service.dart';
import 'identity_design.dart';
import 'identity_models.dart';
import 'widgets/identity_birthday_picker.dart';

/// 上传成功（设计稿 03-01 - 身份认证-上传成功）。
///
/// 展示服务端识别出的姓名 / 证件号 / 出生日期与证件图：姓名与证件号是可直接改的
/// 输入框（识别难免出错），出生日期点一下弹设计稿 03-02 的滚轮。点 Submit 才真正
/// 保存（`/dropcloth/polybutadiene`）；保存成功后再核一遍基础信息
/// （`/dropcloth/phellem`），然后带着成功结果逐层返回认证流程。
class IdentityResultPage extends StatefulWidget {
  const IdentityResultPage({
    this.apiClient,
    this.autoContinue = true,
    super.key,
  });

  /// 网关；缺省从容器取。
  final GatewayClient? apiClient;
  final bool autoContinue;

  @override
  State<IdentityResultPage> createState() => _IdentityResultPageState();
}

class _IdentityResultPageState extends State<IdentityResultPage> {
  late final GatewayClient _apiClient =
      widget.apiClient ?? Get.find<GatewayClient>();
  late final IdentityRecognition _recognition =
      IdentityRecognition.fromArguments(Get.arguments);

  /// 姓名与证件号直接落到可编辑的输入框上：识别难免出错，用户要能改。
  late final TextEditingController _nameController = TextEditingController(
    text: _recognition.fullName,
  );
  late final TextEditingController _idController = TextEditingController(
    text: _recognition.idNumber,
  );

  /// 出生日期：由设计稿 03-02 的滚轮选择器写入，格式固定 `d-m-Y`。
  late String _birthday = _recognition.birthday;

  String _productId = '';
  String _cardType = '';

  /// 场景 3 的开始时间：由上传页在「点击证件正面」时取好带过来。
  int _sceneStartSeconds = 0;

  bool _busy = false;

  /// 调用方带进来的完成标记：保存成功后打勾，让整条流程知道可以退出了。
  IdentityFlowOutcome? _outcome;

  @override
  void initState() {
    super.initState();
    _outcome = IdentityFlowOutcome.of(Get.arguments);
    final arguments = Get.arguments;
    if (arguments is Map) {
      _productId = arguments['productId']?.toString().trim() ?? '';
      _cardType = arguments['cardType']?.toString().trim() ?? '';
      final startedAt = arguments['sceneStartSeconds'];
      _sceneStartSeconds = startedAt is int
          ? startedAt
          : int.tryParse('$startedAt') ?? 0;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    // 设计/产品要求：证件信息确认页是单向步骤，不能再退回上传页。这里同时
    // 去掉顶部返回键，并拦掉系统返回键与 iOS 侧滑返回。
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {},
      child: IdentityPageScaffold(
        gradient: AppColors.identityPageGradient,
        builder: (context, metrics) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            IdentityPageHeader(
              metrics: metrics,
              title: IdentityStrings.pageTitle,
              showBack: false,
            ),
            IdentityHeroBanner(
              text: _heroCopy,
              metrics: metrics,
              maxLines: 2,
              minFontSize: 14,
              maxFontSize: 20,
            ),
            SizedBox(height: metrics.size(15)),
            DecoratedBox(
              key: const Key('identity-result-card'),
              decoration: BoxDecoration(
                color: AppColors.identityCardSurface,
                // 整张卡片四角同圆角：外框只画下半圈时，卡片底色会在标题层的
                // 圆角切角处露出两块方形底色。标题层与外框用同一个半径，两者
                // 的上圆角就完全重合。
                borderRadius: BorderRadius.circular(
                  metrics.size(IdentityDesign.cardRadius),
                ),
                border: Border.all(
                  color: AppColors.identityCardBorder,
                  width: metrics.size(1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  IdentityCardHeader(
                    key: const Key('identity-result-pill'),
                    title: IdentityStrings.resultCardTitle,
                    metrics: metrics,
                    height: IdentityDesign.resultPillHeight,
                    attachedToCard: true,
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      metrics.size(20),
                      metrics.size(20),
                      metrics.size(20),
                      metrics.size(21),
                    ),
                    child: AspectRatio(
                      aspectRatio:
                          IdentityDesign.resultPhotoWidth /
                          IdentityDesign.resultPhotoHeight,
                      child: _IdentityPhoto(
                        url: _recognition.imageUrl,
                        metrics: metrics,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: metrics.size(14)),
            _ResultRow(
              key: const Key('identity-result-row-0'),
              label: IdentityStrings.fullNameLabel,
              metrics: metrics,
              controller: _nameController,
              fieldKey: const Key('identity-result-name'),
            ),
            SizedBox(height: metrics.size(14)),
            _ResultRow(
              key: const Key('identity-result-row-1'),
              label: IdentityStrings.idNumberLabel,
              metrics: metrics,
              controller: _idController,
              fieldKey: const Key('identity-result-id'),
            ),
            SizedBox(height: metrics.size(14)),
            _ResultRow(
              key: const Key('identity-result-row-2'),
              label: IdentityStrings.birthdayLabel,
              metrics: metrics,
              value: _birthday,
              onTap: _pickBirthday,
            ),
            SizedBox(height: metrics.size(20)),
            Center(
              child: IdentitySubmitButton(
                key: const Key('identity-result-submit'),
                metrics: metrics,
                onPressed: _busy ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _heroCopy {
    final copy =
        _apiClient.settings.localSession.productFlowCopy.identityConfirmation;
    return copy.isEmpty ? IdentityStrings.heroCopy : copy;
  }

  /// 打开设计稿 03-02 的日期滚轮。识别不出生日时给一个成年人的默认值，
  /// 免得用户从 1900 年一路往下滚。
  Future<void> _pickBirthday() async {
    if (_busy) return;
    final picked = await showIdentityBirthdayPicker(
      context,
      initialDate:
          IdentityBirthday.parse(_birthday) ??
          DateTime(DateTime.now().year - 25, 1, 1),
    );
    if (picked == null || !mounted) return;
    setState(() => _birthday = picked);
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _nameController.text.trim();
    final idNumber = _idController.text.trim();
    final birthday = _birthday.trim();
    if (name.isEmpty || idNumber.isEmpty || birthday.isEmpty) {
      await EasyLoading.showError(IdentityStrings.saveFailed);
      return;
    }
    setState(() => _busy = true);
    await AppNavigator.showLoading();
    try {
      await _apiClient.saveBasicProfile(
        name: name,
        idNumber: idNumber,
        birthday: birthday,
        cardType: _cardType,
      );
      // 场景 3 的结束时间：证件正面保存成功。
      if (_sceneStartSeconds > 0) {
        unawaited(
          _reporter?.reportScene(
            scene: ReportScene.identityDocument,
            productId: _productId,
            orderNo: _reportOrderNo,
            startedAtSeconds: _sceneStartSeconds,
          ),
        );
      }
      await _apiClient.verifyBasicProfile(productId: _productId);
      await _apiClient.settings.localSession.writeIdentityCardType(_cardType);
      await AppNavigator.dismissLoading();
      if (!mounted) return;
      _outcome?.completed = true;
      _outcome?.cardType = _cardType;
      if (widget.autoContinue && _productId.isNotEmpty) {
        await AppNavigator.continueProductCertification(productId: _productId);
      } else {
        Get.back<void>();
      }
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await EasyLoading.showError(error.message);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await EasyLoading.showError(IdentityStrings.saveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

/// 识别到的证件图。
///
/// 设计稿这里是灰底占位块（307x167），实际数据里服务端会回传上传后的证件图地址
/// （`tidewaters`），因此有地址时显示真图、取不到时退回设计稿的灰底。
class _IdentityPhoto extends StatelessWidget {
  const _IdentityPhoto({required this.url, required this.metrics});

  final String url;
  final IdentityMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: const Key('identity-result-photo'),
      borderRadius: BorderRadius.circular(
        metrics.size(IdentityDesign.resultRowRadius),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.identityPlaceholderSurface,
        ),
        child: url.isEmpty
            ? const SizedBox.expand()
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const SizedBox.expand(),
              ),
      ),
    );
  }
}

/// 一条识别信息（设计稿 `text-wrapper_3`：347x48 白底 + 1px 描边、圆角 8）。
///
/// 两种形态共用同一副外观，静止时都是「灰标签 + 右侧加粗值」：
/// - 传 [controller]：姓名与证件号是可编辑输入框，识别错了用户能直接改；
/// - 传 [onTap]：出生日期是只读文本，点一下弹设计稿 03-02 的日期滚轮。
class _ResultRow extends StatelessWidget {
  const _ResultRow({
    required this.label,
    required this.metrics,
    this.controller,
    this.fieldKey,
    this.value = '',
    this.onTap,
    super.key,
  });

  final String label;
  final IdentityMetrics metrics;
  final TextEditingController? controller;
  final Key? fieldKey;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      width: double.infinity,
      height: metrics.size(IdentityDesign.resultRowHeight),
      padding: EdgeInsets.symmetric(
        horizontal: metrics.size(IdentityDesign.resultRowPadding),
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          metrics.size(IdentityDesign.resultRowRadius),
        ),
        border: Border.all(
          color: AppColors.identityCardBorder,
          width: metrics.size(IdentityDesign.resultRowBorder),
        ),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: metrics.size(IdentityDesign.resultLabelWidth),
            child: Text(
              label,
              style: TextStyle(
                color: AppColors.loginLabelText,
                fontSize: metrics.size(16),
                height: 20 / 16,
              ),
            ),
          ),
          Expanded(child: _buildValue()),
        ],
      ),
    );
    if (onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: row,
    );
  }

  Widget _buildValue() {
    final style = TextStyle(
      color: AppColors.identityTitle,
      fontSize: metrics.size(16),
      fontWeight: FontWeight.w700,
      height: 20 / 16,
    );
    if (controller != null) {
      return TextField(
        key: fieldKey,
        controller: controller,
        contextMenuBuilder: AppTextSelectionMenu.build,
        textAlign: TextAlign.right,
        maxLines: 1,
        style: style,
        cursorColor: AppColors.identityTitle,
        textInputAction: TextInputAction.done,
        // 设计稿这三行只有外框（`text-wrapper_3` 的白底 + 描边），输入框本身
        // 没有任何边框。只写 `border: none` 不够：全局 `inputDecorationTheme`
        // 里的 enabled/focused 描边仍会被 InputDecorator 取用，聚焦时会在行内
        // 再画一圈主色描边，看起来像多了一个输入框。这里把各状态都显式关掉。
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
      );
    }
    return Text(
      value,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: style,
    );
  }
}
