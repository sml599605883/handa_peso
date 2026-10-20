import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/report/report_scene.dart';
import '../../core/report/report_service.dart';

/// 认证核对清单。
///
/// 前两步「证件」「人脸」已经是真实流程：证件走类型选择、上传与确认，人脸走
/// MyTools 契约的活体、上传与场景上报；只有服务端确认成功才把步骤标记完成。
/// 其余步骤仍是流程骨架，等各自的设计稿落地后按同样的方式替换。
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
  /// 只登记骨架能真实命中文档时序的三步——它们的语义是「进入页面 -> 提交成功」，
  /// 与这里的「上一步完成即进入本步 -> 点击本步完成」一致。
  ///
  /// 证件（2、3）与人脸（4）由各自的真实页面按文档时机上报，本清单只负责
  /// 后续仍为骨架的个人信息、工作信息与银行卡场景。
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
      description: 'Address, birthday and contacts',
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
  }

  /// 上报服务由启动流程注册；未接入或独立测试时为空。
  ReportService? get _reporter =>
      Get.isRegistered<ReportService>() ? Get.find<ReportService>() : null;

  /// 证件流程是否正在打开：连点只保留一次。
  bool _openingIdentity = false;

  /// 人脸流程是否正在打开：连点只保留一次。
  bool _openingFace = false;

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
    _completeStep(index);
  }

  /// 第一步「证件」进入真实的原生流程（设计稿 03-01 身份认证）。
  ///
  /// 流程内部自己上报场景 2（认证选择）与场景 3（证件信息）；这里只等它返回
  /// 「证件信息已保存」，成功才把这一步标记完成。
  Future<void> _openIdentityFlow() async {
    if (_openingIdentity) return;
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
    // 个人信息这一步包含联系人：顺带把本机通讯录交上去。原生在未授权时会先弹
    // 一次授权，用户拒绝就什么都不传，不影响这一步本身完成。
    if (scene == ReportScene.personalInfo) {
      unawaited(_reporter?.reportDeviceContacts());
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
