import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import 'payout_account_models.dart';

sealed class PayoutAccountChoice {
  const PayoutAccountChoice();
}

class ExistingPayoutAccount extends PayoutAccountChoice {
  const ExistingPayoutAccount(this.accountId);

  final String accountId;
}

class NewPayoutAccount extends PayoutAccountChoice {
  const NewPayoutAccount();
}

Future<PayoutAccountChoice?> showPayoutAccountSheet(
  BuildContext context,
  PayoutAccountCatalog catalog,
) {
  return showModalBottomSheet<PayoutAccountChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    builder: (context) => _PayoutAccountSheet(catalog: catalog),
  );
}

class _PayoutAccountSheet extends StatefulWidget {
  const _PayoutAccountSheet({required this.catalog});

  final PayoutAccountCatalog catalog;

  @override
  State<_PayoutAccountSheet> createState() => _PayoutAccountSheetState();
}

class _PayoutAccountSheetState extends State<_PayoutAccountSheet> {
  String _selectedId = '';

  @override
  void initState() {
    super.initState();
    for (final account in widget.catalog.accounts) {
      if (account.isPrimary) {
        _selectedId = account.id;
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              AppSpacing.sm,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choose a payout account',
                style: TextStyle(
                  color: AppColors.textStrong,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              children: [
                for (final group in widget.catalog.groups) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.sm,
                      bottom: AppSpacing.xs,
                    ),
                    child: Text(
                      group.title,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  for (final account in group.accounts)
                    _AccountTile(
                      account: account,
                      selected: account.id == _selectedId,
                      onTap: () => setState(() => _selectedId = account.id),
                    ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton(
                  key: const Key('payout-account-add'),
                  onPressed: () =>
                      Navigator.of(context).pop(const NewPayoutAccount()),
                  child: const Text('Add payment method'),
                ),
                const SizedBox(height: AppSpacing.sm),
                FilledButton(
                  key: const Key('payout-account-submit'),
                  onPressed: _selectedId.isEmpty
                      ? null
                      : () =>
                            Navigator.of(context)
                                .pop(ExistingPayoutAccount(_selectedId)),
                  child: const Text('Use selected account'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  const _AccountTile({
    required this.account,
    required this.selected,
    required this.onTap,
  });

  final PayoutAccount account;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          key: Key('payout-account-${account.id}'),
          borderRadius: BorderRadius.circular(AppSpacing.sm),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected ? AppColors.primarySoft : AppColors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppSpacing.sm),
              border: Border.all(
                color: selected ? AppColors.primaryDark : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                if (account.logoUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                    child: Image.network(
                      account.logoUrl,
                      width: 36,
                      height: 36,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) =>
                          const SizedBox.square(dimension: 36),
                    ),
                  )
                else
                  const SizedBox.square(dimension: 36),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        account.bankName,
                        style: const TextStyle(
                          color: AppColors.textStrong,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (account.accountNumber.isNotEmpty)
                        Text(
                          account.accountNumber,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      if (account.holderName.isNotEmpty)
                        Text(
                          account.holderName,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                      if (account.maintenanceNote.isNotEmpty)
                        Text(
                          account.maintenanceNote,
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? AppColors.primaryDark : AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
