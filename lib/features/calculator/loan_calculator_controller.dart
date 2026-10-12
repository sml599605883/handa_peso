import 'package:decimal/decimal.dart';
import 'package:get/get.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/money/money.dart';
import 'loan_plan.dart';

/// 独立还款计算器的状态与计算逻辑。
///
/// 计算器完全在设备本地按公布的费率运行，因此它是真正的原生工具，
/// 而不是一个 WebView。
class LoanCalculatorController extends GetxController {
  static const availableAmounts = <int>[5000, 10000, 20000, 35000];
  static const availablePeriods = <int>[1, 3, 6, 12];
  static const daysPerPeriod = 30;
  static final Decimal interestPerPeriodPercent = Decimal.parse('5');

  final amountMajor = 10000.obs;
  final periods = 3.obs;

  Money get principal => Money.fromMajor(amountMajor.value);

  LoanPlan get plan => LoanPlan.build(
        principal: principal,
        periods: periods.value,
        interestPerPeriodPercent: interestPerPeriodPercent,
        startDate: DateTime.now(),
        daysPerPeriod: daysPerPeriod,
      );

  void selectAmount(int amount) {
    amountMajor.value = amount;
    AnalyticsService.logEvent('calculator_amount_changed', {'amount': amount});
  }

  void selectPeriods(int value) {
    periods.value = value;
    AnalyticsService.logEvent('calculator_period_changed', {'periods': value});
  }
}
