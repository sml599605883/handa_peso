import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_text_selection_menu.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../../core/report/report_scene.dart';
import '../../core/report/report_service.dart';
import 'identity_design.dart';
import 'personal_information_models.dart';
import 'widgets/personal_address_selector.dart';
import 'widgets/certification_progress_bar.dart';
import 'widgets/identity_retention_guard.dart';
import 'widgets/personal_information_selectors.dart';

/// 个人信息与工作信息共用的动态表单页。
///
/// 字段完全由接口动态下发；两种业务形态共用渲染与交互，只切换标题、数据源、
/// 保存接口和埋点场景。保存失败时留在当前页，不向后续认证项推进。
class PersonalInformationPage extends StatefulWidget {
  const PersonalInformationPage({
    this.apiClient,
    this.reporter,
    this.formType = CertificationInformationKind.personal,
    this.autoContinue = true,
    super.key,
  });

  final GatewayClient? apiClient;
  final ReportService? reporter;
  final CertificationInformationKind formType;
  final bool autoContinue;

  @override
  State<PersonalInformationPage> createState() =>
      _PersonalInformationPageState();
}

class _PersonalInformationPageState extends State<PersonalInformationPage>
    with IdentityRetentionGuard<PersonalInformationPage> {
  late final GatewayClient _apiClient =
      widget.apiClient ?? Get.find<GatewayClient>();
  late final int _sceneStartedAt = ReportService.nowSeconds();
  late final PersonalInformationFlowOutcome? _outcome =
      PersonalInformationFlowOutcome.of(Get.arguments);

  final _values = <String, String>{};
  final _displays = <String, String>{};
  final _controllers = <String, TextEditingController>{};

  PersonalInformationData? _data;
  String _productId = '';
  String? _error;
  bool _loading = true;
  bool _submitting = false;

  bool get _isWork => widget.formType == CertificationInformationKind.work;

  /// 个人信息是场景 2，工作信息是场景 3。
  @override
  String get retentionScene => _isWork ? '3' : '2';

  @override
  String get retentionProductId => _productId;

  @override
  GatewayClient get retentionApiClient => _apiClient;

  ReportService? get _reporter {
    if (widget.reporter != null) return widget.reporter;
    return Get.isRegistered<ReportService>() ? Get.find<ReportService>() : null;
  }

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    if (arguments is Map) {
      _productId = arguments['productId']?.toString().trim() ?? '';
    }
    unawaited(_load());
    // 地址目录进页面就预取：点地址字段时直接弹选择器，不必先等接口。
    unawaited(PersonalAddressSelector.prefetch(_apiClient));
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final reply = _isWork
          ? await _apiClient.fetchJobProfile(productId: _productId)
          : await _apiClient.fetchPersonalProfile(productId: _productId);
      reply.orThrow();
      final data = PersonalInformationData.fromReply(reply);
      if (!mounted) return;
      _resetControllers(data);
      setState(() {
        _data = data;
        _loading = false;
      });
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      if (!mounted) return;
      setState(() {
        _error = _isWork
            ? 'Unable to load work information'
            : 'Unable to load personal information';
        _loading = false;
      });
    }
  }

  void _resetControllers(PersonalInformationData data) {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    _controllers.clear();
    _values.clear();
    _displays.clear();
    for (final field in data.fields) {
      _values[field.key] = field.initialSubmitValue;
      _displays[field.key] = field.initialDisplayValue;
      if (field.control == PersonalInformationControl.text) {
        _controllers[field.key] = TextEditingController(
          text: field.initialDisplayValue,
        );
      }
    }
  }

  Future<void> _selectField(PersonalInformationField field) async {
    if (field.control == PersonalInformationControl.selection) {
      await _selectOption(field);
      return;
    }
    if (field.control == PersonalInformationControl.address) {
      await _selectAddress(field);
    }
  }

  Future<void> _selectOption(PersonalInformationField field) async {
    var options = field.options;
    var title = field.title;
    var selected = _values[field.key];
    final labels = <String>[];
    while (true) {
      final result = await showPersonalInformationOptionSheet(
        context: context,
        title: title,
        options: options,
        selectedValue: selected,
      );
      if (result == null || !mounted) return;
      labels.add(result.label);
      if (result.children.isEmpty) {
        setState(() {
          _values[field.key] = result.value;
          _displays[field.key] = labels.join('|');
        });
        return;
      }
      options = result.children;
      title = result.label;
      selected = null;
    }
  }

  Future<void> _selectAddress(PersonalInformationField field) async {
    final value = await PersonalAddressSelector.show(
      context,
      apiClient: _apiClient,
    );
    if (value == null || !mounted) return;
    setState(() {
      _values[field.key] = value;
      _displays[field.key] = value;
    });
  }

  Future<void> _submit() async {
    if (_submitting || _loading || _data == null) return;
    for (final field in _data!.fields) {
      if (!field.isRequired) continue;
      if ((_values[field.key] ?? '').trim().isEmpty) {
        AppNavigator.showError('Please complete ${field.title}');
        return;
      }
    }
    setState(() => _submitting = true);
    await AppNavigator.showLoading();
    try {
      final body = <String, dynamic>{..._values, 'cotype': _productId};
      final reply = _isWork
          ? await _apiClient.submitJobProfile(body: body)
          : await _apiClient.submitPersonalProfile(body: body);
      reply.orThrow();
      await AppNavigator.dismissLoading();
      unawaited(
        _reporter?.reportScene(
          scene: _isWork ? ReportScene.jobInfo : ReportScene.personalInfo,
          productId: _productId,
          startedAtSeconds: _sceneStartedAt,
        ),
      );
      AnalyticsService.logEvent(AppEvents.certificationStepCompleted, {
        'step': _isWork ? 'Work information' : 'Personal details',
      });
      _outcome?.completed = true;
      if (!mounted) return;
      if (widget.autoContinue && _productId.isNotEmpty) {
        await AppNavigator.continueProductCertification(productId: _productId);
      } else {
        Get.back<void>();
      }
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await AppNavigator.dismissLoading();
      if (mounted) AppNavigator.showError(error.message);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await AppNavigator.dismissLoading();
      if (mounted) {
        AppNavigator.showError(
          _isWork
              ? 'Unable to save work information. Please try again.'
              : 'Unable to save personal information. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<void>(
      canPop: retentionCanPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) handleRetentionExit();
      },
      child: IdentityPageScaffold(
        gradient: AppColors.facePageGradient,
        builder: (context, metrics) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            IdentityPageHeader(
              metrics: metrics,
              title: _isWork ? 'Work Information' : 'Identity Information',
              onBack: handleRetentionExit,
            ),
            SizedBox(height: metrics.size(12)),
            IdentityHeroBanner(
              text: _heroCopy,
              metrics: metrics,
              top: SizedBox(
                width: metrics.size(224),
                child: CertificationProgressBar(
                  metrics: metrics,
                  activeSegments: _isWork ? 2 : 1,
                ),
              ),
              maxLines: 3,
              minFontSize: 14,
              maxFontSize: 20,
            ),
            SizedBox(height: metrics.size(36)),
            _buildCard(metrics),
            SizedBox(height: metrics.size(20)),
            Center(
              child: IdentitySubmitButton(
                key: Key(
                  _isWork
                      ? 'work-information-submit'
                      : 'personal-information-submit',
                ),
                metrics: metrics,
                label: 'Submit',
                onPressed: _submitting || _loading || _error != null
                    ? null
                    : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _heroCopy {
    final flowCopy = _apiClient.settings.localSession.productFlowCopy;
    final detailCopy = _isWork ? flowCopy.work : flowCopy.personal;
    if (detailCopy.isNotEmpty) return detailCopy;
    final endpointCopy = _data?.tips.trim() ?? '';
    return endpointCopy.isNotEmpty
        ? endpointCopy
        : 'Tell us more about yourself to speed up your approval.';
  }

  Widget _buildCard(IdentityMetrics metrics) {
    final decoration = BoxDecoration(
      color: AppColors.identityCardSurface,
      borderRadius: BorderRadius.circular(metrics.size(14)),
      border: Border.all(
        color: AppColors.identityCardBorder,
        width: metrics.size(1),
      ),
    );
    if (_loading) {
      return Container(
        constraints: BoxConstraints(minHeight: metrics.size(180)),
        decoration: decoration,
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Container(
        constraints: BoxConstraints(minHeight: metrics.size(180)),
        decoration: decoration,
        child: Center(
          child: TextButton(
            key: Key(
              _isWork ? 'work-information-retry' : 'personal-information-retry',
            ),
            onPressed: _load,
            child: Text(_error!),
          ),
        ),
      );
    }
    final fields = _data?.fields ?? const <PersonalInformationField>[];
    if (fields.isEmpty) {
      return Container(
        constraints: BoxConstraints(minHeight: metrics.size(180)),
        decoration: decoration,
        child: Center(
          child: Text(
            _isWork
                ? 'No work information required'
                : 'No personal information required',
          ),
        ),
      );
    }
    return Container(
      decoration: decoration,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          metrics.size(13),
          metrics.size(19),
          metrics.size(13),
          metrics.size(19),
        ),
        child: Column(
          children: <Widget>[
            for (var index = 0; index < fields.length; index++) ...<Widget>[
              _fieldTile(fields[index], metrics),
              if (index != fields.length - 1)
                SizedBox(height: metrics.size(14)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _fieldTile(PersonalInformationField field, IdentityMetrics metrics) {
    final display = _displays[field.key] ?? '';
    final hint = field.placeholder.isEmpty
        ? 'Please select'
        : field.placeholder;
    final editable = field.control == PersonalInformationControl.text;
    final values = display;
    return Column(
      key: ValueKey<String>('personal-information-field-${field.key}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: metrics.size(20)),
          child: Text(
            field.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.personalInformationLabel,
              fontSize: metrics.size(16),
              height: 20 / 16,
            ),
          ),
        ),
        SizedBox(height: metrics.size(10)),
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: metrics.size(48)),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.personalInformationFieldSurface,
              borderRadius: BorderRadius.circular(metrics.size(10)),
            ),
            child: editable
                ? TextField(
                    key: ValueKey<String>('personal-input-${field.key}'),
                    controller: _controllers[field.key],
                    contextMenuBuilder: AppTextSelectionMenu.build,
                    keyboardType: field.isNumeric
                        ? TextInputType.number
                        : TextInputType.text,
                    inputFormatters: field.isNumeric
                        ? <TextInputFormatter>[
                            FilteringTextInputFormatter.digitsOnly,
                          ]
                        : null,
                    onChanged: (value) => _values[field.key] = value,
                    style: TextStyle(
                      color: AppColors.personalInformationValue,
                      fontSize: metrics.size(16),
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
                      hintText: hint,
                      hintStyle: TextStyle(
                        color: AppColors.personalInformationHint,
                        fontSize: metrics.size(16),
                        fontWeight: FontWeight.normal,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: metrics.size(20),
                      ),
                    ),
                  )
                : InkWell(
                    key: ValueKey<String>('personal-select-${field.key}'),
                    onTap:
                        field.control == PersonalInformationControl.selection ||
                            field.control == PersonalInformationControl.address
                        ? () => _selectField(field)
                        : null,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: metrics.size(20),
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              values.isEmpty ? hint : values,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: values.isEmpty
                                    ? AppColors.personalInformationHint
                                    : AppColors.personalInformationValue,
                                fontSize: metrics.size(16),
                                fontWeight: values.isEmpty
                                    ? FontWeight.normal
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          if (field.control ==
                                  PersonalInformationControl.selection ||
                              field.control ==
                                  PersonalInformationControl.address)
                            Image.asset(
                              IdentityAssets.fieldChevron,
                              width: metrics.size(6),
                              height: metrics.size(12),
                              fit: BoxFit.contain,
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
