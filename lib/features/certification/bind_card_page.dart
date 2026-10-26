import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_text_selection_menu.dart';
import '../../app/widgets/ios_permission_prompt.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/face/face_liveness_bridge.dart';
import '../../core/json/json_utils.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../../core/network/gateway_reply.dart';
import '../../core/permissions/permission_coordinator.dart';
import '../../core/product/product_detail_loader.dart';
import '../../core/report/report_scene.dart';
import '../../core/report/report_service.dart';
import 'bind_card_design.dart';
import 'bind_card_models.dart';
import 'face_models.dart';
import 'identity_design.dart';
import 'personal_information_models.dart';
import 'widgets/certification_progress_bar.dart';
import 'widgets/personal_information_selectors.dart';

typedef BindCardCameraPermission = Future<PermissionDecision> Function();
typedef BindCardLivenessStart = Future<FaceLivenessResult> Function(
  String license,
);
typedef BindCardLivenessConfirmation = Future<bool> Function(
  BuildContext context,
);

enum _BindCardLoadState { loading, content, empty, error }

/// 放款账户绑定页（设计稿 03-05）。
///
/// 页面字段与分组完全由 `card-init` 下发；提交时按 Handa 的混淆字段映射，
/// 服务端返回 `20000` 时完成绑卡专用活体校验并携带结果二次提交。
class BindCardPage extends StatefulWidget {
  const BindCardPage({
    this.apiClient,
    this.reporter,
    this.autoContinue = true,
    this.orderNo = '',
    this.changeOrderNo = '',
    this.requestCameraPermission,
    this.startLiveness,
    this.confirmLiveness,
    super.key,
  });

  final GatewayClient? apiClient;
  final ReportService? reporter;
  final bool autoContinue;
  final String orderNo;

  /// 非空表示这是换绑流程；绑卡成功后会调用更换账户接口。
  final String changeOrderNo;

  final BindCardCameraPermission? requestCameraPermission;
  final BindCardLivenessStart? startLiveness;
  final BindCardLivenessConfirmation? confirmLiveness;

  @override
  State<BindCardPage> createState() => _BindCardPageState();
}

class _BindCardPageState extends State<BindCardPage> {
  static const Map<String, String> _submitKeys = <String, String>{
    'channelCode': 'voraciousness',
    'firstName': 'advisements',
    'middleName': 'chyme',
    'lastName': 'recusant',
    'cardNo': 'thermographs',
    'confirmCardNo': 'lander',
  };

  late final GatewayClient _apiClient =
      widget.apiClient ?? Get.find<GatewayClient>();
  late final ReportService? _reporter =
      widget.reporter ??
      (Get.isRegistered<ReportService>() ? Get.find<ReportService>() : null);
  late final BindCardFlowOutcome? _outcome = BindCardFlowOutcome.of(
    Get.arguments,
  );
  late final int _sceneStartedAt = ReportService.nowSeconds();
  late final PermissionCoordinator _permissions = PermissionCoordinator();

  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  final Map<String, FocusNode> _focusNodes = <String, FocusNode>{};
  final Map<String, String> _values = <String, String>{};

  _BindCardLoadState _loadState = _BindCardLoadState.loading;
  BindCardData? _data;
  String _productId = '';
  String _orderNo = '';
  String _changeOrderNo = '';
  String _selectedType = '';
  String _error = '';
  String? _activeSuggestionKey;
  bool _submitting = false;

  BindCardGroup? get _selectedGroup {
    final data = _data;
    if (data == null || data.groups.isEmpty) return null;
    for (final group in data.groups) {
      if (group.type == _selectedType) return group;
    }
    return data.groups.first;
  }

  BindCardGroup? get _group => _selectedGroup;

  bool get _hasContent =>
      _loadState == _BindCardLoadState.content &&
      (_group?.fields.isNotEmpty ?? false);

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    if (arguments is Map) {
      _productId = arguments['productId']?.toString().trim() ?? '';
      _orderNo = arguments['orderNo']?.toString().trim() ?? '';
      _changeOrderNo = arguments['changeOrderNo']?.toString().trim() ?? '';
    }
    _orderNo = widget.orderNo.trim().isEmpty ? _orderNo : widget.orderNo.trim();
    _changeOrderNo = widget.changeOrderNo.trim().isEmpty
        ? _changeOrderNo
        : widget.changeOrderNo.trim();
    unawaited(_load());
  }

  @override
  void dispose() {
    _disposeEditors();
    super.dispose();
  }

  Future<void> _load() async {
    if (_productId.isEmpty) {
      setState(() {
        _error = 'Product information is unavailable';
        _loadState = _BindCardLoadState.error;
      });
      return;
    }
    setState(() {
      _loadState = _BindCardLoadState.loading;
      _error = '';
    });
    try {
      final reply = await _apiClient.fetchCardForm(productId: _productId);
      reply.orThrow();
      final data = BindCardData.fromReply(reply);
      if (!mounted) return;
      _disposeEditors();
      _createEditors(data);
      final first = data.groups.firstOrNull;
      setState(() {
        _data = data;
        _selectedType = first?.type ?? '';
        _activeSuggestionKey = null;
        _loadState = data.groups.isEmpty
            ? _BindCardLoadState.empty
            : _BindCardLoadState.content;
      });
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loadState = _BindCardLoadState.error;
      });
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load payout accounts';
        _loadState = _BindCardLoadState.error;
      });
    }
  }

  void _createEditors(BindCardData data) {
    for (final group in data.groups) {
      for (final field in group.fields) {
        final key = _fieldKey(group, field);
        final initial = _initialDisplay(field);
        final controller = TextEditingController(text: initial.display);
        final focusNode = FocusNode();
        if (field.control == BindCardFieldControl.text) {
          controller.addListener(_updateActiveSuggestion);
          focusNode.addListener(_updateActiveSuggestion);
        }
        _controllers[key] = controller;
        _focusNodes[key] = focusNode;
        _values[key] = initial.value;
      }
    }
  }

  void _disposeEditors() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _controllers.clear();
    _focusNodes.clear();
    _values.clear();
  }

  ({String value, String display}) _initialDisplay(BindCardField field) {
    final initial = field.initialValue.trim();
    if (field.control == BindCardFieldControl.text) {
      return (value: initial, display: initial);
    }
    for (final option in field.options) {
      if (option.label == initial || option.value == initial) {
        return (value: option.value, display: option.label);
      }
    }
    return (value: initial, display: initial);
  }

  void _selectGroup(BindCardGroup group) {
    if (_selectedType == group.type || _submitting) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedType = group.type;
      _activeSuggestionKey = null;
    });
  }

  void _onTextChanged(BindCardGroup group, BindCardField field, String value) {
    final key = _fieldKey(group, field);
    _values[key] = value;
    _updateActiveSuggestion();
  }

  void _updateActiveSuggestion() {
    if (!mounted) return;
    final data = _data;
    final group = _selectedGroup;
    if (data == null || group == null) return;

    String? nextKey;
    for (final field in group.fields) {
      if (field.control != BindCardFieldControl.text) continue;
      final key = _fieldKey(group, field);
      final controller = _controllers[key];
      if (_focusNodes[key]?.hasFocus != true ||
          controller == null ||
          controller.text.trim().isNotEmpty ||
          field.suggestedValue.isEmpty) {
        continue;
      }
      nextKey = key;
      break;
    }
    if (_activeSuggestionKey != nextKey) {
      setState(() => _activeSuggestionKey = nextKey);
    }
  }

  void _applySuggestions(BindCardGroup group) {
    FocusManager.instance.primaryFocus?.unfocus();
    for (final field in group.fields) {
      if (field.control != BindCardFieldControl.text ||
          field.suggestedValue.isEmpty) {
        continue;
      }
      final key = _fieldKey(group, field);
      final controller = _controllers[key];
      if (controller == null || controller.text.trim().isNotEmpty) continue;
      controller.text = field.suggestedValue;
      _values[key] = field.suggestedValue;
    }
    if (mounted) setState(() => _activeSuggestionKey = null);
  }

  Future<void> _pickOption(BindCardGroup group, BindCardField field) async {
    if (field.options.isEmpty || _submitting) return;
    final key = _fieldKey(group, field);
    final selected = await showPersonalInformationOptionSheet(
      context: context,
      title: field.title,
      options: field.options
          .map(
            (option) => PersonalInformationOption(
              label: option.label,
              value: option.value,
              logoUrl: option.logoUrl,
            ),
          )
          .toList(growable: false),
      selectedValue: _values[key],
    );
    if (selected == null || !mounted) return;
    final controller = _controllers[key];
    controller?.text = selected.label;
    setState(() => _values[key] = selected.value);
  }

  Future<void> _submit() async {
    final group = _group;
    if (_submitting || group == null || _productId.isEmpty) return;
    final fields = <String, String>{
      for (final field in group.fields)
        field.key: (_values[_fieldKey(group, field)] ?? '').trim(),
    };
    final account = fields['cardNo'];
    final confirmation = fields['confirmCardNo'];
    if (account != null && confirmation != null && account != confirmation) {
      AppNavigator.showError('Account numbers do not match');
      return;
    }

    setState(() => _submitting = true);
    await AppNavigator.showLoading();
    try {
      var reply = await _submitBinding(group, fields);
      if (reply.status == 20000) {
        await AppNavigator.dismissLoading();
        if (!mounted) return;
        final livenessReply = await _completeLiveness(group, fields);
        if (livenessReply == null) return;
        reply = livenessReply;
      }
      reply.orThrow();
      await _handleSuccess(group, reply);
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await AppNavigator.dismissLoading();
      if (mounted) AppNavigator.showError(error.message);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await AppNavigator.dismissLoading();
      if (mounted) {
        AppNavigator.showError(
          'Unable to save your payout account. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<GatewayReply> _submitBinding(
    BindCardGroup group,
    Map<String, String> fields, {
    String livenessType = '',
    String livenessId = '',
    String license = '',
  }) {
    final body = <String, dynamic>{
      'cotype': _productId,
      'scarriest': group.type,
      for (final entry in fields.entries)
        (_submitKeys[entry.key] ?? entry.key): entry.value,
      'esplanades': livenessType,
      'debater': livenessId,
      'attach': '',
      'outcrowing': '',
      'wowsers': license,
    };
    return _apiClient.submitCardBinding(body: body);
  }

  Future<GatewayReply?> _completeLiveness(
    BindCardGroup group,
    Map<String, String> fields,
  ) async {
    final confirmed = await (widget.confirmLiveness ?? _confirmLiveness)(
      context,
    );
    if (!confirmed || !mounted) return null;

    final permission =
        await (widget.requestCameraPermission ?? _permissions.requestCamera)();
    if (!mounted) return null;
    if (permission != PermissionDecision.granted) {
      final openSettings = await showIosPermissionPrompt(
        context,
        title: 'Allow Camera Access',
        message:
            'Camera access is required to verify your identity before '
            'binding this payout account.',
      );
      if (openSettings) await _permissions.openSettings();
      return null;
    }

    await AppNavigator.showLoading('Preparing verification...');
    try {
      final orderNo = await _resolveOrderNo();
      if (orderNo.isEmpty) {
        throw const GatewayFailure('Order information is unavailable');
      }
      final tokenReply = await _apiClient.fetchLivenessToken(
        orderNo: orderNo,
        livenessType: '1',
      );
      tokenReply.orThrow();
      final token = FaceTokenResult.fromReply(tokenReply);
      if (!token.isReady) {
        throw GatewayFailure(
          token.error.isEmpty
              ? 'Unable to start face verification'
              : token.error,
        );
      }

      await AppNavigator.dismissLoading();
      final result =
          await (widget.startLiveness ?? FaceLivenessBridge.instance.start)(
            token.license,
          );
      unawaited(_reportLivenessResult(result));
      if (result.livenessId.trim().isEmpty) {
        throw GatewayFailure(
          result.message.isEmpty
              ? 'Liveness verification failed'
              : result.message,
        );
      }
      await AppNavigator.showLoading();
      return await _submitBinding(
        group,
        fields,
        livenessType: '7',
        livenessId: result.livenessId,
        license: token.license,
      );
    } finally {
      await AppNavigator.dismissLoading();
    }
  }

  Future<bool> _confirmLiveness(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Security check required'),
            content: const Text(
              'For your security, a quick face check is required before '
              'this payout account can be used.',
            ),
            actions: <Widget>[
              TextButton(
                key: const Key('bind-card-liveness-cancel'),
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Not Now'),
              ),
              TextButton(
                key: const Key('bind-card-liveness-confirm'),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String> _resolveOrderNo() async {
    final explicit = _orderNo.trim();
    if (explicit.isNotEmpty) return explicit;
    final cached = _apiClient.settings.localSession.productFlowOrderNo.trim();
    if (cached.isNotEmpty) return cached;
    try {
      await ProductDetailLoader.load(_apiClient, productId: _productId);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
    }
    return _apiClient.settings.localSession.productFlowOrderNo.trim();
  }

  Future<void> _reportLivenessResult(FaceLivenessResult result) async {
    try {
      await _apiClient.reportLivenessDecision(
        livenessId: result.livenessId,
        requestId: result.requestId,
        resultCode: '${result.code}',
        resultJson: result.rawJson.isEmpty ? '{}' : result.rawJson,
      );
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
    }
  }

  Future<void> _handleSuccess(BindCardGroup group, GatewayReply reply) async {
    final bindId = reply.payload.stringValue('eyeglasses').trim();
    _outcome
      ?..completed = true
      ..bindId = bindId;

    final changeOrderNo = _changeOrderNo.trim();
    if (changeOrderNo.isNotEmpty) {
      if (bindId.isEmpty) {
        throw const GatewayFailure('The bound account information is missing');
      }
      final changed = await _apiClient.switchPayoutCard(
        orderNo: changeOrderNo,
        cardId: bindId,
      );
      changed.orThrow();
      final redirectUrl = changed.payload.stringValue('proclises').trim();
      _outcome
        ?..changed = true
        ..redirectUrl = redirectUrl;
      if (redirectUrl.isEmpty) {
        throw const GatewayFailure('Unable to open the updated order');
      }
      await AppNavigator.dismissLoading();
      if (mounted) Get.back<void>();
      return;
    }

    await AppNavigator.dismissLoading();
    unawaited(
      _reporter?.reportScene(
        scene: ReportScene.bankCard,
        productId: _productId,
        startedAtSeconds: _sceneStartedAt,
      ),
    );
    AnalyticsService.logEvent(AppEvents.certificationStepCompleted, {
      'step': 'Payout account',
      'accountType': group.label,
    });
    if (!mounted) return;
    if (widget.autoContinue && _productId.isNotEmpty) {
      await AppNavigator.continueProductCertification(productId: _productId);
    } else {
      Get.back<void>();
    }
  }

  @override
  Widget build(BuildContext context) {
    final group = _group;
    final showsHint = group != null && _groupHint(group).isNotEmpty;

    return IdentityPageScaffold(
      gradient: AppColors.facePageGradient,
      builder: (context, metrics) => Column(
        key: const Key('bind-card-page'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          IdentityPageHeader(metrics: metrics, title: 'Withdrawal Info'),
          SizedBox(height: metrics.size(12)),
          IdentityHeroBanner(
            text: _heroCopy,
            metrics: metrics,
            top: SizedBox(
              width: metrics.size(BindCardDesign.progressWidth),
              child: CertificationProgressBar(
                metrics: metrics,
                activeSegments: 4,
              ),
            ),
            maxLines: 3,
            minFontSize: 14,
            maxFontSize: 20,
          ),
          SizedBox(height: metrics.size(36)),
          if (_data?.groups.isNotEmpty ?? false) ...<Widget>[
            SizedBox(
              height: metrics.size(BindCardDesign.typeHeight),
              child: _typeSelector(metrics, _data!.groups),
            ),
            SizedBox(height: metrics.size(14)),
          ],
          _formCard(metrics, group, showsHint),
          SizedBox(height: metrics.size(BindCardDesign.alertTopGap)),
          _alert(metrics),
          SizedBox(height: metrics.size(BindCardDesign.submitTopGap)),
          Center(
            child: IdentitySubmitButton(
              key: const Key('bind-card-submit'),
              metrics: metrics,
              label: 'Submit',
              onPressed: _hasContent && !_submitting ? _submit : null,
            ),
          ),
        ],
      ),
    );
  }

  String get _heroCopy {
    final cached =
        _apiClient.settings.localSession.productFlowCopy.payoutAccount;
    if (cached.isNotEmpty) return cached;
    final prompt = _data?.prompt.trim() ?? '';
    return prompt.isEmpty ? BindCardDesign.defaultHeroCopy : prompt;
  }

  Widget _typeSelector(IdentityMetrics metrics, List<BindCardGroup> groups) {
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.none,
      itemCount: groups.length,
      separatorBuilder: (_, _) =>
          SizedBox(width: metrics.size(BindCardDesign.typeGap)),
      itemBuilder: (context, index) {
        final group = groups[index];
        final selected = group.type == _selectedType;
        final artwork = BindCardAssets
            .typeArtwork[index % BindCardAssets.typeArtwork.length];
        return GestureDetector(
          key: Key('bind-card-type-$index'),
          behavior: HitTestBehavior.opaque,
          onTap: () => _selectGroup(group),
          child: Container(
            width: metrics.size(BindCardDesign.typeWidth),
            height: metrics.size(BindCardDesign.typeHeight),
            padding: EdgeInsets.only(
              top: metrics.size(selected ? 9 : 11),
              left: metrics.size(6),
              right: metrics.size(6),
              bottom: metrics.size(7),
            ),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.surface
                  : AppColors.bindCardTypeIdleSurface,
              borderRadius: BorderRadius.circular(
                metrics.size(BindCardDesign.typeRadius),
              ),
              border: Border.all(
                color: AppColors.identityCardBorder,
                width: metrics.size(1),
              ),
            ),
            child: Column(
              children: <Widget>[
                Image.asset(
                  selected ? artwork.selected : artwork.unselected,
                  key: Key('bind-card-type-icon-$index'),
                  width: metrics.size(artwork.width),
                  height: metrics.size(artwork.height),
                  fit: BoxFit.contain,
                ),
                SizedBox(height: metrics.size(selected ? 6 : 7)),
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        group.label,
                        maxLines: 1,
                        style: TextStyle(
                          color: selected
                              ? AppColors.bindCardSelectedText
                              : AppColors.bindCardTypeIdleText,
                          fontFamily: 'Helvetica',
                          fontSize: metrics.size(BindCardDesign.typeLabelSize),
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.normal,
                          height:
                              BindCardDesign.typeLabelHeight /
                              BindCardDesign.typeLabelSize,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _formCard(
    IdentityMetrics metrics,
    BindCardGroup? group,
    bool showsHint,
  ) {
    return Container(
      key: const Key('bind-card-form'),
      constraints:
          (group == null ||
              _loadState == _BindCardLoadState.loading ||
              _loadState == _BindCardLoadState.error ||
              _loadState == _BindCardLoadState.empty)
          ? BoxConstraints(minHeight: metrics.size(180))
          : null,
      padding: EdgeInsets.symmetric(
        horizontal: metrics.size(BindCardDesign.cardPadding),
        vertical: metrics.size(BindCardDesign.cardPaddingY),
      ),
      decoration: BoxDecoration(
        color: AppColors.identityCardSurface,
        borderRadius: BorderRadius.circular(
          metrics.size(BindCardDesign.cardRadius),
        ),
        border: Border.all(
          color: AppColors.identityCardBorder,
          width: metrics.size(1),
        ),
      ),
      child: _formContent(metrics, group, showsHint),
    );
  }

  Widget _formContent(
    IdentityMetrics metrics,
    BindCardGroup? group,
    bool showsHint,
  ) {
    if (_loadState == _BindCardLoadState.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadState == _BindCardLoadState.error ||
        _loadState == _BindCardLoadState.empty) {
      final message = _loadState == _BindCardLoadState.error
          ? _error
          : 'No payout methods available';
      return Center(
        child: TextButton.icon(
          key: const Key('bind-card-retry'),
          onPressed: _load,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(message, textAlign: TextAlign.center),
        ),
      );
    }
    if (group == null) return const SizedBox.shrink();

    final children = <Widget>[
      SizedBox(
        height: metrics.size(BindCardDesign.labelHeight),
        child: Text(
          'Select your recipient ${group.label}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.personalInformationLabel,
            fontFamily: 'Helvetica',
            fontSize: metrics.size(BindCardDesign.labelSize),
            height: 20 / BindCardDesign.labelSize,
          ),
        ),
      ),
    ];
    for (var index = 0; index < group.fields.length; index++) {
      final field = group.fields[index];
      children
        ..add(
          SizedBox(
            height: metrics.size(
              index == 0 ? BindCardDesign.fieldGap : BindCardDesign.fieldPitch,
            ),
          ),
        )
        ..add(_fieldTile(metrics, group, field, showLabel: index != 0));
      if (index == 0 && showsHint) {
        children
          ..add(SizedBox(height: metrics.size(BindCardDesign.groupHintTopGap)))
          ..add(
            SizedBox(
              height: metrics.size(BindCardDesign.groupHintHeight),
              child: Text(
                _groupHint(group),
                key: const Key('bind-card-group-hint'),
                maxLines: 2,
                style: TextStyle(
                  color: AppColors.bindCardSelectedText,
                  fontFamily: 'Helvetica',
                  fontSize: metrics.size(10),
                  height: 12 / 10,
                ),
              ),
            ),
          );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    );
  }

  String _groupHint(BindCardGroup group) {
    if (group.hint.isNotEmpty) return group.hint;
    return group.type == '3' ? BindCardDesign.cashHintCopy : '';
  }

  Widget _fieldTile(
    IdentityMetrics metrics,
    BindCardGroup group,
    BindCardField field, {
    required bool showLabel,
  }) {
    final key = _fieldKey(group, field);
    final controller = _controllers[key]!;
    final suggestionKey = _activeSuggestionKey == key;
    return Column(
      key: ValueKey<String>('bind-card-field-$key'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showLabel) ...<Widget>[
          SizedBox(
            height: metrics.size(BindCardDesign.labelHeight),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    field.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.personalInformationLabel,
                      fontFamily: 'Helvetica',
                      fontSize: metrics.size(BindCardDesign.labelSize),
                      height: 20 / BindCardDesign.labelSize,
                    ),
                  ),
                ),
                if (suggestionKey)
                  _SuggestionBubble(
                    label: field.suggestedValue,
                    metrics: metrics,
                    key: Key('bind-card-suggestion-$key'),
                    onTap: () => _applySuggestions(group),
                  ),
              ],
            ),
          ),
          SizedBox(height: metrics.size(BindCardDesign.fieldGap)),
        ],
        SizedBox(
          height: metrics.size(BindCardDesign.fieldHeight),
          child: field.control == BindCardFieldControl.text
              ? _textField(metrics, group, field, controller)
              : _selectionField(metrics, group, field, controller),
        ),
      ],
    );
  }

  Widget _textField(
    IdentityMetrics metrics,
    BindCardGroup group,
    BindCardField field,
    TextEditingController controller,
  ) {
    final key = _fieldKey(group, field);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(
          metrics.size(BindCardDesign.fieldRadius),
        ),
      ),
      child: TextField(
        key: Key('bind-card-input-$key'),
        controller: controller,
        focusNode: _focusNodes[key],
        contextMenuBuilder: AppTextSelectionMenu.build,
        keyboardType: field.numeric ? TextInputType.number : TextInputType.text,
        inputFormatters: field.numeric
            ? <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly]
            : null,
        onChanged: (value) => _onTextChanged(group, field, value),
        style: TextStyle(
          color: AppColors.personalInformationValue,
          fontFamily: 'Helvetica',
          fontSize: metrics.size(BindCardDesign.fieldSize),
          fontWeight: FontWeight.w700,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          filled: false,
          hintText: _fieldHint(field),
          hintStyle: TextStyle(
            color: AppColors.personalInformationHint,
            fontFamily: 'Helvetica',
            fontSize: metrics.size(BindCardDesign.fieldSize),
            fontWeight: FontWeight.normal,
          ),
          contentPadding: EdgeInsets.fromLTRB(
            metrics.size(20),
            metrics.size(14),
            metrics.size(20),
            metrics.size(14),
          ),
        ),
      ),
    );
  }

  Widget _selectionField(
    IdentityMetrics metrics,
    BindCardGroup group,
    BindCardField field,
    TextEditingController controller,
  ) {
    final key = _fieldKey(group, field);
    final value = controller.text.trim();
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(
        metrics.size(BindCardDesign.fieldRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('bind-card-select-$key'),
        onTap: field.options.isEmpty ? null : () => _pickOption(group, field),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: metrics.size(20)),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  value.isEmpty ? _fieldHint(field) : value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: value.isEmpty
                        ? AppColors.personalInformationHint
                        : AppColors.personalInformationValue,
                    fontFamily: 'Helvetica',
                    fontSize: metrics.size(BindCardDesign.fieldSize),
                    fontWeight: value.isEmpty
                        ? FontWeight.normal
                        : FontWeight.w700,
                  ),
                ),
              ),
              Image.asset(
                BindCardAssets.fieldChevron,
                width: metrics.size(6),
                height: metrics.size(12),
                fit: BoxFit.contain,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fieldHint(BindCardField field) {
    final placeholder = field.placeholder.trim();
    if (placeholder.isNotEmpty) return placeholder;
    return field.control == BindCardFieldControl.text
        ? 'Please enter'
        : 'Please select';
  }

  Widget _alert(IdentityMetrics metrics) {
    final copy = _data?.bottomPrompt.trim() ?? '';
    return Container(
      key: const Key('bind-card-bottom-prompt'),
      constraints: BoxConstraints(
        minHeight: metrics.size(BindCardDesign.alertHeight),
      ),
      alignment: Alignment.center,
      padding: EdgeInsets.symmetric(horizontal: metrics.size(14)),
      decoration: BoxDecoration(
        color: AppColors.bindCardHintSurface,
        borderRadius: BorderRadius.circular(
          metrics.size(BindCardDesign.alertRadius),
        ),
      ),
      child: Text(
        copy.isEmpty ? BindCardDesign.alertCopy : copy,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.bindCardSelectedText,
          fontFamily: 'Helvetica',
          fontSize: metrics.size(BindCardDesign.alertTextSize),
          height: BindCardDesign.alertTextHeight / BindCardDesign.alertTextSize,
        ),
      ),
    );
  }

  String _fieldKey(BindCardGroup group, BindCardField field) {
    return '${group.type}:${field.key}';
  }
}

class _SuggestionBubble extends StatelessWidget {
  const _SuggestionBubble({
    required this.label,
    required this.metrics,
    required this.onTap,
    super.key,
  });

  final String label;
  final IdentityMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bindCardSuggestionSurface,
      borderRadius: BorderRadius.circular(metrics.size(4)),
      child: InkWell(
        borderRadius: BorderRadius.circular(metrics.size(4)),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.size(12),
            vertical: metrics.size(2),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.textOnPrimary,
              fontFamily: 'Helvetica',
              fontSize: metrics.size(12),
              height: 16 / 12,
            ),
          ),
        ),
      ),
    );
  }
}
