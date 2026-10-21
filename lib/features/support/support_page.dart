import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_spacing.dart';
import '../../app/widgets/app_text_selection_menu.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';

/// 客服中心：自助 FAQ 以及原生工单表单。
class SupportPage extends StatefulWidget {
  const SupportPage({super.key});

  @override
  State<SupportPage> createState() => _SupportPageState();
}

class _SupportPageState extends State<SupportPage> {
  static const _faqs = <(String, String)>[
    (
      'Is Handa Peso a lender?',
      'No. Handa Peso is a matchmaking platform that connects you with licensed '
          'lending partners. Loan approval and disbursement are handled by the partner.',
    ),
    (
      'How is my interest calculated?',
      'Offers use a flat rate per 30-day period. Use the calculator to preview the '
          'total repayment before you apply.',
    ),
    (
      'What happens if I pay late?',
      'Late payments may incur additional fees as disclosed in your loan agreement. '
          'Contact support if you are struggling to pay so we can help.',
    ),
  ];

  final _messageController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await Get.find<GatewayClient>().openSupportTicket(description: message);
      AnalyticsService.logEvent(AppEvents.supportTicketCreated);
      _messageController.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ticket submitted. We will reply by SMS.'),
        ),
      );
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Support centre')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        children: [
          Text('Frequently asked', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          for (final faq in _faqs)
            Card(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: ExpansionTile(
                title: Text(faq.$1),
                childrenPadding: const EdgeInsets.fromLTRB(
                  AppSpacing.sm,
                  0,
                  AppSpacing.sm,
                  AppSpacing.sm,
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(faq.$2, style: textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text('Still need help?', style: textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          TextField(
            controller: _messageController,
            contextMenuBuilder: AppTextSelectionMenu.build,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Describe your issue',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _submitting ? null : _submitTicket,
            child: Text(_submitting ? 'Sending...' : 'Submit ticket'),
          ),
        ],
      ),
    );
  }
}
