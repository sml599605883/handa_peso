import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/layout/responsive_layout.dart';
import '../../app/navigation/app_navigator.dart';
import '../../app/navigation/app_route_observer.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_empty_state.dart';
import '../../app/widgets/design_back_button.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../main_shell/main_controller.dart';
import 'order_card.dart';
import 'order_item.dart';
import 'orders_filter_bar.dart';

/// 订单列表（设计稿 05-01 - 订单列表-有订单 / -暂无订单）。
///
/// 顶部是返回键 + 标题 + 筛选条，下面按筛选状态拉订单卡片；空列表换成设计稿
/// 的插画。跳转地址一律用服务端下发的那一份（卡片 `codesigned`、按钮 `southed`），
/// 客户端不拼 H5 路径。
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  /// 页面标题（设计稿 `Loan List`）。
  static const String title = 'Loan List';

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> with RouteAware {
  /// 返回键与标题（设计稿 24x24 @ y=56、20 号字 @ y=58）。
  static const double _backLeft = 14;
  static const double _backTop = 56;
  static const double _backSize = 24;
  static const double _titleTop = 58;
  static const double _titleHeight = 30;
  static const double _titleSize = 20;

  /// 筛选条与首张卡片（设计稿 347x50 @ y=98、卡片 @ y=168）。
  static const double _filterTop = 98;
  static const double _listTop = 168;
  static const double _cardGap = 16;
  static const double _listBottom = 24;

  /// 空列表插画（设计稿 `box_6` 200x200 @ y=306）。
  static const double _emptyIllustrationTop = 306;
  static const double _emptyIllustrationSize = 200;
  static const String _emptyIllustration =
      'assets/orders_empty_illustration.png';

  static const String _repaymentTitle = 'Repayment';
  static const String _loanDetailTitle = 'Loan detail';

  late final GatewayClient _apiClient = Get.find<GatewayClient>();

  OrderListStatus _selected = OrderListStatus.all;
  List<OrderItem> _items = const <OrderItem>[];
  String? _error;
  bool _loading = true;
  bool _needsLogin = false;

  /// 正在跳转的订单：同一订单连点只保留一次，避免叠出多个落地页。
  final Set<String> _activeActions = <String>{};

  PageRoute<dynamic>? _route;
  bool _returnRefreshScheduled = false;

  /// 请求代号：切换筛选后旧请求的返回结果直接丢弃。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _selected = _initialStatus();
    _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      appRouteObserver.unsubscribe(this);
      _route = route;
      appRouteObserver.subscribe(this, route);
    }
  }

  @override
  void didPopNext() {
    if (_returnRefreshScheduled) return;
    _returnRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _returnRefreshScheduled = false;
      if (!mounted || !(_route?.isCurrent ?? true)) return;
      unawaited(_load());
    });
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  /// 初始筛选状态：来自由个人中心快捷入口或深链传入的 `status` 码。
  OrderListStatus _initialStatus() {
    final arguments = Get.arguments;
    if (arguments is OrderListStatus) return arguments;
    if (arguments is Map) {
      final status = arguments['status'];
      if (status is OrderListStatus) return status;
      if (status is String) return OrderListStatus.fromCode(status);
    }
    return OrderListStatus.all;
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessionId = await _apiClient.settings.localSession.readSessionId();
      if (sessionId.isEmpty) {
        if (!mounted || generation != _generation) return;
        setState(() {
          _needsLogin = true;
          _items = const <OrderItem>[];
          _loading = false;
        });
        return;
      }
      final response = await _apiClient.fetchOrders(status: _selected.code);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = parseOrderItems(response.payload);
        _needsLogin = false;
        _loading = false;
      });
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      if (!mounted || generation != _generation) return;
      setState(() {
        _items = const <OrderItem>[];
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _selectStatus(OrderListStatus status) {
    if (status == _selected) return;
    setState(() => _selected = status);
    _load();
  }

  /// 卡片进订单详情、按钮进还款页，地址都由服务端下发。
  Future<void> _openTarget(OrderItem item, {required bool action}) async {
    final target = (action ? item.actionTarget : item.detailTarget).trim();
    final productId = item.productId.trim();
    final actionId = item.orderNo.trim().isNotEmpty
        ? item.orderNo.trim()
        : '$productId|$target';
    if (!_activeActions.add(actionId)) return;
    try {
      if (target.isNotEmpty) {
        if (action) AnalyticsService.logEvent(AppEvents.repaymentViewed);
        await AppNavigator.openTarget(
          target,
          title: action ? _repaymentTitle : _loanDetailTitle,
        );
      } else if (productId.isNotEmpty) {
        await Get.find<MainController>().applyNow(productId);
      }
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError('Unable to open link');
    } finally {
      _activeActions.remove(actionId);
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

        return DecoratedBox(
          key: const Key('orders-background'),
          decoration: const BoxDecoration(
            gradient: AppColors.accountPageGradient,
          ),
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: metrics.contentWidth,
              height: constraints.maxHeight,
              child: Column(
                children: [
                  SizedBox(height: px(_titleTop + shift)),
                  SizedBox(height: px(_titleHeight), child: _buildTitleBar(px)),
                  SizedBox(height: px(_filterTop - _titleTop - _titleHeight)),
                  OrdersFilterBar(
                    selected: _selected,
                    onSelect: _selectStatus,
                    scale: scale,
                  ),
                  SizedBox(
                    height: px(_listTop - _filterTop - OrdersFilterBar.height),
                  ),
                  Expanded(child: _buildBody(scale)),
                ],
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
              OrdersPage.title,
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

  Widget _buildBody(double scale) {
    double px(num value) => value * scale;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_needsLogin) {
      return AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in to view your orders',
        description: 'Sign in to see your loan records and repayment plans.',
        action: FilledButton(
          key: const Key('orders-sign-in'),
          onPressed: () async {
            final signedIn = await AppNavigator.toLogin();
            if (signedIn && mounted) await _load();
          },
          child: const Text('Sign in'),
        ),
      );
    }
    final error = _error;
    if (error != null) {
      return AppEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'We could not load your loans',
        description: error,
        action: FilledButton(
          key: const Key('orders-retry'),
          onPressed: _load,
          child: const Text('Try again'),
        ),
      );
    }
    if (_items.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              SizedBox(height: px(_emptyIllustrationTop - _listTop)),
              SizedBox(
                width: px(_emptyIllustrationSize),
                height: px(_emptyIllustrationSize),
                child: const Image(
                  key: Key('orders-empty-illustration'),
                  image: AssetImage(_emptyIllustration),
                  fit: BoxFit.fill,
                ),
              ),
              SizedBox(height: px(_listBottom)),
            ],
          ),
        ),
      );
    }

    final gap = px(_cardGap);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: px(_listBottom)),
        itemCount: _items.length,
        itemBuilder: (context, index) {
          final item = _items[index];
          return Padding(
            padding: EdgeInsets.only(bottom: gap),
            child: Center(
              child: OrderCard(
                item: item,
                scale: scale,
                onTap: () => _openTarget(item, action: false),
                onActionTap: () => _openTarget(item, action: true),
              ),
            ),
          );
        },
      ),
    );
  }
}
