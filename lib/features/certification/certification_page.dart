import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_client.dart';
import '../../core/product/product_detail_loader.dart';
import '../../core/report/report_scene.dart';
import '../../core/report/report_service.dart';

/// 认证核对清单。
///
/// 证件、人脸、个人信息与工作信息已经是真实流程；只有对应接口确认成功才把
/// 步骤标记完成。其余步骤仍是流程骨架，等各自的设计稿落地后按同样的方式替换。
///
/// 每一步完成时按接口文档上报风控埋点，产品 ID 由申请入口透传进来。
class CertificationPage extends StatefulWidget {
  const CertificationPage({super.key});

  @override
  State<CertificationPage> createState() => _CertificationPageState();
}

class _CertificationPageState extends State<CertificationPage> {
  /// 步骤与风控埋点场景的对应关系（接口文档「上报风控埋点(新)」的 `proves`）。
  ///
  /// 个人信息（5）、工作信息（6）与银行卡（8）由各自页面在真实提交成功时上报；
  /// 这里保留映射供后续仍为骨架的银行卡步骤使用。
  static const _sceneByStep = <int, String>{
    2: ReportScene.personalInfo,
    3: ReportScene.jobInfo,
    4: ReportScene.bankCard,
  };

  final _steps = <_CertificationStep>[
    _CertificationStep(
      title: 'Identity',
      description: 'Upload a valid government ID',
    ),
    _CertificationStep(
      title: 'Face scan',
      description: 'Confirm you are the ID holder',
    ),
    _CertificationStep(
      title: 'Personal details',
      description: 'Address, birthday and profile details',
    ),
    _CertificationStep(
      title: 'Work information',
      description: 'Source of income',
    ),
    _CertificationStep(
      title: 'Payout account',
      description: 'Where we send your funds',
    ),
  ];

  int _completed = 0;

  /// 用户申请的产品 ID；从申请入口的路由参数带进来，缺省为空串。
  String _productId = '';

  /// 列表入口没有先走产品详情深链时，在第一步打开前补拉一次详情，让后续认证页
  /// 能读到服务端下发的文案。失败时仍允许按本地兜底继续。
  late final Future<void> _detailReady = _prepareProductDetail();

  /// 当前进行中步骤的开始时间。
  ///
  /// 文档要求「进入页面 -> 提交成功」，所以每完成一步就把下一步的开始时间重置为
  /// 此刻；第一步取页面打开时间。
  int _stepStartedAtSeconds = 0;

  @override
  void initState() {
    super.initState();
    _stepStartedAtSeconds = ReportService.nowSeconds();
    final arguments = Get.arguments;
    if (arguments is Map) {
      _productId = arguments['productId']?.toString() ?? '';
    }
    unawaited(_detailReady);
  }

  /// 上报服务由启动流程注册；未接入或独立测试时为空。
  ReportService? get _reporter =>
      Get.isRegistered<ReportService>() ? Get.find<ReportService>() : null;

  /// 证件流程是否正在打开：连点只保留一次。
  bool _openingIdentity = false;

  /// 人脸流程是否正在打开：连点只保留一次。
  bool _openingFace = false;

  /// 个人信息流程是否正在打开：连点只保留一次。
  bool _openingPersonal = false;

  /// 工作信息流程是否正在打开：连点只保留一次。
  bool _openingWork = false;

  /// 证件流程选中的卡种；人脸上传接口继续使用这个必填字段。
  String _identityCardType = '';

  void _onStepTap(int index) {
    if (index != _completed) return;
    if (index == 0) {
      unawaited(_openIdentityFlow());
      return;
    }
    if (index == 1) {
      unawaited(_openFaceFlow());
      return;
    }
    if (index == 2) {
      unawaited(_openPersonalFlow());
      return;
    }
    if (index == 3) {
      unawaited(_openWorkFlow());
      return;
    }
    _completeStep(index);
  }

  /// 第一步「证件」进入真实的原生流程（设计稿 03-01 身份认证）。
  ///
  /// 流程内部自己上报场景 2（认证选择）与场景 3（证件信息）；这里只等它返回
  /// 「证件信息已保存」，成功才把这一步标记完成。
  Future<void> _openIdentityFlow() async {
    if (_openingIdentity) return;
    await _detailReady;
    _openingIdentity = true;
    try {
      final outcome = await AppNavigator.toIdentityVerification(
        productId: _productId,
      );
      if (!mounted || !outcome.completed) return;
      _identityCardType = outcome.cardType;
      _finishStep(0);
      await _openFaceFlow();
    } finally {
      _openingIdentity = false;
    }
  }

  /// 第二步「人脸」进入真实设计稿页面，上传成功后才标记完成。
  Future<void> _openFaceFlow() async {
    if (_openingFace) return;
    await _detailReady;
    _openingFace = true;
    try {
      final verified = await AppNavigator.toFaceVerification(
        productId: _productId,
        cardType: _identityCardType,
      );
      if (!mounted || !verified) return;
      _finishStep(1);
    } finally {
      _openingFace = false;
    }
  }

  /// 第三步「个人信息」进入真实设计稿页面，保存成功才标记完成。
  Future<void> _openPersonalFlow() async {
    if (_openingPersonal) return;
    await _detailReady;
    _openingPersonal = true;
    try {
      final outcome = await AppNavigator.toPersonalInformation(
        productId: _productId,
      );
      if (!mounted || !outcome.completed) return;
      _finishStep(2);
    } finally {
      _openingPersonal = false;
    }
  }

  /// 第四步「工作信息」复用动态表单页面，只切换工作信息接口。
  Future<void> _openWorkFlow() async {
    if (_openingWork) return;
    await _detailReady;
    _openingWork = true;
    try {
      final outcome = await AppNavigator.toWorkInformation(
        productId: _productId,
      );
      if (!mounted || !outcome.completed) return;
      _finishStep(3);
    } finally {
      _openingWork = false;
    }
  }

  Future<void> _prepareProductDetail() async {
    if (_productId.isEmpty || !Get.isRegistered<GatewayClient>()) return;
    try {
      await ProductDetailLoader.load(
        Get.find<GatewayClient>(),
        productId: _productId,
      );
    } catch (_) {
      // 详情失败时保留已有缓存；认证页仍可用设计稿文案继续。
    }
  }

  void _completeStep(int index) {
    if (index != _completed) return;

    final scene = _sceneByStep[index];
    if (scene != null) {
      unawaited(
        _reporter?.reportScene(
          scene: scene,
          productId: _productId,
          startedAtSeconds: _stepStartedAtSeconds,
        ),
      );
    }
    _finishStep(index);
  }

  /// 标记某一步完成，并把下一步的开始时间重置为此刻。
  void _finishStep(int index) {
    setState(() => _completed += 1);
    _stepStartedAtSeconds = ReportService.nowSeconds();
    AnalyticsService.logEvent(AppEvents.certificationStepCompleted, {
      'step': _steps[index].title,
    });
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('${_steps[index].title} verified')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Text(
            'Complete ${_steps.length} steps to unlock your offers',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your data is encrypted and only used to assess eligibility.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: AppSpacing.md),
          for (var index = 0; index < _steps.length; index++)
            _StepTile(
              step: _steps[index],
              index: index,
              done: index < _completed,
              active: index == _completed,
              onTap: () => _onStepTap(index),
            ),
        ],
      ),
    );
  }
}

class _CertificationStep {
  const _CertificationStep({required this.title, required this.description});

  final String title;
  final String description;
}

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.step,
    required this.index,
    required this.done,
    required this.active,
    required this.onTap,
  });

  final _CertificationStep step;
  final int index;
  final bool done;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: done
              ? AppColors.success
              : active
              ? AppColors.primary
              : AppColors.surfaceMuted,
          child: done
              ? const Icon(Icons.check_rounded, color: AppColors.textOnPrimary)
              : Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: active
                        ? AppColors.textOnPrimary
                        : AppColors.textSecondary,
                  ),
                ),
        ),
        title: Text(step.title, style: textTheme.titleMedium),
        subtitle: Text(step.description),
        trailing: done
            ? const Icon(Icons.verified_rounded, color: AppColors.success)
            : const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textMuted,
              ),
        onTap: done ? null : onTap,
      ),
    );
  }
}
