import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/analytics/analytics_service.dart';

/// Verification checklist.
///
/// Each step is a native screen in the full product; here we expose the flow
/// skeleton with realistic copy and completion state so the feature is more
/// than a web wrapper.
class CertificationPage extends StatefulWidget {
  const CertificationPage({super.key});

  @override
  State<CertificationPage> createState() => _CertificationPageState();
}

class _CertificationPageState extends State<CertificationPage> {
  final _steps = <_CertificationStep>[
    _CertificationStep(title: 'Identity', description: 'Upload a valid government ID'),
    _CertificationStep(title: 'Face scan', description: 'Confirm you are the ID holder'),
    _CertificationStep(title: 'Personal details', description: 'Address, birthday and contacts'),
    _CertificationStep(title: 'Work information', description: 'Source of income'),
    _CertificationStep(title: 'Payout account', description: 'Where we send your funds'),
  ];

  int _completed = 0;

  void _completeStep(int index) {
    if (index != _completed) return;
    setState(() => _completed += 1);
    AnalyticsService.logEvent(
      AppEvents.certificationStepCompleted,
      {'step': _steps[index].title},
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${_steps[index].title} verified')),
    );
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
                    color: active ? AppColors.textOnPrimary : AppColors.textSecondary,
                  ),
                ),
        ),
        title: Text(step.title, style: textTheme.titleMedium),
        subtitle: Text(step.description),
        trailing: done
            ? const Icon(Icons.verified_rounded, color: AppColors.success)
            : const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        onTap: done ? null : onTap,
      ),
    );
  }
}
