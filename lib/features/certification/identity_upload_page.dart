import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/ios_permission_prompt.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../../core/permissions/permission_coordinator.dart';
import '../../core/report/report_service.dart';
import '../main_shell/main_controller.dart';
import 'identity_design.dart';
import 'identity_models.dart';
import 'identity_photo_service.dart';
import 'widgets/identity_retention_guard.dart';
import 'widgets/identity_upload_method_sheet.dart';

/// 上传证件正面（设计稿 03-01 - 身份认证-上传身份证 / -认证方式选择）。
///
/// 页面本身只有「示范卡片 + Submit」：点 Submit 弹出取图方式弹层（设计稿的认证
/// 方式选择），确认拍照或相册后按接口文档的 `type=11`（身份证正面）把照片交给
/// `/dropcloth/sikes`，识别结果带到下一屏确认。
///
/// 风控埋点：文档里「证件信息」的开始时间是**点击证件正面**，结束时间是证件正面
/// 保存成功，因此开始时间在用户按下 Submit 时取，结束时间在成功页保存成功后取。
class IdentityUploadPage extends StatefulWidget {
  const IdentityUploadPage({
    this.photoPicker,
    this.photoCompressor,
    this.permissions,
    this.apiClient,
    super.key,
  });

  /// 取图出口；缺省走系统相机或相册。
  final IdentityPhotoPicker? photoPicker;

  /// 压缩出口；缺省压到 500KB 以内。
  final IdentityPhotoCompressor? photoCompressor;

  /// 相机权限出口；缺省复用外壳里的 [PermissionCoordinator]。
  final PermissionCoordinator? permissions;

  /// 网关；缺省从容器取。
  final GatewayClient? apiClient;

  /// 接口文档 `trollopy`：11 表示身份证正面，10 表示人像。
  static const String idFrontTileType = '11';

  /// 接口文档 `sleeker`：1 相册、2 拍照。
  static const String albumSource = '1';
  static const String cameraSource = '2';

  @override
  State<IdentityUploadPage> createState() => _IdentityUploadPageState();
}

class _IdentityUploadPageState extends State<IdentityUploadPage>
    with IdentityRetentionGuard<IdentityUploadPage> {
  late final GatewayClient _apiClient =
      widget.apiClient ?? Get.find<GatewayClient>();
  late final IdentityPhotoPicker _picker =
      widget.photoPicker ?? DefaultIdentityPhotoPicker();
  late final IdentityPhotoCompressor _compressor =
      widget.photoCompressor ?? DefaultIdentityPhotoCompressor();

  String _productId = '';
  String _cardType = '';
  bool _busy = false;

  /// 调用方带进来的完成标记，随流程一路传下去。
  IdentityFlowOutcome? _outcome;

  @override
  String get retentionScene => '0';

  @override
  String get retentionProductId => _productId;

  @override
  GatewayClient get retentionApiClient => _apiClient;

  @override
  void initState() {
    super.initState();
    _outcome = IdentityFlowOutcome.of(Get.arguments);
    final arguments = Get.arguments;
    if (arguments is Map) {
      _productId = arguments['productId']?.toString().trim() ?? '';
      _cardType = arguments['cardType']?.toString().trim() ?? '';
    }
  }

  PermissionCoordinator get _permissions {
    if (widget.permissions != null) return widget.permissions!;
    if (Get.isRegistered<MainController>()) {
      return Get.find<MainController>().permissionCoordinator;
    }
    return PermissionCoordinator();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: retentionCanPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) handleRetentionExit();
      },
      child: IdentityPageScaffold(
        gradient: AppColors.identityPageGradient,
        builder: (context, metrics) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            IdentityPageHeader(
              metrics: metrics,
              title: IdentityStrings.pageTitle,
              onBack: handleRetentionExit,
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
              key: const Key('identity-upload-card'),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  IdentityCardHeader(
                    key: const Key('identity-upload-pill'),
                    title: IdentityStrings.uploadCardTitle,
                    metrics: metrics,
                    height: IdentityDesign.uploadPillHeight,
                    attachedToCard: true,
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      metrics.size(5),
                      metrics.size(18),
                      metrics.size(14),
                      metrics.size(21),
                    ),
                    child: AspectRatio(
                      aspectRatio:
                          IdentityDesign.demoWidth / IdentityDesign.demoHeight,
                      child: const Image(
                        key: Key('identity-upload-demo'),
                        image: AssetImage(IdentityAssets.demoCard),
                        fit: BoxFit.contain,
                        semanticLabel: 'ID upload demonstration',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: metrics.size(20)),
            Center(
              child: IdentitySubmitButton(
                key: const Key('identity-upload-submit'),
                metrics: metrics,
                onPressed: _busy ? null : _startUpload,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _heroCopy {
    final copy = _apiClient.settings.localSession.productFlowCopy.identity;
    return copy.isEmpty ? IdentityStrings.heroCopy : copy;
  }

  Future<void> _startUpload() async {
    if (_busy) return;
    // 场景 3 的开始时间：文档写的是「点击身份证正面」，即用户按下这一枚 Submit 的
    // 一刻；后面确认取图方式也算在这段时长里。中途取消不产生上报。
    final sceneStartSeconds = ReportService.nowSeconds();
    final method = await showIdentityUploadMethodSheet(context);
    if (method == null || !mounted) return;

    AnalyticsService.logEvent(AppEvents.certificationStepCompleted, {
      'step': 'IdentityUpload',
      'source': method.name,
    });

    if (method == IdentityPhotoSource.camera) {
      final decision = await _permissions.requestCamera();
      if (!mounted) return;
      if (decision != PermissionDecision.granted) {
        final openSettings = await showIosPermissionPrompt(
          context,
          title: IdentityStrings.cameraPermissionTitle,
          message: IdentityStrings.cameraPermissionBody,
        );
        if (openSettings && mounted) _permissions.openSettings();
        return;
      }
    }

    setState(() => _busy = true);
    await AppNavigator.showLoading();
    String? path;
    try {
      path = method == IdentityPhotoSource.camera
          ? await _picker.pickFromCamera()
          : await _picker.pickFromAlbum();
      if (path == null || path.isEmpty) {
        await AppNavigator.dismissLoading();
        if (mounted) setState(() => _busy = false);
        return;
      }
      path = await _compressor.compressToLimit(path);
      if (path == null || path.isEmpty) {
        await EasyLoading.showError(IdentityStrings.photoFailed);
        if (mounted) setState(() => _busy = false);
        return;
      }
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await EasyLoading.showError(IdentityStrings.photoFailed);
      if (mounted) setState(() => _busy = false);
      return;
    }
    await _upload(path, sceneStartSeconds, method);
  }

  Future<void> _upload(
    String path,
    int sceneStartSeconds,
    IdentityPhotoSource method,
  ) async {
    try {
      final reply = await _apiClient.uploadEvidence(
        filePath: path,
        body: <String, dynamic>{
          'trollopy': IdentityUploadPage.idFrontTileType,
          'sleeker': method == IdentityPhotoSource.album
              ? IdentityUploadPage.albumSource
              : IdentityUploadPage.cameraSource,
          'scarriest': _cardType,
        },
      );
      await AppNavigator.dismissLoading();
      if (!mounted) return;
      final recognition = IdentityRecognition.fromReply(reply);
      await Get.toNamed<void>(
        AppRoutes.certificationIdentityResult,
        arguments: <String, dynamic>{
          'productId': _productId,
          'cardType': _cardType,
          'sceneStartSeconds': sceneStartSeconds,
          ...recognition.toArguments(),
          if (_outcome != null) IdentityFlowOutcome.argumentKey: _outcome,
        },
      );
      // 证件信息保存成功时标记已完成；这里退回上一屏，由上层继续退出流程。
      if (mounted && _outcome?.completed == true) {
        Get.back<void>();
      }
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await EasyLoading.showError(error.message);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await EasyLoading.showError(IdentityStrings.uploadFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
