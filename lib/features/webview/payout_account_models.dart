import '../../core/json/json_utils.dart';
import '../../core/network/gateway_reply.dart';

/// 换绑时可选择的放款账户。
class PayoutAccount {
  const PayoutAccount({
    required this.id,
    required this.bankName,
    required this.accountNumber,
    required this.logoUrl,
    required this.holderName,
    required this.maintenanceNote,
    required this.isPrimary,
  });

  factory PayoutAccount.fromJson(Map<String, dynamic> json) {
    final holder = json.mapOf('rivieres');
    final name = <String>[
      holder.stringValue('barehanded'),
      holder.stringValue('unforced'),
      holder.stringValue('unenlightened'),
    ].map((part) => part.trim()).where((part) => part.isNotEmpty).join(' ');
    return PayoutAccount(
      id: json.stringValue('retraction').trim(),
      bankName: json.stringValue('photoduplicated').trim(),
      accountNumber: json.stringValue('banisters').trim(),
      logoUrl: json.stringValue('week').trim(),
      holderName: name,
      maintenanceNote: json.stringValue('lookalike').trim(),
      isPrimary: json.boolValue('premillenarian'),
    );
  }

  final String id;
  final String bankName;
  final String accountNumber;
  final String logoUrl;
  final String holderName;
  final String maintenanceNote;
  final bool isPrimary;
}

class PayoutAccountGroup {
  const PayoutAccountGroup({required this.title, required this.accounts});

  factory PayoutAccountGroup.fromJson(Map<String, dynamic> json) {
    return PayoutAccountGroup(
      title: json.stringValue('burlesquer').trim(),
      accounts: json
          .listValue('geochronologist')
          .maps
          .map(PayoutAccount.fromJson)
          .where((account) => account.id.isNotEmpty)
          .toList(growable: false),
    );
  }

  final String title;
  final List<PayoutAccount> accounts;
}

class PayoutAccountCatalog {
  const PayoutAccountCatalog(this.groups);

  factory PayoutAccountCatalog.fromReply(GatewayReply reply) {
    return PayoutAccountCatalog(
      reply.payload
          .listValue('applicants')
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
