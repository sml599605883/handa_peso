import '../../core/json/json_utils.dart';
import '../../core/network/gateway_reply.dart';

/// 绑卡流程回传给调用方的结果，也用于后续换绑场景。
class BindCardFlowOutcome {
  static const String argumentKey = 'bindCardOutcome';

  bool completed = false;
  bool changed = false;
  String bindId = '';
  String redirectUrl = '';

  static BindCardFlowOutcome? of(Object? arguments) {
    if (arguments is! Map) return null;
    final value = arguments[argumentKey];
    return value is BindCardFlowOutcome ? value : null;
  }
}

enum BindCardFieldControl { selection, text, address, unsupported }

class BindCardOption {
  const BindCardOption({
    required this.label,
    required this.value,
    required this.logoUrl,
    required this.available,
    required this.hint,
  });

  factory BindCardOption.fromJson(Map<String, dynamic> json) {
    return BindCardOption(
      label: _firstText(json, const <String>['definitively', 'cymenes']),
      value: _firstText(json, const <String>['trollopy', 'bellings']),
      logoUrl: _firstText(json, const <String>['headway', 'week']),
      available:
          json.intValue(
            'uppropped',
            fallback: json.intValue('barghests', fallback: 1),
          ) !=
          0,
      hint: _firstText(json, const <String>['lookalike', 'lysogenicity']),
    );
  }

  final String label;
  final String value;
  final String logoUrl;

  /// 维护中仍允许绑定；该标志只用于提示，不用于禁用选项。
  final bool available;
  final String hint;
}

class BindCardField {
  const BindCardField({
    required this.title,
    required this.key,
    required this.placeholder,
    required this.control,
    required this.options,
    required this.required,
    required this.numeric,
    required this.initialValue,
    required this.suggestedValue,
  });

  factory BindCardField.fromJson(Map<String, dynamic> json) {
    final key = _firstText(json, const <String>['unaccepted', 'coffees']);
    final rawType = _firstText(json, const <String>[
      'psychosexual',
      'torsos',
    ]).toLowerCase();
    final options = json
        .listValue('azurites')
        .whereType<Map<String, dynamic>>()
        .map(BindCardOption.fromJson)
        .where((option) => option.label.isNotEmpty && option.value.isNotEmpty)
        .toList(growable: false);
    return BindCardField(
      title: _firstText(json, const <String>['canonic', 'stalagmitic']),
      key: key,
      placeholder: _firstText(json, const <String>['preaccuses', 'vacantness']),
      control: _controlOf(rawType),
      options: options,
      required:
          json.intValue('packwaxes', fallback: json.intValue('shmaltzy')) == 0,
      numeric:
          json.intValue('ulterior', fallback: json.intValue('forgets')) == 1,
      initialValue: _firstText(json, const <String>[
        'monosyllabicity',
        'biolysis',
      ]),
      suggestedValue: _firstText(json, const <String>[
        'lysogenicity',
        'tracheophyte',
      ]),
    );
  }

  final String title;
  final String key;
  final String placeholder;
  final BindCardFieldControl control;
  final List<BindCardOption> options;
  final bool required;
  final bool numeric;
  final String initialValue;
  final String suggestedValue;

  static BindCardFieldControl _controlOf(String value) {
    return switch (value) {
      'enum' ||
      'superorganisms' ||
      'stepped' ||
      'pastramisnucleosomal' => BindCardFieldControl.selection,
      'txt' ||
      'empathisedwombiest' ||
      'onto' ||
      'yokefellowcomplicity' => BindCardFieldControl.text,
      'cityselect' ||
      'browbeat' ||
      'stage' ||
      'safely' => BindCardFieldControl.address,
      _ => BindCardFieldControl.unsupported,
    };
  }
}

class BindCardGroup {
  const BindCardGroup({
    required this.label,
    required this.type,
    required this.fields,
    required this.hint,
  });

  factory BindCardGroup.fromJson(Map<String, dynamic> json) {
    return BindCardGroup(
      label: _firstText(json, const <String>['canonic', 'stalagmitic']),
      type: _firstText(json, const <String>['trollopy', 'bellings']),
      fields: json
          .listValue('magnificences')
          .whereType<Map<String, dynamic>>()
          .map(BindCardField.fromJson)
          .where(
            (field) =>
                field.title.isNotEmpty &&
                field.key.isNotEmpty &&
                field.control != BindCardFieldControl.unsupported,
          )
          .toList(growable: false),
      hint: _firstText(json, const <String>['holt', 'canClickMessage']),
    );
  }

  final String label;
  final String type;
  final List<BindCardField> fields;
  final String hint;
}

class BindCardData {
  const BindCardData({
    required this.groups,
    required this.prompt,
    required this.bottomPrompt,
  });

  factory BindCardData.fromReply(GatewayReply reply) {
    final payload = reply.payload;
    final rows = payload.listValue('magnificences');
    final source = rows.isNotEmpty ? rows : payload.listValue('fribbled');
    return BindCardData(
      groups: source
          .whereType<Map<String, dynamic>>()
          .map(BindCardGroup.fromJson)
          .where(
            (group) =>
                group.label.isNotEmpty &&
                group.type.isNotEmpty &&
                group.fields.isNotEmpty,
          )
          .toList(growable: false),
      prompt: _firstText(payload, const <String>['flatfish', 'properdins']),
      bottomPrompt: _firstText(payload, const <String>[
        'dilatational',
        'biogeographies',
      ]),
    );
  }

  final List<BindCardGroup> groups;
  final String prompt;
  final String bottomPrompt;
}

String _firstText(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json.stringValue(key).trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}
