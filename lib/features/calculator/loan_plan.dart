import 'package:decimal/decimal.dart';

import '../../core/money/money.dart';

/// 计算完成、可直接用于渲染的还款计划。
///
/// 所有运算均使用 [Decimal]/整数最小货币单位，因此展示的金额与还款计划表
/// 始终精确到分（centavo）地对齐。
class LoanPlan {
  LoanPlan._({
    required this.principal,
    required this.periods,
    required this.interestPerPeriodPercent,
    required List<LoanInstallment> schedule,
  }) : schedule = List.unmodifiable(schedule);

  /// 平息方案：每期均按全额本金计息。
  factory LoanPlan.build({
    required Money principal,
    required int periods,
    required Decimal interestPerPeriodPercent,
    required DateTime startDate,
    required int daysPerPeriod,
  }) {
    final safePeriods = periods < 1 ? 1 : periods;
    final totalInterest = principal.multipliedBy(
      (interestPerPeriodPercent * Decimal.fromInt(safePeriods) / Decimal.fromInt(100)).toDecimal(),
    );
    final totalRepayment = principal + totalInterest;
    final perPeriod = _split(totalRepayment, safePeriods);
    final interestPerPeriod = _split(totalInterest, safePeriods);

    final schedule = <LoanInstallment>[];
    for (var index = 1; index <= safePeriods; index++) {
      final isLast = index == safePeriods;
      final interest = isLast
          ? totalInterest - interestPerPeriod * (safePeriods - 1)
          : interestPerPeriod;
      final payment = isLast
          ? totalRepayment - perPeriod * (safePeriods - 1)
          : perPeriod;
      final principalPart = payment - interest;
      schedule.add(
        LoanInstallment(
          index: index,
          dueDate: startDate.add(Duration(days: daysPerPeriod * index)),
          principal: principalPart,
          interest: interest,
          payment: payment,
        ),
      );
    }

    return LoanPlan._(
      principal: principal,
      periods: safePeriods,
      interestPerPeriodPercent: interestPerPeriodPercent,
      schedule: schedule,
    );
  }

  final Money principal;
  final int periods;
  final Decimal interestPerPeriodPercent;
  final List<LoanInstallment> schedule;

  Money get totalInterest =>
      schedule.fold(Money.zero, (sum, item) => sum + item.interest);

  Money get totalRepayment =>
      schedule.fold(Money.zero, (sum, item) => sum + item.payment);

  Money get perPeriodPayment => schedule.isEmpty ? Money.zero : schedule.first.payment;

  /// 将金额拆分为 [parts] 个大致相等的最小货币单位份额。
  static Money _split(Money total, int parts) {
    final base = total.minorUnits ~/ parts;
    return Money.fromMinor(base);
  }
}

class LoanInstallment {
  const LoanInstallment({
    required this.index,
    required this.dueDate,
    required this.principal,
    required this.interest,
    required this.payment,
  });

  final int index;
  final DateTime dueDate;
  final Money principal;
  final Money interest;
  final Money payment;
}
