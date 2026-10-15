import '../../core/json/json_utils.dart';
import '../loan_progress/loan_progress_item.dart';

/// 首页信息流（`/dropcloth/indulgences`）。
///
/// 网关把首页拆成一串「模块」（`trollopy`），每个模块下面挂着若干条目
/// （`ranulas`）。客户端只解析当前设计稿覆盖到的模块，其余模块直接跳过，
/// 这样后端新增模块时老版本不会因为看不懂字段而崩掉。
class HomeData {
  HomeData({
    this.loanCard,
    List<HomeBannerData> banners = const <HomeBannerData>[],
    List<HomeProductOffer> offers = const <HomeProductOffer>[],
    List<LoanProgressItem> progressItems = const <LoanProgressItem>[],
  }) : banners = List.unmodifiable(banners),
       offers = List.unmodifiable(offers),
       progressItems = List.unmodifiable(progressItems);

  factory HomeData.fromJson(Map<String, dynamic> json) {
    HomeLoanCard? largeCard;
    HomeLoanCard? smallCard;
    final banners = <HomeBannerData>[];
    final offers = <HomeProductOffer>[];
    final progressItems = <LoanProgressItem>[];

    for (final module in json.listValue('latchstrings').maps) {
      final items = module.listValue('ranulas').maps;
      if (items.isEmpty) continue;

      switch (module.stringValue('trollopy').trim()) {
        case _HomeModule.banner:
          // 没有图片的条目渲染不出内容，直接丢弃，避免轮播里出现空页。
          banners.addAll(
            items
                .map(HomeBannerData.fromJson)
                .where((banner) => banner.imageUrl.isNotEmpty),
          );
        case _HomeModule.largeCard:
          largeCard ??= HomeLoanCard.fromJson(items.first);
        case _HomeModule.smallCard:
          smallCard ??= HomeLoanCard.fromJson(items.first);
        case _HomeModule.productList:
          offers.addAll(items.map(HomeProductOffer.fromJson));
        case _HomeModule.processList:
          progressItems.addAll(items.map(LoanProgressItem.fromJson));
      }
    }

    // 大卡位缺失时退回小卡位，两者字段结构一致（见接口文档）。
    return HomeData(
      loanCard: largeCard ?? smallCard,
      banners: banners,
      offers: offers,
      progressItems: progressItems,
    );
  }

  final HomeLoanCard? loanCard;

  /// 首页 Banner 轮播（`BANNER`），按网关下发的顺序展示。
  final List<HomeBannerData> banners;

  final List<HomeProductOffer> offers;

  /// 借款进度卡片（`PROCESS_LIST`）：Loan Progress 页面与首页共用同一份数据，
  /// 游客（未登录）下发空数组。
  final List<LoanProgressItem> progressItems;

  bool get isEmpty => loanCard == null && banners.isEmpty && offers.isEmpty;
}

/// 首页模块令牌（接口文档「首页元素」值映射）。
///
/// 网关下发的是本应用专属的令牌，文档里的大写可读名只是它的语义标注：
/// `BANNER` = `TophBacks`、`LARGE_CARD` = `Jailbirds`、
/// `SMALL_CARD` = `DetentionsEndemically`、`REPAY` = `GalReproducibility`、
/// `PRODUCT_LIST` = `InspissateDismantling`、`PROCESS_LIST` = `PeriplasmAddition`、
/// `AD_LIST` = `Broodiest`。这里只声明当前设计稿覆盖到的模块。
abstract final class _HomeModule {
  static const banner = 'TophBacks';
  static const largeCard = 'Jailbirds';
  static const smallCard = 'DetentionsEndemically';
  static const productList = 'InspissateDismantling';
  static const processList = 'PeriplasmAddition';
}

/// 首页 Banner（`BANNER`）里的一张轮播图。
class HomeBannerData {
  const HomeBannerData({
    required this.id,
    required this.imageUrl,
    required this.targetUrl,
  });

  factory HomeBannerData.fromJson(Map<String, dynamic> json) => HomeBannerData(
    id: json.stringValue('dependable').trim(),
    imageUrl: json.stringValue('originator').trim(),
    targetUrl: json.stringValue('tidewaters').trim(),
  );

  /// Banner 配置 ID，点击上报时回传。
  final String id;

  final String imageUrl;

  /// 落地页或深链；服务端可能下发空串，此时图片只展示、不可点击。
  final String targetUrl;
}

/// 首页主借款卡片（大卡位 / 小卡位）。
class HomeLoanCard {
  const HomeLoanCard({
    required this.productId,
    required this.productName,
    required this.logoUrl,
    required this.amountText,
    required this.amountCaption,
    required this.termText,
    required this.termCaption,
    required this.rateText,
    required this.rateCaption,
    required this.processText,
    required this.limitSteps,
    required this.periodTerms,
  });

  factory HomeLoanCard.fromJson(Map<String, dynamic> json) {
    return HomeLoanCard(
      productId: json.stringValue('dependable'),
      productName: json.stringValue('dullard'),
      logoUrl: json.stringValue('circularise'),
      amountText: json.stringValue('flaunter'),
      amountCaption: json.stringValue('outeating', fallback: 'Available up to'),
      termText: json.stringValue('pyranoside'),
      termCaption: json.stringValue('farle', fallback: 'Loan terms'),
      rateText: json.stringValue('phalarope'),
      rateCaption: json.stringValue('disgruntle', fallback: 'Interest rate'),
      processText: json.stringValue('unglove'),
      limitSteps: json
          .listValue('microfarads')
          .maps
          .map(HomeLimitStep.fromJson)
          .toList(growable: false),
      periodTerms: json
          .listValue('varyingly')
          .maps
          .map(HomePeriodTerm.fromJson)
          .toList(growable: false),
    );
  }

  final String productId;
  final String productName;
  final String logoUrl;

  /// 已格式化好的金额文案，例如 `₱50,000`。
  final String amountText;
  final String amountCaption;

  /// 单期方案下的固定期限与利率文案。
  final String termText;
  final String termCaption;
  final String rateText;
  final String rateCaption;

  /// 卡片下方的认证引导文案。
  final String processText;

  /// 「认证进度」票据中的额度筹码，仅在认证进行中下发。
  final List<HomeLimitStep> limitSteps;

  /// 借款可选期数，认证完成后下发；只有一项时按单期居中展示。
  final List<HomePeriodTerm> periodTerms;

  bool get hasLimitSteps => limitSteps.isNotEmpty;
}

/// 「My unlocked limit」票据中的一个额度筹码。
class HomeLimitStep {
  const HomeLimitStep({
    required this.title,
    required this.amountText,
    required this.reached,
  });

  factory HomeLimitStep.fromJson(Map<String, dynamic> json) => HomeLimitStep(
    title: json.stringValue('canonic').trim(),
    amountText: json.stringValue('triodes').trim(),
    reached: json.intValue('gametogenous') == 1,
  );

  final String title;
  final String amountText;
  final bool reached;
}

/// 借款可选期数（例如 `2 Period / ≤0.5% / Day`）。
class HomePeriodTerm {
  const HomePeriodTerm({
    required this.period,
    required this.caption,
    required this.rateText,
  });

  factory HomePeriodTerm.fromJson(Map<String, dynamic> json) => HomePeriodTerm(
    period: json.stringValue('selenological').trim(),
    caption: json.stringValue('coaxing').trim(),
    rateText: json.stringValue('phalarope').trim(),
  );

  final String period;
  final String caption;
  final String rateText;
}

/// 推荐列表（`PRODUCT_LIST`）中的一个导流产品。
class HomeProductOffer {
  const HomeProductOffer({
    required this.productId,
    required this.productName,
    required this.logoUrl,
    required this.amountText,
    required this.amountCaption,
    required this.termText,
    required this.rateText,
    required this.buttonText,
    required this.tone,
  });

  factory HomeProductOffer.fromJson(Map<String, dynamic> json) {
    return HomeProductOffer(
      productId: json.stringValue('dependable'),
      productName: json.stringValue('dullard'),
      logoUrl: json.stringValue('circularise'),
      amountText: json.stringValue('flaunter'),
      amountCaption: json.stringValue('outeating', fallback: 'Available up to'),
      termText: json.stringValue('pyranoside'),
      rateText: json.stringValue('phalarope'),
      buttonText: json.stringValue('unchivalrous', fallback: 'Apply Now'),
      tone: HomeApplyTone.fromCode(
        json.containsKey('asbestine')
            ? json.intValue('asbestine')
            : json.intValue('sinewing'),
      ),
    );
  }

  final String productId;
  final String productName;
  final String logoUrl;
  final String amountText;
  final String amountCaption;
  final String termText;
  final String rateText;
  final String buttonText;
  final HomeApplyTone tone;
}

/// 推荐卡片按钮的下发状态：`1` 高亮、`0` 普通、`-1` 置灰。
enum HomeApplyTone {
  highlight,
  normal,
  disabled;

  static HomeApplyTone fromCode(int code) {
    if (code > 0) return HomeApplyTone.highlight;
    if (code < 0) return HomeApplyTone.disabled;
    return HomeApplyTone.normal;
  }
}
