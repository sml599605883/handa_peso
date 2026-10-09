import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/analytics/analytics_service.dart';

/// Hosts legal documents and content pages.
///
/// It is intentionally *not* the app shell: only static/legal content is shown
/// here so the product remains a native application.
class AppWebViewPage extends StatefulWidget {
  const AppWebViewPage({super.key});

  @override
  State<AppWebViewPage> createState() => _AppWebViewPageState();
}

class _AppWebViewPageState extends State<AppWebViewPage> {
  final _progress = 0.0.obs;
  String _title = 'Details';
  String _url = '';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments;
    if (args is Map) {
      _url = args['url']?.toString() ?? '';
      _title = args['title']?.toString() ?? 'Details';
    }
    AnalyticsService.logEvent('webview_open', {'title': _title});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: _url.isEmpty
          ? const Center(child: Text('Nothing to display.'))
          : Stack(
              children: [
                InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_url)),
                  onProgressChanged: (controller, progress) => _progress.value = progress / 100,
                  onReceivedError: (controller, request, error) {
                    if (request.isForMainFrame ?? false) {
                      setState(() => _failed = true);
                    }
                  },
                  onLoadStop: (controller, url) {
                    if (_failed) setState(() => _failed = false);
                  },
                ),
                Obx(
                  () => _progress.value >= 1
                      ? const SizedBox.shrink()
                      : LinearProgressIndicator(
                          value: _progress.value,
                          minHeight: 3,
                          backgroundColor: AppColors.surfaceMuted,
                        ),
                ),
                if (_failed)
                  ColoredBox(
                    color: AppColors.surface,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textMuted),
                            const SizedBox(height: AppSpacing.sm),
                            const Text('This page could not be loaded.'),
                            const SizedBox(height: AppSpacing.md),
                            FilledButton(
                              onPressed: () => setState(() => _failed = false),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
