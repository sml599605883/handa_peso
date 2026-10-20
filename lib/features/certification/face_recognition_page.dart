import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/camera_permission_prompt.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/face/face_liveness_bridge.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../../core/permissions/permission_coordinator.dart';
import '../../core/product/product_next_step.dart';
import '../../core/report/report_scene.dart';
import '../../core/report/report_service.dart';
import '../main_shell/main_controller.dart';
import 'face_models.dart';
import 'identity_design.dart';

typedef FaceImageWriter = Future<String> Function(String imageBase64);

/// 人脸识别引导页（设计稿 03-01 - 身份认证-人脸识别）。
///
/// 页面本身展示与设计稿一致的示范图；用户点击 `Next` 后，才按 MyTools 的契约
/// 获取 TrustDecision license、拉起活体、上传人脸并上报场景 4。任何一步失败都
/// 留在当前页，不向下一认证项推进。
class FaceRecognitionPage extends StatefulWidget {
  const FaceRecognitionPage({
    this.apiClient,
    this.liveness,
    this.permissions,
    this.reporter,
    this.imageWriter,
    super.key,
  });

  final GatewayClient? apiClient;
  final FaceLivenessLauncher? liveness;
  final PermissionCoordinator? permissions;
  final ReportService? reporter;
  final FaceImageWriter? imageWriter;

  @override
  State<FaceRecognitionPage> createState() => _FaceRecognitionPageState();
}

class _FaceRecognitionPageState extends State<FaceRecognitionPage> {
  late final GatewayClient _apiClient =
      widget.apiClient ?? Get.find<GatewayClient>();
  late final FaceLivenessLauncher _liveness =
      widget.liveness ?? FaceLivenessBridge.instance;
  late final FaceImageWriter _imageWriter =
      widget.imageWriter ?? _writeFaceImage;

  late final String _productId;
  late final String _orderNo;
  late final String _cardType;
  late final FaceVerificationOutcome? _outcome = FaceVerificationOutcome.of(
    Get.arguments,
  );

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments is Map
        ? Map<String, dynamic>.from(Get.arguments as Map)
        : const <String, dynamic>{};
    _productId = arguments['productId']?.toString().trim() ?? '';
    _orderNo = arguments['orderNo']?.toString().trim() ?? '';
    _cardType = arguments['cardType']?.toString().trim() ?? '';
  }

  PermissionCoordinator get _permissions {
    if (widget.permissions != null) return widget.permissions!;
    if (Get.isRegistered<MainController>()) {
      return Get.find<MainController>().permissionCoordinator;
    }
    return PermissionCoordinator();
  }

  ReportService? get _reporter {
    if (widget.reporter != null) return widget.reporter;
    return Get.isRegistered<ReportService>() ? Get.find<ReportService>() : null;
  }

  @override
  Widget build(BuildContext context) {
    return IdentityPageScaffold(
      gradient: AppColors.facePageGradient,
      designHeight: IdentityDesign.pageHeight,
      builder: (context, metrics) => IdentityPageChrome(
        metrics: metrics,
        title: IdentityStrings.facePageTitle,
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
                  key: const Key('face-recognition-card'),
                  width: metrics.size(IdentityDesign.cardWidth),
                  height: metrics.size(IdentityDesign.uploadCardHeight),
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
                  key: const Key('face-recognition-pill'),
                  title: IdentityStrings.uploadCardTitle,
                  metrics: metrics,
                  height: IdentityDesign.uploadPillHeight,
                  attachedToCard: true,
                ),
              ),
              Positioned(
                left: metrics.x(IdentityDesign.demoLeft),
                top: metrics.y(_demoTop),
                width: metrics.size(IdentityDesign.demoWidth),
                height: metrics.size(IdentityDesign.demoHeight),
                child: const Image(
                  key: Key('face-recognition-demo'),
                  image: AssetImage(IdentityAssets.faceDemoCard),
                  fit: BoxFit.fill,
                  semanticLabel: 'Face recognition demonstration',
                ),
              ),
              Positioned(
                left: metrics.x(_submitLeft),
                top: metrics.y(_submitTop),
                child: IdentitySubmitButton(
                  key: const Key('face-recognition-submit'),
                  metrics: metrics,
                  label: IdentityStrings.next,
                  onPressed: _busy ? null : _startFaceVerification,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const double _submitLeft =
      (IdentityDesign.pageWidth - IdentityDesign.submitWidth) / 2;
  static const double _pillTop =
      IdentityDesign.uploadPillTop - IdentityDesign.heroContentTop;
  static const double _cardTop =
      IdentityDesign.uploadCardTop - IdentityDesign.heroContentTop;
  static const double _demoTop =
      IdentityDesign.demoTop - IdentityDesign.heroContentTop;
  static const double _submitTop =
      IdentityDesign.uploadSubmitTop - IdentityDesign.heroContentTop;

  Future<void> _startFaceVerification() async {
    if (_busy) return;

    if (_productId.isEmpty) {
      await EasyLoading.showError(FaceStrings.productMissing);
      return;
    }

    setState(() => _busy = true);
    final sceneStartSeconds = ReportService.nowSeconds();
    String? imagePath;
    try {
      final decision = await _permissions.requestCamera();
      if (!mounted) return;
      if (decision != PermissionDecision.granted) {
        await showCameraPermissionPrompt(
          context,
          openSettings: _permissions.openSettings,
          title: FaceStrings.cameraPermissionTitle,
          message: FaceStrings.cameraPermissionBody,
        );
        return;
      }

      final orderNo = await _resolveOrderNo();
      if (!mounted || orderNo.isEmpty) return;

      final cardType = await _resolveCardType();
      if (!mounted) return;
      if (cardType.isEmpty) {
        await _showIdentityUploadDialog();
        return;
      }

      await EasyLoading.show(status: 'Loading...');
      final tokenReply = await _apiClient.fetchLivenessToken(
        orderNo: orderNo,
        livenessType: '0',
      );
      final token = FaceTokenResult.fromReply(tokenReply);
      if (token.needsIdentityUpload) {
        await EasyLoading.dismiss();
        if (mounted) await _showIdentityUploadDialog();
        return;
      }
      tokenReply.orThrow();
      if (!token.isReady) {
        throw GatewayFailure(
          token.error.isEmpty ? FaceStrings.tokenFailed : token.error,
        );
      }

      await EasyLoading.dismiss();
      final livenessResult = await _liveness.start(token.license);
      unawaited(_reportLivenessResult(livenessResult));
      if (!hasUploadableLivenessData(livenessResult)) {
        throw GatewayFailure(
          livenessResult.message.isEmpty
              ? FaceStrings.livenessFailed
              : livenessResult.message,
        );
      }

      imagePath = await _imageWriter(livenessResult.image);
      await EasyLoading.show(status: 'Loading...');
      final uploadReply = await _apiClient.uploadEvidence(
        filePath: imagePath,
        body: <String, dynamic>{
          // MyTools「接口上传(face,身份证正面)」的 type=10 字段。
          'trollopy': '10',
          'sleeker': '1',
          'scarriest': cardType,
          'debater': livenessResult.livenessId,
          'wowsers': token.license,
          'esplanades': '7',
        },
      );
      uploadReply.orThrow();
      await EasyLoading.dismiss();

      if (sceneStartSeconds > 0) {
        unawaited(
          _reporter?.reportScene(
            scene: ReportScene.faceScan,
            productId: _productId,
            orderNo: orderNo,
            startedAtSeconds: sceneStartSeconds,
          ),
        );
      }
      AnalyticsService.logEvent(AppEvents.certificationStepCompleted, {
        'step': 'Face scan',
      });
      if (!mounted) return;
      _outcome?.completed = true;
      Get.back<void>();
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await EasyLoading.showError(error.message);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await EasyLoading.showError(FaceStrings.verificationFailed);
    } finally {
      if (imagePath != null) {
        try {
          File(imagePath).deleteSync();
        } on FileSystemException {
          // Best-effort cleanup of the temporary liveness image.
        }
      }
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 产品详情接口 `recurs.redecorates` 是 token 接口要求的订单号。
  Future<String> _resolveOrderNo() async {
    if (_orderNo.isNotEmpty) return _orderNo;
    await EasyLoading.show(status: 'Loading...');
    try {
      final reply = await _apiClient.fetchProductDetail(productId: _productId);
      final orderNo = ProductNextStep.fromReply(reply).orderNo;
      if (orderNo.isEmpty) {
        await EasyLoading.showError(FaceStrings.orderMissing);
        return '';
      }
      await EasyLoading.dismiss();
      return orderNo;
    } on GatewayFailure catch (error) {
      await EasyLoading.showError(error.message);
      return '';
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await EasyLoading.showError(FaceStrings.orderMissing);
      return '';
    }
  }

  /// 从路由参数或本地会话中恢复证件卡种；没有时要求用户重新选择并上传证件。
  Future<String> _resolveCardType() async {
    if (_cardType.isNotEmpty) return _cardType;
    return _apiClient.settings.localSession.readIdentityCardType();
  }

  Future<void> _reportLivenessResult(FaceLivenessResult result) async {
    try {
      await _apiClient.reportLivenessDecision(
        livenessId: result.livenessId,
        requestId: result.requestId,
        resultCode: '${result.code}',
        resultJson: result.rawJson.isEmpty ? '{}' : result.rawJson,
      );
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
    }
  }

  Future<void> _showIdentityUploadDialog() async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(FaceStrings.identityRequiredTitle),
        content: const Text(FaceStrings.identityRequiredBody),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await AppNavigator.toIdentityVerification(productId: _productId);
  }

  static Future<String> _writeFaceImage(String imageBase64) async {
    final normalized = imageBase64.contains(',')
        ? imageBase64.split(',').last
        : imageBase64;
    final file = File(
      '${Directory.systemTemp.path}/handa_peso_face_'
      '${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(base64Decode(normalized), flush: true);
    return file.path;
  }
}

abstract final class FaceStrings {
  static const productMissing = 'Product information is not available.';
  static const orderMissing = 'Order information is not available.';
  static const tokenFailed = 'Unable to start face verification.';
  static const livenessFailed = 'Face verification was not completed.';
  static const verificationFailed =
      'Face verification failed. Please try again.';
  static const identityRequiredTitle = 'Upload Your ID Again';
  static const identityRequiredBody =
      'Please select your ID type and upload your ID again to continue face verification.';
  static const cameraPermissionTitle = 'Allow Camera Access';
  static const cameraPermissionBody =
      'Camera access is required for face verification. You can turn it on in Settings.';
}
