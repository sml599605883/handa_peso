import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/json/json_utils.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_endpoints.dart';
import '../../core/network/api_exception.dart';
import '../home/home_data.dart';
import '../main_shell/main_shell_page.dart';

/// Fraud-prevention and product announcements.
class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key});

  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  List<Announcement>? _items;
  String? _error;
  bool _loading = true;

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
      final response = await Get.find<ApiClient>().get(ApiEndpoints.announcements);
      final items = response.data.listValue('list').maps.map(Announcement.fromJson).toList();
      if (!mounted) return;
      setState(() {
        _items = items;
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
      appBar: ShellAppBar(title: 'Announcements'),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return AppEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Could not load announcements',
        description: _error,
        action: FilledButton(onPressed: _load, child: const Text('Try again')),
      );
    }
    final items = _items ?? const <Announcement>[];
    if (items.isEmpty) {
      return const AppEmptyState(
        icon: Icons.campaign_rounded,
        title: 'No announcements',
        description: 'Check back later for product and safety updates.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.screenPadding),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        final item = items[index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.article_rounded, color: AppColors.primary),
            title: Text(item.title),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => AppNavigator.toWebView(url: item.url, title: item.title),
          ),
        );
      },
    );
  }
}
