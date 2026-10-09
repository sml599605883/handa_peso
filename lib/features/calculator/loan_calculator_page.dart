import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import 'loan_calculator_controller.dart';
import 'loan_plan.dart';

class LoanCalculatorPage extends GetView<LoanCalculatorController> {
  const LoanCalculatorPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Repayment calculator')),
      body: Obx(() {
        final plan = controller.plan;
        return ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            Text('How much do you need?', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            _AmountChips(controller: controller),
            const SizedBox(height: AppSpacing.md),
            Text('Installment plan', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            _PeriodChips(controller: controller),
            const SizedBox(height: AppSpacing.md),
            _SummaryCard(plan: plan),
            const SizedBox(height: AppSpacing.md),
            Text('Repayment schedule', style: textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            _ScheduleTable(plan: plan),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Illustrative only. The flat rate of 5% per 30-day period is a sample. '
              'Your final terms are shown before you confirm a loan.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        );
      }),
    );
  }
}

class _AmountChips extends StatelessWidget {
  const _AmountChips({required this.controller});

  final LoanCalculatorController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final amount in LoanCalculatorController.availableAmounts)
          Obx(
            () => ChoiceChip(
              key: Key('amount-$amount'),
              label: Text('₱${NumberFormat('#,##0').format(amount)}'),
              selected: controller.amountMajor.value == amount,
              onSelected: (_) => controller.selectAmount(amount),
            ),
          ),
      ],
    );
  }
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({required this.controller});

  final LoanCalculatorController controller;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final period in LoanCalculatorController.availablePeriods)
          Obx(
            () => ChoiceChip(
              key: Key('period-$period'),
              label: Text(period == 1 ? '1 payment' : '$period payments'),
              selected: controller.periods.value == period,
              onSelected: (_) => controller.selectPeriods(period),
            ),
          ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.plan});

  final LoanPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('You repay', style: TextStyle(color: AppColors.onPrimaryMuted, fontSize: 13)),
          const SizedBox(height: AppSpacing.xs),
          Text(
            plan.totalRepayment.format(),
            style: const TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _SummaryMetric(
                label: plan.periods == 1 ? 'Payment' : 'Per payment',
                value: plan.perPeriodPayment.format(),
              ),
              const SizedBox(width: AppSpacing.md),
              _SummaryMetric(label: 'Total interest', value: plan.totalInterest.format()),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.onPrimaryMuted, fontSize: 12)),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textOnPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ScheduleTable extends StatelessWidget {
  const _ScheduleTable({required this.plan});

  final LoanPlan plan;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dateFormat = DateFormat('yyyy-MM-dd');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          children: [
            for (final item in plan.schedule)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 40,
                      child: Text('#${item.index}', style: textTheme.bodySmall),
                    ),
                    Expanded(
                      child: Text(dateFormat.format(item.dueDate), style: textTheme.bodyMedium),
                    ),
                    Text(
                      item.payment.format(),
                      style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
