import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../core/analytics/screen_view_reporter.dart';
import '../core/bootstrap/app_bootstrap.dart';
import 'navigation/app_route_observer.dart';
import 'theme/app_colors.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';
import '../features/announcements/announcements_page.dart';
import '../features/certification/bind_card_page.dart';
import '../features/certification/certification_page.dart';
import '../features/certification/emergency_contact_page.dart';
import '../features/certification/face_recognition_page.dart';
import '../features/certification/identity_result_page.dart';
import '../features/certification/identity_type_page.dart';
import '../features/certification/identity_upload_page.dart';
import '../features/certification/personal_information_page.dart';
import '../features/certification/work_information_page.dart';
import '../features/calculator/loan_calculator_binding.dart';
import '../features/calculator/loan_calculator_page.dart';
import '../features/credit_review/credit_review_page.dart';
import '../features/login/login_binding.dart';
import '../features/login/login_page.dart';
import '../features/main_shell/main_binding.dart';
import '../features/main_shell/main_shell_page.dart';
import '../features/mine/account_deletion_page.dart';
import '../features/mine/account_page.dart';
import '../features/orders/orders_page.dart';
import '../features/support/support_page.dart';
import '../features/webview/app_webview_page.dart';
import '../features/webview/payout_accounts_page.dart';

class HandaPesoApp extends StatelessWidget {
  const HandaPesoApp({required this.dependencies, super.key});

  static final TransitionBuilder _easyLoadingBuilder = EasyLoading.init();

  final AppDependencies dependencies;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Handa Peso',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      builder: (context, child) => _easyLoadingBuilder(
        context,
        DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppColors.pageBackgroundGradient,
          ),
          child: child,
        ),
      ),
      navigatorObservers: [appRouteObserver, ScreenViewReporter()],
      initialBinding: MainBinding(appDependencies: dependencies),
      initialRoute: AppRoutes.main,
      getPages: [
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
        GetPage(
          name: AppRoutes.certification,
          page: () => const CertificationPage(),
        ),
        GetPage(
          name: AppRoutes.certificationIdentity,
          page: () => const IdentityTypePage(),
        ),
        GetPage(
          name: AppRoutes.certificationIdentityUpload,
          page: () => const IdentityUploadPage(),
        ),
        GetPage(
          name: AppRoutes.certificationIdentityResult,
          page: () => const IdentityResultPage(),
        ),
        GetPage(
          name: AppRoutes.certificationFace,
          page: () => const FaceRecognitionPage(),
        ),
        GetPage(
          name: AppRoutes.personalInformation,
          page: () => const PersonalInformationPage(),
        ),
        GetPage(
          name: AppRoutes.workInformation,
          page: () => const WorkInformationPage(),
        ),
        GetPage(
          name: AppRoutes.emergencyContact,
          page: () => const EmergencyContactPage(),
        ),
        GetPage(name: AppRoutes.bindCard, page: () => const BindCardPage()),
        GetPage(
          name: AppRoutes.payoutAccounts,
          page: () => const PayoutAccountsPage(),
        ),
        GetPage(
          name: AppRoutes.creditReview,
          page: () => const CreditReviewPage(),
        ),
        GetPage(name: AppRoutes.orders, page: () => const OrdersPage()),
        GetPage(name: AppRoutes.support, page: () => const SupportPage()),
        GetPage(
          name: AppRoutes.announcements,
          page: () => const AnnouncementsPage(),
        ),
        GetPage(name: AppRoutes.account, page: () => const AccountPage()),
        GetPage(
          name: AppRoutes.accountDeletion,
          page: () => const AccountDeletionPage(),
        ),
        GetPage(name: AppRoutes.webView, page: () => const AppWebViewPage()),
      ],
    );
  }
}
