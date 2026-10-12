import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/routes/app_routes.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/session/session_store.dart';
import '../home/home_data.dart';

/// 管理三 Tab 外壳及共享首页信息流的状态。
class MainController extends GetxController {
  MainController({required this.apiClient, required this.sessionStore});

  final ApiClient apiClient;
  final SessionStore sessionStore;

  final selectedIndex = 0.obs;
  final phoneNumber = ''.obs;
  final homeData = Rxn<HomeData>();
  final homeLoading = false.obs;
  final homeError = RxnString();

  bool _loadedOnce = false;

  @override
  void onInit() {
    super.onInit();
    _restoreProfile();
    loadHome();
  }

  void selectTab(int index) => selectedIndex.value = index;

  Future<void> _restoreProfile() async {
    phoneNumber.value = await sessionStore.phone();
  }

  Future<void> loadHome({bool force = false}) async {
    if (homeLoading.value) return;
    if (_loadedOnce && !force) return;
    homeLoading.value = true;
    homeError.value = null;
    try {
      final response = await apiClient.homePage();
      homeData.value = HomeData.fromJson(response.data);
      _loadedOnce = true;
    } on ApiException catch (error) {
      homeError.value = error.message;
      CrashReporter.record(error, StackTrace.current);
    } finally {
      homeLoading.value = false;
    }
  }

  Future<void> refreshHome() => loadHome(force: true);

  /// 在任意页面登录成功后重新同步游客状态。
  Future<void> onSessionStarted(String phone) async {
    phoneNumber.value = phone;
    _loadedOnce = false;
    await loadHome(force: true);
  }

  Future<void> applyNow(String productId) async {
    AnalyticsService.logEvent(AppEvents.applyNowTapped, {'product_id': productId});
    if (!await AppNavigator.requireSession(redirect: productId)) {
      return;
    }
    final profileComplete = await sessionStore.profileComplete();
    if (!profileComplete) {
      await AppNavigator.toCertification();
      return;
    }
    await AppNavigator.toCalculator();
  }

  Future<void> logout() async {
    try {
      await apiClient.logout();
    } on ApiException catch (error) {
      CrashReporter.record(error, StackTrace.current);
    } finally {
      await sessionStore.clear();
      AnalyticsService.setUserId(null);
      homeData.value = null;
      phoneNumber.value = '';
      _loadedOnce = false;
      await loadHome(force: true);
    }
  }

  Future<void> openAccountDeletion() async {
    await Get.toNamed<void>(AppRoutes.accountDeletion);
  }
}
