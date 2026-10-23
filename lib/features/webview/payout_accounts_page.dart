import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../certification/bind_card_models.dart';
import '../certification/identity_design.dart';
import 'payout_account_design.dart';
import 'payout_account_models.dart';

typedef PayoutAccountSwitcher = Future<String> Function({
  required String orderNo,
  required String cardId,
});
typedef PayoutAccountEditor = Future<BindCardFlowOutcome> Function();

/// 更换放款账户页（设计稿 04-01 - 确认借款-选择其它方式）。
///
/// 页面位于来源 H5 之上。用户选择已有账户或新增账户后，页面只回传新的订单
/// 地址；由来源 WebView 负责替换自身，避免原生页和旧 H5 同时留在路由栈里。
class PayoutAccountsPage extends StatefulWidget {
  const PayoutAccountsPage({
    this.catalog,
    this.productId = '',
    this.orderNo = '',
    this.apiClient,
    this.switchAccount,
    this.addAccount,
    super.key,
  });

  final PayoutAccountCatalog? catalog;
  final String productId;
  final String orderNo;
  final GatewayClient? apiClient;
  final PayoutAccountSwitcher? switchAccount;
  final PayoutAccountEditor? addAccount;

  @override
  State<PayoutAccountsPage> createState() => _PayoutAccountsPageState();
}

class _PayoutAccountsPageState extends State<PayoutAccountsPage> {
  late final PayoutAccountCatalog _catalog;
  late final PayoutAccountFlowOutcome? _outcome;
  late final GatewayClient? _apiClient;
  late final String _productId;
  late final String _orderNo;

  late String _selectedId;
  bool _switching = false;
  bool _addingAccount = false;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    final values = arguments is Map
        ? Map<String, dynamic>.from(arguments)
        : const <String, dynamic>{};
    final argumentCatalog = values['catalog'];
    _catalog =
        widget.catalog ??
        (argumentCatalog is PayoutAccountCatalog
            ? argumentCatalog
            : const PayoutAccountCatalog(<PayoutAccountGroup>[]));
    _outcome = PayoutAccountFlowOutcome.of(arguments);
    _apiClient =
        widget.apiClient ??
        (widget.switchAccount == null ? Get.find<GatewayClient>() : null);
    _productId = widget.productId.trim().isEmpty
        ? values['productId']?.toString().trim() ?? ''
        : widget.productId.trim();
    _orderNo = widget.orderNo.trim().isEmpty
        ? values['orderNo']?.toString().trim() ?? ''
        : widget.orderNo.trim();

    final preferred = _catalog.accounts.firstWhereOrNull(
      (account) => account.isPrimary,
    );
    _selectedId = preferred?.id ?? _catalog.accounts.firstOrNull?.id ?? '';
  }

  Future<void> _submit() async {
    if (_switching || _selectedId.isEmpty || _orderNo.isEmpty) return;
    setState(() => _switching = true);
    await AppNavigator.showLoading();
    try {
      final target = await _switchAccount(_selectedId);
      if (target.isEmpty) {
        throw const GatewayFailure('Updated order link is unavailable');
      }
      AnalyticsService.logEvent(AppEvents.certificationStepCompleted, {
        'step': 'Payout account',
        'action': 'selected_existing',
      });
      _finish(target);
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError(error.message);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError(
        'Unable to change your payout account. Please try again.',
      );
    } finally {
      await AppNavigator.dismissLoading();
      if (mounted) setState(() => _switching = false);
    }
  }

  Future<String> _switchAccount(String cardId) async {
    final switcher = widget.switchAccount;
    if (switcher != null) {
      return switcher(orderNo: _orderNo, cardId: cardId);
    }
    final reply = await _apiClient!.switchPayoutCard(
      orderNo: _orderNo,
      cardId: cardId,
    );
    reply.orThrow();
    return payoutRedirectUrlFrom(reply);
  }

  Future<void> _addAccount() async {
    if (_addingAccount || _switching || _productId.isEmpty) return;
    setState(() => _addingAccount = true);
    try {
      final result =
          await (widget.addAccount?.call() ??
              AppNavigator.toBindCard(
                productId: _productId,
                changeOrderNo: _orderNo,
              ));
      if (!mounted || !result.changed || result.redirectUrl.isEmpty) return;
      AnalyticsService.logEvent(AppEvents.certificationStepCompleted, {
        'step': 'Payout account',
        'action': 'added_new',
      });
      _finish(result.redirectUrl);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError(
        'Unable to add a payout account. Please try again.',
      );
    } finally {
      if (mounted) setState(() => _addingAccount = false);
    }
  }

  void _finish(String redirectUrl) {
    _outcome
      ?..changed = true
      ..redirectUrl = redirectUrl;
    if (Get.key.currentState?.canPop() ?? false) {
      Get.back<void>();
    }
  }

  @override
  Widget build(BuildContext context) {
    return IdentityPageScaffold(
      gradient: AppColors.payoutAccountPageGradient,
      builder: (context, metrics) => Column(
        key: const Key('payout-account-page'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          IdentityPageHeader(metrics: metrics, title: 'Loan details'),
          SizedBox(height: metrics.size(PayoutAccountDesign.bannerTopGap)),
          Semantics(
            button: true,
            label: 'Add other payment methods',
            child: GestureDetector(
              key: const Key('payout-account-add'),
              behavior: HitTestBehavior.opaque,
              onTap: _addAccount,
              child: Image.asset(
                PayoutAccountAssets.addBanner,
                width: double.infinity,
                height: metrics.size(PayoutAccountDesign.bannerHeight),
                fit: BoxFit.fill,
              ),
            ),
          ),
          SizedBox(
            height: metrics.size(PayoutAccountDesign.bannerToFirstSection),
          ),
          if (_catalog.isEmpty)
            _EmptyAccounts(metrics: metrics)
          else
            for (
              var groupIndex = 0;
              groupIndex < _catalog.groups.length;
              groupIndex++
            ) ...<Widget>[
              if (groupIndex > 0)
                SizedBox(
                  height: metrics.size(
                    groupIndex == 1
                        ? PayoutAccountDesign.sectionGap
                        : PayoutAccountDesign.laterSectionGap,
                  ),
                ),
              _SectionTitle(
                title: _catalog.groups[groupIndex].title,
                metrics: metrics,
              ),
              SizedBox(
                height: metrics.size(
                  groupIndex == 0
                      ? PayoutAccountDesign.firstTitleToCardGap
                      : groupIndex == 1
                      ? PayoutAccountDesign.secondTitleToCardGap
                      : PayoutAccountDesign.titleToCardGap,
                ),
              ),
              for (
                var accountIndex = 0;
                accountIndex < _catalog.groups[groupIndex].accounts.length;
                accountIndex++
              ) ...<Widget>[
                _PayoutAccountCard(
                  account: _catalog.groups[groupIndex].accounts[accountIndex],
                  groupTitle: _catalog.groups[groupIndex].title,
                  groupType: _catalog.groups[groupIndex].type,
                  metrics: metrics,
                  selected:
                      _catalog.groups[groupIndex].accounts[accountIndex].id ==
                      _selectedId,
                  onTap: () => setState(
                    () => _selectedId =
                        _catalog.groups[groupIndex].accounts[accountIndex].id,
                  ),
                ),
                if (accountIndex <
                    _catalog.groups[groupIndex].accounts.length - 1)
                  SizedBox(height: metrics.size(12)),
              ],
            ],
          SizedBox(height: metrics.size(PayoutAccountDesign.submitTopGap)),
          Center(
            child: IdentitySubmitButton(
              key: const Key('payout-account-submit'),
              metrics: metrics,
              label: 'Submit',
              width: PayoutAccountDesign.submitWidth,
              onPressed:
                  _selectedId.isNotEmpty && !_switching && !_addingAccount
                  ? _submit
                  : null,
            ),
          ),
          SizedBox(height: metrics.size(PayoutAccountDesign.bottomPadding)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.metrics});

  final String title;
  final IdentityMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: metrics.size(PayoutAccountDesign.sectionTitleHeight),
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: AppColors.identityTitle,
          fontFamily: 'Helvetica',
          fontSize: metrics.size(PayoutAccountDesign.sectionTitleSize),
          fontWeight: FontWeight.w700,
          height:
              PayoutAccountDesign.sectionTitleHeight /
              PayoutAccountDesign.sectionTitleSize,
        ),
      ),
    );
  }
}

class _PayoutAccountCard extends StatelessWidget {
  const _PayoutAccountCard({
    required this.account,
    required this.groupTitle,
    required this.groupType,
    required this.metrics,
    required this.selected,
    required this.onTap,
  });

  final PayoutAccount account;
  final String groupTitle;
  final String groupType;
  final IdentityMetrics metrics;
  final bool selected;
  final VoidCallback onTap;

  bool get _isCashPickup =>
      groupType == '3' || groupTitle.toLowerCase().contains('cash');

  @override
  Widget build(BuildContext context) {
    final hasNote = account.maintenanceNote.isNotEmpty;
    final bodyHeight = hasNote
        ? PayoutAccountDesign.cardBodyWithNoteHeight
        : PayoutAccountDesign.cardBodyHeight;
    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        key: Key('payout-account-card-${account.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: metrics.size(
            PayoutAccountDesign.cardHeaderHeight + bodyHeight,
          ),
          child: Stack(
            children: <Widget>[
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(
                    metrics.size(PayoutAccountDesign.cardRadius),
                  ),
                  child: ColoredBox(
                    color: AppColors.progressCardSurface,
                    child: Column(
                      children: <Widget>[
                        _CardHeader(
                          account: account,
                          metrics: metrics,
                          selected: selected,
                        ),
                        SizedBox(
                          height: metrics.size(bodyHeight),
                          child: _isCashPickup
                              ? _CashDetails(account: account, metrics: metrics)
                              : _AccountDetails(
                                  account: account,
                                  metrics: metrics,
                                  hasNote: hasNote,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(
                        metrics.size(PayoutAccountDesign.cardRadius),
                      ),
                      border: Border.all(
                        color: AppColors.homeCardBorder,
                        width: metrics.size(1),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.account,
    required this.metrics,
    required this.selected,
  });

  final PayoutAccount account;
  final IdentityMetrics metrics;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: metrics.size(PayoutAccountDesign.cardHeaderHeight),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(PayoutAccountAssets.cardHeader, fit: BoxFit.fill),
          Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _BankLogo(account: account, metrics: metrics),
                SizedBox(width: metrics.size(7)),
                Flexible(
                  child: Text(
                    account.bankName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.identityTitle,
                      fontFamily: 'Roboto',
                      fontSize: metrics.size(PayoutAccountDesign.bankNameSize),
                      fontWeight: FontWeight.w400,
                      height: 22 / PayoutAccountDesign.bankNameSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            width: metrics.size(PayoutAccountDesign.checkboxSize),
            height: metrics.size(PayoutAccountDesign.checkboxSize),
            child: Image.asset(
              selected
                  ? PayoutAccountAssets.checkboxSelected
                  : PayoutAccountAssets.checkboxUnselected,
              key: Key(
                selected
                    ? 'payout-account-selected-${account.id}'
                    : 'payout-account-unselected-${account.id}',
              ),
              fit: BoxFit.fill,
            ),
          ),
        ],
      ),
    );
  }
}

class _BankLogo extends StatelessWidget {
  const _BankLogo({required this.account, required this.metrics});

  final PayoutAccount account;
  final IdentityMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final fallback = _initials(account.bankName);
    return Container(
      width: metrics.size(PayoutAccountDesign.logoBoxSize),
      height: metrics.size(PayoutAccountDesign.logoBoxSize),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(metrics.size(8)),
        border: Border.all(color: AppColors.surface),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(metrics.size(4)),
        child: account.logoUrl.isEmpty
            ? _LogoFallback(text: fallback, metrics: metrics)
            : Image.network(
                account.logoUrl,
                width: metrics.size(PayoutAccountDesign.logoSize),
                height: metrics.size(PayoutAccountDesign.logoSize),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _LogoFallback(text: fallback, metrics: metrics),
              ),
      ),
    );
  }

  String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final result = words.map((word) => word[0]).take(3).join().toUpperCase();
    return result.isEmpty ? 'B' : result;
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.text, required this.metrics});

  final String text;
  final IdentityMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.payoutLogoSurface,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: metrics.size(2)),
            child: Text(
              text,
              style: TextStyle(
                color: AppColors.loginAccentText,
                fontSize: metrics.size(10),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountDetails extends StatelessWidget {
  const _AccountDetails({
    required this.account,
    required this.metrics,
    required this.hasNote,
  });

  final PayoutAccount account;
  final IdentityMetrics metrics;
  final bool hasNote;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        top: metrics.size(PayoutAccountDesign.cardPaddingY),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: metrics.size(PayoutAccountDesign.cardPaddingX),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                SizedBox(
                  height: metrics.size(PayoutAccountDesign.accountLabelHeight),
                  child: Text(
                    'Receipt Account',
                    style: TextStyle(
                      color: AppColors.heroLabel,
                      fontFamily: 'Helvetica',
                      fontSize: metrics.size(
                        PayoutAccountDesign.accountLabelSize,
                      ),
                      height:
                          PayoutAccountDesign.accountLabelHeight /
                          PayoutAccountDesign.accountLabelSize,
                    ),
                  ),
                ),
                SizedBox(
                  height: metrics.size(PayoutAccountDesign.accountLabelToValue),
                ),
                SizedBox(
                  height: metrics.size(PayoutAccountDesign.accountValueHeight),
                  child: Text(
                    account.accountNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.identityTitle,
                      fontFamily: 'Roboto',
                      fontSize: metrics.size(
                        PayoutAccountDesign.accountValueSize,
                      ),
                      fontWeight: FontWeight.w500,
                      height:
                          PayoutAccountDesign.accountValueHeight /
                          PayoutAccountDesign.accountValueSize,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (hasNote) ...<Widget>[
            SizedBox(
              height: metrics.size(PayoutAccountDesign.accountValueToDivider),
            ),
            Container(
              height: metrics.size(1),
              margin: EdgeInsets.symmetric(
                horizontal: metrics.size(PayoutAccountDesign.dividerInset),
              ),
              color: AppColors.homeCardDivider,
            ),
            SizedBox(height: metrics.size(PayoutAccountDesign.dividerToNote)),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: metrics.size(PayoutAccountDesign.cardPaddingX),
              ),
              child: SizedBox(
                height: metrics.size(PayoutAccountDesign.noteHeight),
                child: Text(
                  account.maintenanceNote,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.loginAccentText,
                    fontFamily: 'Helvetica',
                    fontSize: metrics.size(12),
                    height: PayoutAccountDesign.noteLineHeight / 12,
                  ),
                ),
              ),
            ),
          ] else
            const Spacer(),
        ],
      ),
    );
  }
}

class _CashDetails extends StatelessWidget {
  const _CashDetails({required this.account, required this.metrics});

  final PayoutAccount account;
  final IdentityMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.size(PayoutAccountDesign.cardPaddingX),
        metrics.size(PayoutAccountDesign.cardPaddingY),
        metrics.size(PayoutAccountDesign.cardPaddingX),
        0,
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _CashName(
                label: 'First Name',
                value: account.holderFirstName,
                metrics: metrics,
              ),
              _CashName(
                label: 'Middle Name',
                value: account.holderMiddleName,
                metrics: metrics,
              ),
              _CashName(
                label: 'Last Name',
                value: account.holderLastName,
                metrics: metrics,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CashName extends StatelessWidget {
  const _CashName({
    required this.label,
    required this.value,
    required this.metrics,
  });

  final String label;
  final String value;
  final IdentityMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          SizedBox(
            height: metrics.size(PayoutAccountDesign.accountLabelHeight),
            child: Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.heroLabel,
                fontFamily: 'Helvetica',
                fontSize: metrics.size(PayoutAccountDesign.accountLabelSize),
                height:
                    PayoutAccountDesign.accountLabelHeight /
                    PayoutAccountDesign.accountLabelSize,
              ),
            ),
          ),
          SizedBox(height: metrics.size(10)),
          SizedBox(
            height: metrics.size(PayoutAccountDesign.accountValueHeight),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  color: AppColors.identityTitle,
                  fontFamily: 'Roboto',
                  fontSize: metrics.size(PayoutAccountDesign.accountValueSize),
                  fontWeight: FontWeight.w500,
                  height:
                      PayoutAccountDesign.accountValueHeight /
                      PayoutAccountDesign.accountValueSize,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyAccounts extends StatelessWidget {
  const _EmptyAccounts({required this.metrics});

  final IdentityMetrics metrics;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: metrics.size(150),
      child: Center(
        child: Text(
          'No payout accounts available',
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: metrics.size(16),
          ),
        ),
      ),
    );
  }
}
