import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';
import 'package:flutter_native_contact_picker/model/contact.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../../core/report/report_scene.dart';
import '../../core/report/report_service.dart';
import 'emergency_contact_design.dart';
import 'emergency_contact_models.dart';
import 'identity_design.dart';
import 'personal_information_models.dart';
import 'widgets/certification_progress_bar.dart';
import 'widgets/identity_retention_guard.dart';
import 'widgets/personal_information_selectors.dart';

typedef EmergencyContactPicker = Future<EmergencyPickedContact?> Function();

/// 紧急联系人（设计稿 03-04）。
///
/// 联系人列表由服务端下发；关系使用单选弹层，联系人信息通过系统通讯录选择器
/// 带入。保存成功后才上报场景 7 并继续产品认证流程，任何失败都停留在本页。
class EmergencyContactPage extends StatefulWidget {
  const EmergencyContactPage({
    this.apiClient,
    this.reporter,
    this.autoContinue = true,
    this.contactPicker,
    super.key,
  });

  final GatewayClient? apiClient;
  final ReportService? reporter;
  final bool autoContinue;
  final EmergencyContactPicker? contactPicker;

  @override
  State<EmergencyContactPage> createState() => _EmergencyContactPageState();
}

class _EmergencyContactPageState extends State<EmergencyContactPage>
    with IdentityRetentionGuard<EmergencyContactPage> {
  static const String _defaultPrompt =
      'Tell us more about yourself to speed up your approval.';

  late final GatewayClient _apiClient =
      widget.apiClient ?? Get.find<GatewayClient>();
  late final int _sceneStartedAt = ReportService.nowSeconds();
  late final EmergencyContactFlowOutcome? _outcome =
      EmergencyContactFlowOutcome.of(Get.arguments);
  final FlutterNativeContactPicker _nativeContactPicker =
      FlutterNativeContactPicker();

  String _productId = '';
  String _prompt = _defaultPrompt;
  List<_ContactEntry> _contacts = const <_ContactEntry>[];
  String _error = '';
  bool _loading = true;
  bool _submitting = false;

  ReportService? get _reporter {
    if (widget.reporter != null) return widget.reporter;
    return Get.isRegistered<ReportService>() ? Get.find<ReportService>() : null;
  }

  bool get _hasContent => _contacts.isNotEmpty && _error.isEmpty && !_loading;

  @override
  String get retentionScene => '4';

  @override
  String get retentionProductId => _productId;

  @override
  GatewayClient get retentionApiClient => _apiClient;

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    if (arguments is Map) {
      _productId = arguments['productId']?.toString().trim() ?? '';
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final reply = await _apiClient.fetchContactProfile(productId: _productId);
      reply.orThrow();
      final data = EmergencyContactData.fromReply(reply);
      if (!mounted) return;
      setState(() {
        _contacts = data.contacts
            .map(_ContactEntry.fromContact)
            .toList(growable: false);
        _prompt = data.prompt.isEmpty ? _defaultPrompt : data.prompt;
        _loading = false;
      });
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      if (!mounted) return;
      setState(() {
        _contacts = const <_ContactEntry>[];
        _error = error.message;
        _loading = false;
      });
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      if (!mounted) return;
      setState(() {
        _contacts = const <_ContactEntry>[];
        _error = 'Unable to load emergency contacts';
        _loading = false;
      });
    }
  }

  Future<void> _selectRelationship(_ContactEntry contact) async {
    if (contact.options.isEmpty) return;
    final selected = await showPersonalInformationOptionSheet(
      context: context,
      title: 'Relationship',
      options: contact.options,
      selectedValue: contact.relationshipValue,
    );
    if (selected == null || !mounted) return;
    setState(() {
      contact.relationshipValue = selected.value;
      contact.relationshipLabel = selected.label;
    });
  }

  Future<void> _selectContact(_ContactEntry contact) async {
    try {
      final picked = await _pickContact();
      if (picked == null || !mounted) return;
      setState(() {
        contact.name = picked.name.trim();
        contact.phone = picked.phone.trim();
      });
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      if (mounted) {
        AppNavigator.showError('Unable to open contacts. Please try again.');
      }
    }
  }

  Future<EmergencyPickedContact?> _pickContact() async {
    if (widget.contactPicker != null) {
      return widget.contactPicker!();
    }
    final contact = await _nativeContactPicker.selectContact();
    if (contact == null) return null;
    return EmergencyPickedContact(
      name: (contact.fullName ?? '').trim(),
      phone: _primaryPhone(contact),
    );
  }

  String _primaryPhone(Contact contact) {
    final selected = (contact.selectedPhoneNumber ?? '').trim();
    if (selected.isNotEmpty) return selected;
    for (final phone in contact.phoneNumbers ?? const <String>[]) {
      if (phone.trim().isNotEmpty) return phone.trim();
    }
    return '';
  }

  Future<void> _submit() async {
    if (_submitting || !_hasContent) return;
    if (_productId.isEmpty) {
      AppNavigator.showError('Product information is unavailable');
      return;
    }

    setState(() => _submitting = true);
    await AppNavigator.showLoading();
    try {
      final reply = await _apiClient.submitContactProfile(
        productId: _productId,
        contacts: _contacts
            .map((contact) => contact.toJson())
            .toList(growable: false),
      );
      reply.orThrow();
      await AppNavigator.dismissLoading();
      unawaited(
        _reporter?.reportScene(
          scene: ReportScene.emergencyContact,
          productId: _productId,
          startedAtSeconds: _sceneStartedAt,
        ),
      );
      AnalyticsService.logEvent(AppEvents.certificationStepCompleted, {
        'step': 'Emergency contacts',
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
          'Unable to save emergency contacts. Please try again.',
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
              title: 'Emergency Contacts',
              onBack: handleRetentionExit,
            ),
            SizedBox(height: metrics.size(12)),
            IdentityHeroBanner(
              text: _heroCopy,
              metrics: metrics,
              top: SizedBox(
                width: metrics.size(EmergencyContactDesign.progressWidth),
                child: CertificationProgressBar(
                  metrics: metrics,
                  activeSegments: 3,
                ),
              ),
              maxLines: 3,
              minFontSize: 14,
              maxFontSize: 20,
            ),
            if (_loading || _error.isNotEmpty || _contacts.isEmpty) ...<Widget>[
              SizedBox(height: metrics.size(46)),
              _statusCard(metrics),
            ] else ...<Widget>[
              SizedBox(height: metrics.size(30)),
              for (
                var index = 0;
                index < _contacts.length;
                index++
              ) ...<Widget>[
                _contactBlock(metrics, index),
                if (index != _contacts.length - 1)
                  SizedBox(height: metrics.size(20)),
              ],
            ],
            SizedBox(height: metrics.size(20)),
            Center(
              child: IdentitySubmitButton(
                key: const Key('emergency-contact-submit'),
                metrics: metrics,
                label: 'Submit',
                onPressed: _hasContent && !_submitting ? _submit : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _heroCopy {
    final productCopy =
        _apiClient.settings.localSession.productFlowCopy.emergencyContact;
    if (productCopy.isNotEmpty) return productCopy;
    return _prompt.trim().isEmpty ? _defaultPrompt : _prompt;
  }

  Widget _statusCard(IdentityMetrics metrics) {
    final message = _loading
        ? 'Loading contacts...'
        : _error.isNotEmpty
        ? _error
        : 'No emergency contacts available';
    return Container(
      key: const Key('emergency-contact-status'),
      constraints: BoxConstraints(
        minHeight: metrics.size(EmergencyContactDesign.cardHeight),
      ),
      decoration: BoxDecoration(
        color: AppColors.identityCardSurface,
        borderRadius: BorderRadius.circular(
          metrics.size(EmergencyContactDesign.cardRadius),
        ),
        border: Border.all(
          color: AppColors.identityCardBorder,
          width: metrics.size(1),
        ),
      ),
      child: Center(
        child: _loading
            ? const CircularProgressIndicator()
            : TextButton.icon(
                key: const Key('emergency-contact-retry'),
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(message),
              ),
      ),
    );
  }

  Widget _contactBlock(IdentityMetrics metrics, int index) {
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Padding(
          padding: EdgeInsets.only(
            top: metrics.size(EmergencyContactDesign.badgeOverlap),
          ),
          child: _contactCard(metrics, index),
        ),
        Positioned(
          left: metrics.size(
            index.isEven
                ? EmergencyContactDesign.badgeLeft -
                      EmergencyContactDesign.cardLeft
                : EmergencyContactDesign.badgeRightLeft -
                      EmergencyContactDesign.cardLeft,
          ),
          top: 0,
          child: _groupBadge(metrics, index),
        ),
      ],
    );
  }

  Widget _contactCard(IdentityMetrics metrics, int index) {
    final contact = _contacts[index];
    return Container(
      key: ValueKey<String>('emergency-contact-card-${contact.number}'),
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: metrics.size(EmergencyContactDesign.cardHeight),
      ),
      padding: EdgeInsets.symmetric(
        horizontal: metrics.size(EmergencyContactDesign.cardPaddingX),
        vertical: metrics.size(EmergencyContactDesign.cardPaddingY),
      ),
      decoration: BoxDecoration(
        color: AppColors.identityCardSurface,
        borderRadius: BorderRadius.circular(
          metrics.size(EmergencyContactDesign.cardRadius),
        ),
        border: Border.all(
          color: AppColors.identityCardBorder,
          width: metrics.size(1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _label(metrics, 'Relationship'),
          SizedBox(height: metrics.size(EmergencyContactDesign.fieldGap)),
          SizedBox(
            height: metrics.size(
              EmergencyContactDesign.relationshipFieldHeight,
            ),
            child: _relationshipField(metrics, contact),
          ),
          SizedBox(height: metrics.size(EmergencyContactDesign.sectionGap)),
          _label(metrics, 'Contact Information'),
          SizedBox(height: metrics.size(EmergencyContactDesign.sectionGap)),
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: metrics.size(76)),
            child: _contactField(metrics, contact),
          ),
        ],
      ),
    );
  }

  Widget _groupBadge(IdentityMetrics metrics, int index) {
    return SizedBox(
      width: metrics.size(EmergencyContactDesign.badgeWidth),
      height: metrics.size(EmergencyContactDesign.badgeHeight),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            index.isEven
                ? EmergencyContactDesign.titleLeftAsset
                : EmergencyContactDesign.titleRightAsset,
            key: ValueKey<String>(
              'emergency-contact-badge-asset-${_contacts[index].number}',
            ),
            fit: BoxFit.fill,
          ),
          Center(
            child: Text(
              'Relationship with Emergency Contacts - ${index + 1}',
              key: ValueKey<String>(
                'emergency-contact-group-title-${_contacts[index].number}',
              ),
              style: TextStyle(
                color: AppColors.textOnPrimary,
                fontSize: metrics.size(12),
                fontWeight: FontWeight.normal,
                height: 18 / 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(IdentityMetrics metrics, String text) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: metrics.size(EmergencyContactDesign.labelHeight),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.personalInformationLabel,
          fontSize: metrics.size(16),
          height: 20 / 16,
        ),
      ),
    );
  }

  Widget _relationshipField(IdentityMetrics metrics, _ContactEntry contact) {
    final hasValue = contact.relationshipLabel.isNotEmpty;
    return Material(
      color: AppColors.personalInformationFieldSurface,
      borderRadius: BorderRadius.circular(
        metrics.size(EmergencyContactDesign.fieldRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>(
          'emergency-contact-relationship-${contact.number}',
        ),
        onTap: contact.options.isEmpty
            ? null
            : () => _selectRelationship(contact),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: metrics.size(20)),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  hasValue ? contact.relationshipLabel : 'Please select',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: hasValue
                        ? AppColors.personalInformationValue
                        : AppColors.personalInformationHint,
                    fontSize: metrics.size(16),
                    fontWeight: hasValue ? FontWeight.w700 : FontWeight.normal,
                    height: 20 / 16,
                  ),
                ),
              ),
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
    );
  }

  Widget _contactField(IdentityMetrics metrics, _ContactEntry contact) {
    return Material(
      color: AppColors.personalInformationFieldSurface,
      borderRadius: BorderRadius.circular(
        metrics.size(EmergencyContactDesign.fieldRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey<String>('emergency-contact-picker-${contact.number}'),
        onTap: () => _selectContact(contact),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: metrics.size(20),
            vertical: metrics.size(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                contact.name.isEmpty ? 'Name' : contact.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: contact.name.isEmpty
                      ? AppColors.personalInformationHint
                      : AppColors.personalInformationValue,
                  fontSize: metrics.size(16),
                  fontWeight: contact.name.isEmpty
                      ? FontWeight.normal
                      : FontWeight.w700,
                  height: 20 / 16,
                ),
              ),
              SizedBox(height: metrics.size(10)),
              Text(
                contact.phone.isEmpty ? 'Phone Number' : contact.phone,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: contact.phone.isEmpty
                      ? AppColors.personalInformationHint
                      : AppColors.personalInformationValue,
                  fontSize: metrics.size(16),
                  fontWeight: contact.phone.isEmpty
                      ? FontWeight.normal
                      : FontWeight.w700,
                  height: 20 / 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactEntry {
  _ContactEntry.fromContact(EmergencyContact contact)
    : number = contact.number,
      relationshipValue = contact.relationshipValue,
      relationshipLabel = contact.relationshipLabel,
      name = contact.name,
      phone = contact.phone,
      options = contact.relationshipOptions
          .map(
            (option) => PersonalInformationOption(
              label: option.label,
              value: option.value,
            ),
          )
          .toList(growable: false);

  final String number;
  final List<PersonalInformationOption> options;
  String relationshipValue;
  String relationshipLabel;
  String name;
  String phone;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'silencers': phone.trim(),
      'definitively': name.trim(),
      'releasers': relationshipValue.trim(),
      'nomadisms': number,
    };
  }
}
