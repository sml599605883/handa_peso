import '../../core/json/json_utils.dart';
import '../../core/network/gateway_reply.dart';

/// 放款账户页回传结果。
///
/// 页面只负责选卡和换卡；调用方拿到新的订单地址后，再把来源 H5 替换掉。
class PayoutAccountFlowOutcome {
  static const String argumentKey = 'payoutAccountOutcome';

  bool changed = false;
  String redirectUrl = '';

  static PayoutAccountFlowOutcome? of(Object? arguments) {
    if (arguments is! Map) return null;
    final value = arguments[argumentKey];
    return value is PayoutAccountFlowOutcome ? value : null;
  }
}

/// 换绑时可选择的放款账户。
class PayoutAccount {
  static const defaultMaintenanceNote =
      'The bank is under maintenance. Loans may be delayed. '
      'Please wait or choose another option';

  const PayoutAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.logoUrl,
    required this.holderName,
    required this.maintenanceNote,
    required this.isPrimary,
    this.holderFirstName = '',
    this.holderMiddleName = '',
    this.holderLastName = '',
    this.available = true,
  });

  factory PayoutAccount.fromJson(Map<String, dynamic> json) {
    final holder = json.mapOrNull('unworked') ?? json.mapOf('rivieres');
    final first = _firstText(holder, const <String>[
      'advisements',
      'barehanded',
    ]);
    final middle = _firstText(holder, const <String>['chyme', 'unforced']);
    final last = _firstText(holder, const <String>[
      'recusant',
      'unenlightened',
    ]);
    final available =
        json.intValue(
          'uppropped',
          fallback: json.intValue('status', fallback: 1),
        ) !=
        0;
    // 维护提示文案：实抓 `/dropcloth/dullard` 里账户对象带的是 `jellies`
    // （MyTools 字段映射 text→jellies），维护中的账户才会填内容，可用时为空串。
    // `argala`(noteText) / `azurites`(note) 是同族接口出现过的历史文案键。
    final note = _firstText(json, const <String>['jellies', 'argala', 'azurites']);
    return PayoutAccount(
      id: _firstText(json, const <String>['eyeglasses', 'retraction']),
      bankName: _firstText(json, const <String>['crankles', 'photoduplicated']),
      accountNumber: _firstText(json, const <String>['calipash', 'banisters']),
      logoUrl: _firstText(json, const <String>['headway', 'week']),
      holderName: <String>[
        first,
        middle,
        last,
      ].where((part) => part.isNotEmpty).join(' '),
      maintenanceNote: !available && note.isEmpty
          ? defaultMaintenanceNote
          : note,
      isPrimary: json.boolValue(
        'assureds',
        fallback: json.boolValue('premillenarian'),
      ),
      holderFirstName: first,
      holderMiddleName: middle,
      holderLastName: last,
      available: available,
    );
  }

  final String id;
  final String bankName;
  final String accountNumber;
  final String logoUrl;

  /// 户名。C-21 出参会带，但设计稿 04-01 的银行/电子钱包卡片只展示
  /// 「Receipt Account + 卡号」两行，现金取款才是三姓名分列，所以这里只解析
  /// 不渲染；要展示需先有设计位。
  final String holderName;
  final String maintenanceNote;
  final bool isPrimary;
  final String holderFirstName;
  final String holderMiddleName;
  final String holderLastName;

  /// 服务端判定的可用性。维护中只影响提示文案，不禁止选择（R-F17-3）。
  final bool available;
}

class PayoutAccountGroup {
  const PayoutAccountGroup({
    required this.title,
    required this.accounts,
    this.type = '',
  });

  factory PayoutAccountGroup.fromJson(Map<String, dynamic> json) {
    return PayoutAccountGroup(
      title: _firstText(json, const <String>['axmen', 'burlesquer']),
      type: _firstText(json, const <String>['scarriest', 'trollopy']),
      accounts:
          (json.listValue('ranulas').isNotEmpty
                  ? json.listValue('ranulas')
                  : json.listValue('geochronologist'))
              .maps
              .map(PayoutAccount.fromJson)
              .where((account) => account.id.isNotEmpty)
              .toList(growable: false),
    );
  }

  final String title;
  final List<PayoutAccount> accounts;
  final String type;
}

class PayoutAccountCatalog {
  const PayoutAccountCatalog(this.groups);

  factory PayoutAccountCatalog.fromReply(GatewayReply reply) {
    return PayoutAccountCatalog(
      reply.payload
          .listValue(
            reply.payload.listValue('latchstrings').isNotEmpty
                ? 'latchstrings'
                : 'applicants',
          )
          .maps
          .map(PayoutAccountGroup.fromJson)
          .where((group) => group.accounts.isNotEmpty)
          .toList(growable: false),
    );
  }

  final List<PayoutAccountGroup> groups;

  List<PayoutAccount> get accounts =>
      groups.expand((group) => group.accounts).toList(growable: false);

  bool get isEmpty => accounts.isEmpty;
}

String _firstText(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json.stringValue(key).trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}
