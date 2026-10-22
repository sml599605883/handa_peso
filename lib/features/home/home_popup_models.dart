import '../../core/json/json_utils.dart';
import '../../core/network/gateway_reply.dart';

enum HomePopupKind { none, appUpgrade, membershipUpgrade, marketing }

class HomePopupBenefit {
  const HomePopupBenefit({required this.title, required this.imageUrl});

  factory HomePopupBenefit.fromJson(Map<String, dynamic> json) {
    return HomePopupBenefit(
      title: json.stringValue('flatfish').trim(),
      imageUrl: json.stringValue('headway').trim(),
    );
  }

  final String title;
  final String imageUrl;
}

class HomePopupConfig {
  const HomePopupConfig({
    this.kind = HomePopupKind.none,
    this.version = '',
    this.message = '',
    this.imageUrl = '',
    this.targetUrl = '',
    this.previousLevel = '',
    this.currentLevel = '',
    this.previousLevelImage = '',
    this.currentLevelImage = '',
    this.benefits = const <HomePopupBenefit>[],
  });

  factory HomePopupConfig.fromReply(GatewayReply reply) {
    final payload = reply.payload;
    final content = payload.mapOf('revetting');
    final previous = content.mapOf('botanic');
    final current = content.mapOf('ward');
    final kind = switch (payload.intValue('trollopy')) {
      1 => HomePopupKind.appUpgrade,
      2 => HomePopupKind.membershipUpgrade,
      3 => HomePopupKind.marketing,
      _ => HomePopupKind.none,
    };
    return HomePopupConfig(
      kind: kind,
      version: content.stringValue('noncounty').trim(),
      message: content.stringValue('tubby').trim(),
      imageUrl: content.stringValue('delinquency').trim(),
      targetUrl: content.stringValue('tidewaters').trim(),
      previousLevel: previous.stringValue('definitively').trim(),
      currentLevel: current.stringValue('definitively').trim(),
      previousLevelImage: previous.stringValue('headway').trim(),
      currentLevelImage: current.stringValue('headway').trim(),
      benefits: content
          .listValue('debilities')
          .maps
          .map(HomePopupBenefit.fromJson)
          .where((benefit) => benefit.title.isNotEmpty)
          .toList(growable: false),
    );
  }

  final HomePopupKind kind;
  final String version;
  final String message;
  final String imageUrl;
  final String targetUrl;
  final String previousLevel;
  final String currentLevel;
  final String previousLevelImage;
  final String currentLevelImage;
  final List<HomePopupBenefit> benefits;

  bool get shouldShow => switch (kind) {
    HomePopupKind.appUpgrade =>
      version.isNotEmpty || message.isNotEmpty || targetUrl.isNotEmpty,
    HomePopupKind.membershipUpgrade => currentLevel.isNotEmpty,
    HomePopupKind.marketing => imageUrl.isNotEmpty,
    HomePopupKind.none => false,
  };
}
