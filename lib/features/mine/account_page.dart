import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/layout/responsive_layout.dart';
import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/design_back_button.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_failure.dart';
import '../main_shell/main_controller.dart';
import 'account_retention_dialog.dart';

/// 账号页（设计稿 07-01 - 个人中心-退出，从个人中心的 `Account` 入口进入）。
///
/// 一张卡片：弧形面板上的应用名、版本号、应用图标，以及「Delete Account」与
/// 「Logout」两枚按钮。两个动作都先弹设计稿的挽留弹窗，确认后才真正请求接口；
/// 请求失败只是提示，不清本地会话——注销失败还把账号当成已退出的会误导用户。
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  static const String title = 'Account';
  static const String appName = 'Handa Peso';

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  /// 返回键与标题（设计稿 24x24 @ y=56、20 号字 @ y=58）。
  static const double _backLeft = 14;
  static const double _backTop = 56;
  static const double _backSize = 24;
  static const double _titleTop = 58;
  static const double _titleHeight = 30;
  static const double _titleSize = 20;

  /// 卡片（设计稿 `box_4` @ y=118，347 宽、圆角 14、`#FFF9F2` + `#EBDBCA`）。
  static const double _cardTop = 118;
  static const double _cardRadius = 14;
  static const double _cardBottom = 39;

  /// 弧形面板（设计稿 `block_2` 347x64）与面板上的应用名。
  static const double _curtainHeight = 64;
  static const double _curtainTitleSize = 18;
  static const String _curtainAsset = 'assets/account_curtain_header.png';

  /// 版本号、应用图标（设计稿 205x205）与它们之间的间距。
  static const double _versionGap = 14;
  static const double _versionHeight = 20;
  static const double _versionSize = 16;
  static const double _logoSize = 205;
  static const String _logoAsset = 'assets/account_app_logo.png';

  /// 两枚按钮（设计稿 `group_1` 宽 319，按钮 52 高、圆角 26）。
  static const double _actionsTopGap = 20;
  static const double _actionsWidth = 319;
  static const double _actionHeight = 52;
  static const double _actionRadius = 26;
  static const double _actionGap = 12;
  static const double _actionLabelSize = 18;

  /// 注销成功后的提示：服务端只是受理，删除本身是异步的。
  static const String _deletedHint =
      'Your account deletion request has been submitted.';

  String _version = '';

  /// 请求在途：挡住重复提交。
  bool _exiting = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _version = info.version);
    } catch (error) {
      // 取不到版本号不影响退出 / 注销，静默降级为不显示版本。
      CrashReporter.record(error, StackTrace.current);
    }
  }

  Future<void> _deleteAccount() async {
    final confirmed = await showAccountRetentionDialog(
      context: context,
      action: AccountExitAction.deleteAccount,
    );
    if (confirmed != true || !mounted) return;
    await _run(Get.find<MainController>().deleteAccount, deleted: true);
  }

  Future<void> _logout() async {
    final confirmed = await showAccountRetentionDialog(
      context: context,
      action: AccountExitAction.logout,
    );
    if (confirmed != true || !mounted) return;
    await _run(Get.find<MainController>().logout, deleted: false);
  }

  /// 执行退出 / 注销：成功后才回到外壳并切回首页。
  ///
  /// 受保护的 Tab 在无会话时不允许停留，所以退出后不能把用户留在 Mine Tab。
  Future<void> _run(
    Future<void> Function() request, {
    required bool deleted,
  }) async {
    if (_exiting) return;
    setState(() => _exiting = true);
    await AppNavigator.showLoading();
    try {
      await request();
      await AppNavigator.dismissLoading();
      if (!mounted) return;
      if (deleted) AppNavigator.showToast(_deletedHint);
      AppNavigator.switchMainTab(0);
      Get.back<void>();
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await AppNavigator.dismissLoading();
      AppNavigator.showError(error.message);
    } finally {
      if (mounted) setState(() => _exiting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = AppResponsiveMetrics(
          screenWidth: constraints.maxWidth,
          safeTop: MediaQuery.paddingOf(context).top,
          safeBottom: MediaQuery.paddingOf(context).bottom,
          designHorizontalInset: _backLeft,
        );
        final scale = metrics.scale;
        double px(num value) => value * scale;
        final shift = metrics.headerShift;

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: DecoratedBox(
            key: const Key('account-background'),
            decoration: const BoxDecoration(
              gradient: AppColors.accountPageGradient,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: metrics.safeBottom + px(24)),
              child: Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: metrics.contentWidth,
                  child: Column(
                    children: [
                      SizedBox(height: px(_titleTop + shift)),
                      SizedBox(
                        height: px(_titleHeight),
                        child: _buildTitleBar(px),
                      ),
                      SizedBox(height: px(_cardTop - _titleTop - _titleHeight)),
                      _buildCard(px, scale),
                      SizedBox(height: px(24)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 标题栏：返回键在左，标题在剩余空间居中。
  Widget _buildTitleBar(double Function(num) px) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Transform.translate(
          offset: Offset(0, px(_backTop - _titleTop)),
          child: SizedBox(
            width: px(_backSize),
            height: px(_backSize),
            child: const DesignBackButton(),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              AccountPage.title,
              style: TextStyle(
                color: AppColors.textStrong,
                fontSize: px(_titleSize),
                fontWeight: FontWeight.w700,
                height: _titleHeight / _titleSize,
              ),
            ),
          ),
        ),
        SizedBox(width: px(_backSize)),
      ],
    );
  }

  Widget _buildCard(double Function(num) px, double scale) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.accountCardSurface,
        borderRadius: BorderRadius.circular(px(_cardRadius)),
        border: Border.all(color: AppColors.accountCardBorder, width: px(1)),
      ),
      padding: EdgeInsets.only(bottom: px(_cardBottom)),
      child: Column(
        children: [
          // 弧形面板与面板上的应用名。
          SizedBox(
            width: double.infinity,
            height: px(_curtainHeight),
            child: Stack(
              children: [
                Positioned.fill(
                  child: const Image(
                    image: AssetImage(_curtainAsset),
                    fit: BoxFit.fill,
                  ),
                ),
                Center(
                  child: Text(
                    AccountPage.appName,
                    style: TextStyle(
                      color: AppColors.accountCurtainTitle,
                      fontSize: px(_curtainTitleSize),
                      height: 22 / _curtainTitleSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: px(_versionGap)),
          SizedBox(
            height: px(_versionHeight),
            child: Text(
              _version.isEmpty ? '' : 'V$_version',
              key: const Key('account-version'),
              style: TextStyle(
                color: AppColors.accountVersionLabel,
                fontSize: px(_versionSize),
                height: _versionHeight / _versionSize,
              ),
            ),
          ),
          SizedBox(height: px(_versionGap)),
          SizedBox(
            width: px(_logoSize),
            height: px(_logoSize),
            child: const Image(
              key: Key('account-logo'),
              image: AssetImage(_logoAsset),
              fit: BoxFit.fill,
            ),
          ),
          SizedBox(height: px(_actionsTopGap)),
          SizedBox(
            width: px(_actionsWidth),
            height: px(_actionHeight),
            child: Row(
              children: [
                Expanded(
                  child: _AccountAction(
                    key: const Key('account-delete'),
                    label: 'Delete Account',
                    scale: scale,
                    surface: AppColors.accountMutedAction,
                    onTap: _exiting ? null : _deleteAccount,
                  ),
                ),
                SizedBox(width: px(_actionGap)),
                Expanded(
                  child: _AccountAction(
                    key: const Key('account-logout'),
                    label: 'Logout',
                    scale: scale,
                    gradient: AppColors.accountWarmGradient,
                    onTap: _exiting ? null : _logout,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 卡片上的胶囊按钮：灰色底（注销）或暖橙渐变底（退出登录）。
class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.label,
    required this.scale,
    required this.onTap,
    this.surface,
    this.gradient,
    super.key,
  });

  final String label;
  final double scale;
  final VoidCallback? onTap;
  final Color? surface;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surface,
          gradient: gradient,
          borderRadius: BorderRadius.circular(
            _AccountPageState._actionRadius * scale,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textOnPrimary,
            fontSize: _AccountPageState._actionLabelSize * scale,
            fontWeight: FontWeight.w600,
            height: 25 / _AccountPageState._actionLabelSize,
          ),
        ),
      ),
    );
  }
}
