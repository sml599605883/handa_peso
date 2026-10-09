import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../app/navigation/app_navigator.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../main_shell/main_shell_page.dart';
import 'order_item.dart';

/// Order list with explicit loading, error and empty states.
class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  late final ApiClient _apiClient = Get.find<ApiClient>();

  List<OrderItem>? _orders;
  String? _error;
  bool _loading = true;
  bool _needsLogin = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final sessionId = await _apiClient.config.sessionStore.sessionId();
      if (sessionId.isEmpty) {
        if (!mounted) return;
        setState(() {
          _needsLogin = true;
          _loading = false;
        });
        return;
      }
      final response = await _apiClient.get(ApiEndpoints.orderList);
      final items = response.data['list'] is List
          ? (response.data['list'] as List)
              .whereType<Map<String, dynamic>>()
              .map(OrderItem.fromJson)
              .toList()
          : <OrderItem>[];
      if (!mounted) return;
      setState(() {
        _orders = items;
        _needsLogin = false;
        _loading = false;
      });
    } on ApiException catch (error) {
      CrashReporter.record(error, StackTrace.current);
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ShellAppBar(title: 'My orders'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_needsLogin) {
      return AppEmptyState(
        icon: Icons.lock_outline_rounded,
        title: 'Sign in to view your orders',
        description: 'You can browse offers as a guest. Signing in shows your loans.',
        action: FilledButton(
          key: const Key('orders-sign-in'),
          onPressed: () async {
            final signedIn = await AppNavigator.toLogin();
            if (signedIn && mounted) _load();
          },
          child: const Text('Sign in'),
        ),
      );
    }
    if (_error != null) {
      return AppEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load your orders',
        description: _error,
        action: FilledButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    final orders = _orders ?? const <OrderItem>[];
    if (orders.isEmpty) {
      return AppEmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No orders yet',
        description: 'Apply for a loan from the home page to get started.',
        action: FilledButton(
          onPressed: _load,
          child: const Text('Refresh'),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: orders.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) => _OrderCard(order: orders[index]),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final OrderItem order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final due = order.dueDate;
    final dateLabel = due == null ? '-' : DateFormat('yyyy-MM-dd').format(due);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(order.productTitle, style: textTheme.titleMedium)),
                _StatusChip(order: order),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(order.amount.format(), style: textTheme.headlineSmall),
            const SizedBox(height: AppSpacing.xs),
            Text('Order ${order.orderNo}', style: textTheme.bodySmall),
            Text(
              'Due $dateLabel',
              style: textTheme.bodySmall?.copyWith(
                color: order.isOverdue ? AppColors.danger : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.order});

  final OrderItem order;

  @override
  Widget build(BuildContext context) {
    final color = switch (order.status) {
      OrderStatus.settled => AppColors.success,
      OrderStatus.overdue => AppColors.danger,
      OrderStatus.repaying || OrderStatus.disbursing => AppColors.info,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs, vertical: AppSpacing.xxs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        order.isOverdue ? OrderStatus.overdue.label : order.status.label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
