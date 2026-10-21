import 'dart:convert';

import '../../core/json/json_utils.dart';
import '../../core/network/gateway_reply.dart';

/// 个人信息/工作信息流程共用的完成标记，随命名路由参数传给页面。
class PersonalInformationFlowOutcome {
  static const String argumentKey = 'personalInformationOutcome';

  bool completed = false;

  static PersonalInformationFlowOutcome? of(Object? arguments) {
    if (arguments is! Map) return null;
    final value = arguments[argumentKey];
    return value is PersonalInformationFlowOutcome ? value : null;
  }
}

enum PersonalInformationControl { selection, text, address, unsupported }

/// 动态认证资料页的两种业务形态。
///
/// 个人信息与工作信息共用字段结构和交互，只切换接口、文案与埋点场景。
enum CertificationInformationKind { personal, work }

/// 个人信息与工作信息接口共用的动态字段载荷。
class PersonalInformationData {
  const PersonalInformationData({required this.fields, required this.tips});

  factory PersonalInformationData.fromReply(GatewayReply reply) {
    final payload = reply.payload;
    final rows = payload.listValue('magnificences');
    return PersonalInformationData(
      fields: rows
          .whereType<Map<String, dynamic>>()
          .map(PersonalInformationField.fromJson)
          .where((field) => field.key.isNotEmpty)
          .toList(growable: false),
      tips: payload.stringValue('flatfish').trim(),
    );
  }

  final List<PersonalInformationField> fields;
  final String tips;
}

class PersonalInformationOption {
  const PersonalInformationOption({
    required this.label,
    required this.value,
    this.logoUrl = '',
    this.children = const <PersonalInformationOption>[],
  });

  factory PersonalInformationOption.fromJson(Map<String, dynamic> json) {
    return PersonalInformationOption(
      label: json.stringValue('definitively').trim(),
      value: json.stringValue('trollopy').trim(),
      logoUrl: json.stringValue('headway').trim(),
      children: _childrenOf(json)
          .whereType<Map<String, dynamic>>()
          .map(PersonalInformationOption.fromJson)
          .where((option) => option.label.isNotEmpty)
          .toList(growable: false),
    );
  }

  final String label;
  final String value;
  final String logoUrl;
  final List<PersonalInformationOption> children;

  /// 工作信息的二级选项仍挂在 `azurites` 下；另外两个键保留兼容其它灰度载荷。
  static List<dynamic> _childrenOf(Map<String, dynamic> json) {
    for (final key in const <String>[
      'azurites',
      'deportment',
      'overwhelming',
    ]) {
      final value = json[key];
      if (value is List && value.isNotEmpty) return value;
    }
    return const <dynamic>[];
  }
}

class PersonalInformationField {
  const PersonalInformationField({
    required this.title,
    required this.placeholder,
    required this.key,
    required this.control,
    required this.isNumeric,
    required this.isRequired,
    required this.options,
    required this.initialValue,
    required this.rawValue,
  });

  factory PersonalInformationField.fromJson(Map<String, dynamic> json) {
    final key = json.stringValue('unaccepted').trim();
    final options = json
        .listValue('azurites')
        .whereType<Map<String, dynamic>>()
        .map(PersonalInformationOption.fromJson)
        .where((option) => option.label.isNotEmpty)
        .toList(growable: false);
    final currentValue = json.stringValue('monosyllabicity').trim();
    return PersonalInformationField(
      title: json.stringValue('canonic').trim(),
      placeholder: json.stringValue('preaccuses').trim(),
      key: key,
      control: _controlOf(json.stringValue('psychosexual').trim()),
      isNumeric: json.boolValue('ulterior'),
      isRequired: !json.boolValue('packwaxes'),
      options: options,
      initialValue: _initialValue(options, currentValue),
      rawValue: currentValue,
    );
  }

  final String title;
  final String placeholder;
  final String key;
  final PersonalInformationControl control;
  final bool isNumeric;
  final bool isRequired;
  final List<PersonalInformationOption> options;
  final PersonalInformationOption? initialValue;
  final String rawValue;

  /// 选项控件保存服务端 value；文本控件直接保存用户输入。
  String get initialSubmitValue => switch (control) {
    PersonalInformationControl.selection => initialValue?.value ?? rawValue,
    _ => rawValue,
  };

  String get initialDisplayValue =>
      rawValue.contains('|') ? rawValue : initialValue?.label ?? rawValue;

  static PersonalInformationControl _controlOf(String value) {
    return switch (value) {
      // MyTools「认证项组件」的明文值与混淆值；`stepped` 是本项目接口示例里
      // 已出现的枚举写法，`Superorganisms` 是参考项目的兼容值。
      'enum' ||
      'stepped' ||
      'PastramisNucleosomal' ||
      'Superorganisms' => PersonalInformationControl.selection,
      'txt' ||
      'onto' ||
      'YokefellowComplicity' ||
      'EmpathisedWombiest' => PersonalInformationControl.text,
      'citySelect' ||
      'stage' ||
      'Safely' ||
      'Browbeat' => PersonalInformationControl.address,
      _ => PersonalInformationControl.unsupported,
    };
  }

  static PersonalInformationOption? _initialValue(
    List<PersonalInformationOption> options,
    String current,
  ) {
    for (final option in options) {
      if (option.label == current || option.value == current) return option;
      for (final child in option.children) {
        if (child.label == current || child.value == current) return child;
      }
    }
    final parts = current.split('|');
    if (parts.length == 2) {
      final parentLabel = parts.first.trim();
      final childLabel = parts.last.trim();
      for (final option in options) {
        if (option.label != parentLabel && option.value != parentLabel) {
          continue;
        }
        for (final child in option.children) {
          if (child.label == childLabel || child.value == childLabel) {
            return child;
          }
        }
      }
    }
    return null;
  }
}

class PersonalAddressNode {
  const PersonalAddressNode({
    required this.id,
    required this.label,
    required this.children,
  });

  factory PersonalAddressNode.fromJson(Map<String, dynamic> json) {
    return PersonalAddressNode(
      id: (json['dependable'] ?? json['unaccepted'] ?? '').toString().trim(),
      label: json.stringValue('definitively').trim(),
      children: parseChildren(
        json['latchstrings'] ?? json['boogeying'] ?? json['applicants'],
      ),
    );
  }

  final String id;
  final String label;
  final List<PersonalAddressNode> children;

  static List<PersonalAddressNode> fromReply(GatewayReply reply) {
    final payload = reply.payload;
    final nested = payload.mapOf('indulgences');
    final source = payload['latchstrings'] ?? nested['latchstrings'];
    return parseChildren(source);
  }

  static List<PersonalAddressNode> parseChildren(Object? raw) {
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isEmpty) return const <PersonalAddressNode>[];
      try {
        return parseChildren(jsonDecode(trimmed));
      } on FormatException {
        return const <PersonalAddressNode>[];
      }
    }
    if (raw is Map) {
      return parseChildren(
        raw['latchstrings'] ?? raw['applicants'] ?? raw['list'],
      );
    }
    if (raw is! List) return const <PersonalAddressNode>[];
    return raw
        .whereType<Map>()
        .map(
          (node) =>
              PersonalAddressNode.fromJson(Map<String, dynamic>.from(node)),
        )
        .where((node) => node.id.isNotEmpty && node.label.isNotEmpty)
        .toList(growable: false);
  }
}
