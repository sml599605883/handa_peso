import 'dart:convert';

import '../../core/json/json_utils.dart';
import '../../core/network/gateway_reply.dart';

/// 证件流程走完的标记。
///
/// GetX 的命名路由按 `Route<dynamic>` 生成，`Get.toNamed<bool>` 拿不到泛型回传值
/// （`AppNavigator.toLogin` 也是因为同一限制才改成看会话状态），所以由调用方建一个
/// 标记、随路由参数带进流程，流程在「证件信息保存成功」时打勾。
class IdentityFlowOutcome {
  /// 流程各页共用的参数名。
  static const String argumentKey = 'identityOutcome';

  bool completed = false;

  /// 用户在证件类型页选择的卡种；人脸上传接口的 `scarriest` 继续沿用。
  String cardType = '';

  /// 从路由参数里取标记；直接进入某一页（例如测试或深链）时没有这个参数。
  static IdentityFlowOutcome? of(Object? arguments) {
    if (arguments is! Map) return null;
    final value = arguments[argumentKey];
    return value is IdentityFlowOutcome ? value : null;
  }
}

/// 一个可选的证件类型（接口文档「获取用户身份信息（第一项）」的 `card`）。
///
/// 字段名一律取文档里登记的不透明键名，改动前必须回查 MyTools 的
/// `ph_handa_peso_ios` 文档，不能按字面猜语义。
///
/// 文档里同一个对象还有正确示范图 `destructs` 与错误示范图 `will`：设计稿的上传页
/// 用的是固定的一张示范卡（`assets/identity_demo_card.png`），因此这里不解析。
class IdentityCardType {
  const IdentityCardType({required this.code});

  factory IdentityCardType.fromJson(Map<String, dynamic> json) {
    return IdentityCardType(code: json.stringValue('apivorous').trim());
  }

  /// 服务端下发的内容（`apivorous`），既用于按钮展示、也作为 `scarriest` 回传。
  ///
  /// 不另做显示名映射：服务端下发什么就显示什么（`alleviated` 下发的是
  /// `SSS ID` 这类名称，`pricklier` 下发的是 `SSS` 这类 code）。
  final String code;

  /// 按钮上显示的名字。
  String get label => code;
}

/// 证件类型选择页的数据（`/dropcloth/blockader` 的载荷）。
///
/// 两组证件有两个来源，按顺序取：
/// 1. `alleviated`（`cardTypeList2`）：带名称与示范图的服务端结构，灰度时才有；
/// 2. `pricklier`（`cardTypeList`）：线上稳定下发，两行 code，第一行推荐、第二行其它。
///
/// 实测本机抓到的 `GET /dropcloth/blockader?cotype=1` 里 `alleviated` 是空数组、只有
/// `pricklier` 有两行数据，所以第二种才是主路径、第一种是增强。文档里同一份载荷还带
/// 证件背面 `melancholies` 与引导文案 `flatfish`，当前设计稿没有对应位置，故不解析。
class IdentityTypeOptions {
  const IdentityTypeOptions({required this.recommended, required this.others});

  factory IdentityTypeOptions.fromReply(GatewayReply reply) {
    final payload = reply.payload;
    final groups = payload.listValue('alleviated');
    final recommended = <IdentityCardType>[];
    final others = <IdentityCardType>[];
    for (final group in groups) {
      final map = group is Map<String, dynamic>
          ? group
          : const <String, dynamic>{};
      recommended.addAll(_types(map.listValue('tonsil')));
      others.addAll(_types(map.listValue('divagations')));
    }
    if (recommended.isNotEmpty || others.isNotEmpty) {
      return IdentityTypeOptions(
        recommended: _dedupe(recommended),
        others: _dedupe(others),
      );
    }
    return IdentityTypeOptions._fromCardTypeList(payload);
  }

  /// `pricklier`（`cardTypeList`）的回退：两行 code，第一行推荐、第二行其它。
  factory IdentityTypeOptions._fromCardTypeList(Map<String, dynamic> payload) {
    final rows = payload.listValue('pricklier');
    return IdentityTypeOptions(
      recommended: _codes(rows.isNotEmpty ? rows.first : null),
      others: _codes(rows.length > 1 ? rows[1] : null),
    );
  }

  final List<IdentityCardType> recommended;
  final List<IdentityCardType> others;

  bool get isEmpty => recommended.isEmpty && others.isEmpty;

  /// 把一行 code 转成证件项。
  static List<IdentityCardType> _codes(Object? row) {
    if (row is! List) return const <IdentityCardType>[];
    return _dedupe(
      row
          .map((item) => IdentityCardType(code: item?.toString().trim() ?? ''))
          .where((type) => type.code.isNotEmpty)
          .toList(growable: false),
    );
  }

  static List<IdentityCardType> _types(List<dynamic> source) {
    return source
        .whereType<Map<String, dynamic>>()
        .map(IdentityCardType.fromJson)
        .where((type) => type.code.isNotEmpty)
        .toList(growable: false);
  }

  static List<IdentityCardType> _dedupe(List<IdentityCardType> source) {
    final seen = <String>{};
    return source.where((type) => seen.add(type.code)).toList(growable: false);
  }
}

/// 证件正面识别结果（`/dropcloth/sikes` 的 `type=11` 载荷）。
class IdentityRecognition {
  const IdentityRecognition({
    required this.fullName,
    required this.idNumber,
    required this.birthday,
    required this.imageUrl,
  });

  factory IdentityRecognition.fromReply(GatewayReply reply) {
    final payload = reply.payload;
    return IdentityRecognition(
      fullName: payload.stringValue('definitively').trim(),
      idNumber: payload.stringValue('optically').trim(),
      birthday: normalizeBirthday(payload.stringValue('gleeking')),
      imageUrl: payload.stringValue('tidewaters').trim(),
    );
  }

  factory IdentityRecognition.fromArguments(Object? arguments) {
    final map = arguments is Map
        ? Map<String, dynamic>.from(arguments)
        : const <String, dynamic>{};
    return IdentityRecognition(
      fullName: map.stringValue('definitively').trim(),
      idNumber: map.stringValue('optically').trim(),
      birthday: normalizeBirthday(map.stringValue('gleeking')),
      imageUrl: map.stringValue('tidewaters').trim(),
    );
  }

  final String fullName;
  final String idNumber;

  /// 识别出的出生日期，统一成接口要求的 `d-m-Y`。
  final String birthday;

  /// 上传成功后服务端回传的证件图地址。
  final String imageUrl;

  Map<String, dynamic> toArguments() => <String, dynamic>{
    'definitively': fullName,
    'optically': idNumber,
    'gleeking': birthday,
    'tidewaters': imageUrl,
  };

  /// 把 `d/m/Y`、`Y/m/d` 这类写法归一成 `d-m-Y`（`/dropcloth/polybutadiene`
  /// 要求的格式）。认不出来的写法原样返回，交给服务端校验。
  static String normalizeBirthday(String value) =>
      IdentityBirthday.normalize(value);

  @override
  String toString() => jsonEncode(<String, Object?>{
    'name': fullName,
    'idNumber': idNumber,
    'birthday': birthday,
  });
}

/// 证件类型页退出时的挽留弹窗（`/dropcloth/unchivalrous`）。
///
/// Handa 的载荷包在 `revetting` 里；图片是 `tidewaters`，按钮文案分别是
/// `jollified`（继续）与 `footrests`（退出）。没有图片时不展示弹窗，直接放行。
class IdentityRetentionPrompt {
  const IdentityRetentionPrompt({
    required this.title,
    required this.message,
    required this.imageUrl,
    required this.continueText,
    required this.exitText,
  });

  factory IdentityRetentionPrompt.fromReply(GatewayReply reply) {
    final data = reply.payload.mapOf('revetting');
    return IdentityRetentionPrompt(
      title: data.stringValue('canonic').trim(),
      message: data.stringValue('unstably').trim(),
      imageUrl: data.stringValue('tidewaters').trim(),
      continueText: _label(data.stringValue('jollified'), 'Continue'),
      exitText: _label(data.stringValue('footrests'), 'Exit'),
    );
  }

  final String title;
  final String message;
  final String imageUrl;
  final String continueText;
  final String exitText;

  bool get shouldShow => imageUrl.isNotEmpty;

  static String _label(String value, String fallback) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }
}

/// 出生日期的解析与格式化。
///
/// 接口用的是 `d-m-Y`（`/dropcloth/polybutadiene` 的 `gleeking`），识别结果可能回来
/// `d/m/Y` 或 `Y/m/d`，两条链路都从这里过，改格式时只改一处。
abstract final class IdentityBirthday {
  /// 可选年份的下限（证件选择器的最早年份）。
  static const int minimumYear = 1900;

  static final RegExp _dayFirst = RegExp(
    r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$',
  );
  static final RegExp _yearFirst = RegExp(
    r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$',
  );

  /// 解析成日期；写法认不出来、或不在允许范围内时返回 `null`。
  static DateTime? parse(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final dayFirst = _dayFirst.firstMatch(trimmed);
    final yearFirst = dayFirst == null ? _yearFirst.firstMatch(trimmed) : null;
    final int year;
    final int month;
    final int day;
    if (dayFirst != null) {
      day = int.parse(dayFirst.group(1)!);
      month = int.parse(dayFirst.group(2)!);
      year = int.parse(dayFirst.group(3)!);
    } else if (yearFirst != null) {
      year = int.parse(yearFirst.group(1)!);
      month = int.parse(yearFirst.group(2)!);
      day = int.parse(yearFirst.group(3)!);
    } else {
      return null;
    }
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    if (year < minimumYear || parsed.isAfter(DateTime.now())) return null;
    return parsed;
  }

  /// 归一成接口要的 `d-m-Y`；认不出来的写法原样返回，交给服务端校验。
  static String normalize(String value) {
    final parsed = parse(value);
    return parsed == null ? value.trim() : format(parsed);
  }

  static String format(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-${date.year}';
}
