import 'package:decimal/decimal.dart';

import '../../core/money/money.dart';

/// A computed, ready-to-render repayment plan.
///
/// All arithmetic is done with [Decimal]/integer minor units so displayed
/// amounts always reconcile with the schedule to the centavo.
class LoanPlan {
  LoanPlan._({
    required this.principal,
    required this.periods,
    required this.interestPerPeriodPercent,
    required List<LoanInstallment> schedule,
  }) : schedule = List.unmodifiable(schedule);

  /// Flat-interest plan: interest is charged per period on the full principal.
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

  /// Splits an amount into [parts] roughly equal minor-unit chunks.
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
