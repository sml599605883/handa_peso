import '../../core/json/json_utils.dart';
import '../../core/network/gateway_reply.dart';

/// 紧急联系人流程的完成标记，随命名路由参数传给页面。
class EmergencyContactFlowOutcome {
  static const argumentKey = 'emergencyContactOutcome';

  bool completed = false;

  static EmergencyContactFlowOutcome? of(Object? arguments) {
    if (arguments is! Map) return null;
    final value = arguments[argumentKey];
    return value is EmergencyContactFlowOutcome ? value : null;
  }
}

class EmergencyContactOption {
  const EmergencyContactOption({required this.label, required this.value});

  factory EmergencyContactOption.fromJson(Map<String, dynamic> json) {
    return EmergencyContactOption(
      label: json.stringValue('definitively').trim(),
      value: json.stringValue('trollopy').trim(),
    );
  }

  final String label;
  final String value;
}

class EmergencyContact {
  const EmergencyContact({
    required this.number,
    required this.relationshipValue,
    required this.relationshipLabel,
    required this.name,
    required this.phone,
    required this.relationshipOptions,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    final options = json
        .listValue('musick')
        .whereType<Map<String, dynamic>>()
        .map(EmergencyContactOption.fromJson)
        .where((option) => option.label.isNotEmpty && option.value.isNotEmpty)
        .toList(growable: false);
    final relationshipValue = json.stringValue('releasers').trim();
    final selected = options
        .where((option) => option.value == relationshipValue)
        .firstOrNull;
    return EmergencyContact(
      number: json.stringValue('nomadisms').trim(),
      relationshipValue: relationshipValue,
      relationshipLabel: selected?.label ?? '',
      name: json.stringValue('definitively').trim(),
      phone: json.stringValue('silencers').trim(),
      relationshipOptions: options,
    );
  }

  final String number;
  final String relationshipValue;
  final String relationshipLabel;
  final String name;
  final String phone;
  final List<EmergencyContactOption> relationshipOptions;
}

class EmergencyContactData {
  const EmergencyContactData({required this.prompt, required this.contacts});

  factory EmergencyContactData.fromReply(GatewayReply reply) {
    final payload = reply.payload;
    final redness = payload.mapOf('redness');
    final rows = redness.listValue('latchstrings');
    return EmergencyContactData(
      prompt: payload.stringValue('flatfish').trim(),
      contacts: rows
          .whereType<Map<String, dynamic>>()
          .map(EmergencyContact.fromJson)
          .where((contact) => contact.number.isNotEmpty)
          .toList(growable: false),
    );
  }

  final String prompt;
  final List<EmergencyContact> contacts;
}

/// 系统通讯录选择器返回的可保存联系人信息。
class EmergencyPickedContact {
  const EmergencyPickedContact({required this.name, required this.phone});

  final String name;
  final String phone;
}
