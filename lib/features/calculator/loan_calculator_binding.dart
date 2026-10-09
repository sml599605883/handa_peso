import 'package:get/get.dart';

import 'loan_calculator_controller.dart';

class LoanCalculatorBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<LoanCalculatorController>(LoanCalculatorController.new);
  }
}
