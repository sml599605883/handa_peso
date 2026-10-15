import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/report/report_scene.dart';
import '../../core/report/report_service.dart';

/// 认证核对清单。
///
/// 在完整产品中每个步骤都是一个原生页面；这里先给出流程骨架，配上贴近真实的
/// 文案与完成状态，让该功能不止是一个 Web 包装层。
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
  /// 证件（3）与人脸（4）在文档里的开始时间是「点击证件正面 / 点击开始人脸」，
  /// 骨架里既没有子页面也没有提交动作，上报只会得到恒为 0 的时长，属于污染风控
  /// 样本，因此这里不上报；紧急联系人（7）与申贷（9、10）同理，等真实页面落地
  /// 后再接上 [ReportService.reportScene]。
  ///
  /// 认证选择（2）的语义是「进入选择页 -> 选择结束」，这里的列表同时承担选择页
  /// 的角色：进入页面先取一次时间，用户第一次点击即选择结束，因此只在首个动作
  /// 上报一次，后面的点击是步骤完成，不再重复算作选择。
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

  void _completeStep(int index) {
    if (index != _completed) return;

    // 第一次点击既是「选择结束」，也是第一步开始，两条埋点用的是同一个开始时间。
    if (index == 0) {
      unawaited(
        _reporter?.reportScene(
          scene: ReportScene.certificationChoice,
          productId: _productId,
          startedAtSeconds: _stepStartedAtSeconds,
        ),
      );
    }

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
              onTap: () => _completeStep(index),
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
