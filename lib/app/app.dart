import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../core/bootstrap/app_bootstrap.dart';
import 'navigation/app_route_observer.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import '../features/announcements/announcements_page.dart';
import '../features/certification/certification_page.dart';
import '../features/calculator/loan_calculator_binding.dart';
import '../features/calculator/loan_calculator_page.dart';
import '../features/login/login_binding.dart';
import '../features/login/login_page.dart';
import '../features/main_shell/main_binding.dart';
import '../features/main_shell/main_shell_page.dart';
import '../features/mine/account_deletion_page.dart';
import '../features/orders/orders_page.dart';
import '../features/splash/splash_page.dart';
import '../features/support/support_page.dart';
import '../features/webview/app_webview_page.dart';

class HandaPesoApp extends StatelessWidget {
  const HandaPesoApp({required this.dependencies, super.key});

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Handa Peso',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: EasyLoading.init(),
      navigatorObservers: [appRouteObserver, AnalyticsRouteObserver()],
      initialBinding: MainBinding(appDependencies: dependencies),
      initialRoute: AppRoutes.splash,
      getPages: [
        GetPage(name: AppRoutes.splash, page: () => const SplashPage()),
        GetPage(
          name: AppRoutes.login,
          page: () => const LoginPage(),
          binding: LoginBinding(appDependencies: dependencies),
        ),
        GetPage(name: AppRoutes.main, page: () => const MainShellPage()),
        GetPage(
          name: AppRoutes.calculator,
          page: () => const LoanCalculatorPage(),
          binding: LoanCalculatorBinding(),
        ),
        GetPage(name: AppRoutes.certification, page: () => const CertificationPage()),
        GetPage(name: AppRoutes.orders, page: () => const OrdersPage()),
        GetPage(name: AppRoutes.support, page: () => const SupportPage()),
        GetPage(name: AppRoutes.announcements, page: () => const AnnouncementsPage()),
        GetPage(name: AppRoutes.accountDeletion, page: () => const AccountDeletionPage()),
        GetPage(name: AppRoutes.webView, page: () => const AppWebViewPage()),
      ],
    );
  }
}
