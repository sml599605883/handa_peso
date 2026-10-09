import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/money/money.dart';
import 'package:handa_peso/features/calculator/loan_plan.dart';

void main() {
  group('LoanPlan', () {
    test('flat interest totals reconcile with the schedule', () {
      final plan = LoanPlan.build(
        principal: Money.fromMajor(10000),
        periods: 6,
        interestPerPeriodPercent: Decimal.parse('5'),
        startDate: DateTime(2026, 1, 1),
        daysPerPeriod: 30,
      );

      expect(plan.totalInterest, Money.fromMajor(3000));
      expect(plan.totalRepayment, Money.fromMajor(13000));
      expect(plan.schedule, hasLength(6));

      final scheduleTotal = plan.schedule
          .fold(Money.zero, (sum, item) => sum + item.payment);
      expect(scheduleTotal, plan.totalRepayment);
    });

    test('due dates advance by the period length', () {
      final plan = LoanPlan.build(
        principal: Money.fromMajor(5000),
        periods: 1,
        interestPerPeriodPercent: Decimal.parse('5'),
        startDate: DateTime(2026, 1, 1),
        daysPerPeriod: 30,
      );

      expect(plan.schedule.single.dueDate, DateTime(2026, 1, 31));
    });
  });
}
