import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
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
  const IdentityResultPage({this.apiClient, super.key});

  /// 网关；缺省从容器取。
  final GatewayClient? apiClient;

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

  @override
  Widget build(BuildContext context) {
    return IdentityPageScaffold(
      gradient: AppColors.identityPageGradient,
      designHeight: IdentityDesign.pageHeight,
      builder: (context, metrics) => IdentityPageChrome(
        metrics: metrics,
        contentTop: IdentityDesign.heroContentTop,
        heroCopy: IdentityStrings.heroCopy,
        child: SizedBox(
          height: metrics.size(
            IdentityDesign.pageHeight - IdentityDesign.heroContentTop,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: <Widget>[
              Positioned(
                left: metrics.x(IdentityDesign.cardLeft),
                top: metrics.y(_cardTop),
                child: Container(
                  key: const Key('identity-result-card'),
                  width: metrics.size(IdentityDesign.cardWidth),
                  height: metrics.size(IdentityDesign.resultCardHeight),
                  decoration: BoxDecoration(
                    color: AppColors.identityCardSurface,
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(
                        metrics.size(IdentityDesign.cardRadius),
                      ),
                    ),
                    border: Border(
                      left: BorderSide(
                        color: AppColors.identityCardBorder,
                        width: metrics.size(1),
                      ),
                      right: BorderSide(
                        color: AppColors.identityCardBorder,
                        width: metrics.size(1),
                      ),
                      bottom: BorderSide(
                        color: AppColors.identityCardBorder,
                        width: metrics.size(1),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: metrics.x(IdentityDesign.cardLeft),
                top: metrics.y(_pillTop),
                child: IdentityCardHeader(
                  key: const Key('identity-result-pill'),
                  title: IdentityStrings.resultCardTitle,
                  metrics: metrics,
                  height: IdentityDesign.resultPillHeight,
                  attachedToCard: true,
                ),
              ),
              Positioned(
                left: metrics.x(IdentityDesign.resultPhotoLeft),
                top: metrics.y(_photoTop),
                width: metrics.size(IdentityDesign.resultPhotoWidth),
                height: metrics.size(IdentityDesign.resultPhotoHeight),
                child: _IdentityPhoto(
                  url: _recognition.imageUrl,
                  metrics: metrics,
                ),
              ),
              _row(
                index: 0,
                metrics: metrics,
                child: _ResultRow(
                  key: const Key('identity-result-row-0'),
                  label: IdentityStrings.fullNameLabel,
                  metrics: metrics,
                  controller: _nameController,
                  fieldKey: const Key('identity-result-name'),
                ),
              ),
              _row(
                index: 1,
                metrics: metrics,
                child: _ResultRow(
                  key: const Key('identity-result-row-1'),
                  label: IdentityStrings.idNumberLabel,
                  metrics: metrics,
                  controller: _idController,
                  fieldKey: const Key('identity-result-id'),
                ),
              ),
              _row(
                index: 2,
                metrics: metrics,
                child: _ResultRow(
                  key: const Key('identity-result-row-2'),
                  label: IdentityStrings.birthdayLabel,
                  metrics: metrics,
                  value: _birthday,
                  onTap: _pickBirthday,
                ),
              ),
              Positioned(
                left: metrics.x(_submitLeft),
                top: metrics.y(_submitTop),
                child: IdentitySubmitButton(
                  key: const Key('identity-result-submit'),
                  metrics: metrics,
                  onPressed: _busy ? null : _save,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 把一行识别信息摆到设计坐标上（454 起、行距 62）。
  Widget _row({
    required int index,
    required IdentityMetrics metrics,
    required Widget child,
  }) {
    return Positioned(
      left: metrics.x(IdentityDesign.cardLeft),
      top: metrics.y(_rowTop + index * IdentityDesign.resultRowPitch),
      child: child,
    );
  }

  /// 主按钮居中：设计稿 220x52 摆在 375 画布正中。
  static const double _submitLeft =
      (IdentityDesign.pageWidth - IdentityDesign.submitWidth) / 2;

  /// 正文区从设计坐标 171（引导区下沿）起，所以正文里的纵向位置都要减掉它。
  static const double _pillTop =
      IdentityDesign.uploadPillTop - IdentityDesign.heroContentTop;
  static const double _cardTop =
      IdentityDesign.resultCardTop - IdentityDesign.heroContentTop;
  static const double _photoTop =
      IdentityDesign.resultPhotoTop - IdentityDesign.heroContentTop;
  static const double _rowTop =
      IdentityDesign.resultRowTop - IdentityDesign.heroContentTop;
  static const double _submitTop =
      IdentityDesign.resultSubmitTop - IdentityDesign.heroContentTop;

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
    await EasyLoading.show(status: 'Loading...');
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
            startedAtSeconds: _sceneStartSeconds,
          ),
        );
      }
      await _apiClient.verifyBasicProfile(productId: _productId);
      await _apiClient.settings.localSession.writeIdentityCardType(_cardType);
      await EasyLoading.dismiss();
      if (!mounted) return;
      _outcome?.completed = true;
      _outcome?.cardType = _cardType;
      Get.back<void>();
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
      width: metrics.size(IdentityDesign.cardWidth),
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
        textAlign: TextAlign.right,
        maxLines: 1,
        style: style,
        cursorColor: AppColors.identityTitle,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          isDense: true,
          filled: false,
          border: InputBorder.none,
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
