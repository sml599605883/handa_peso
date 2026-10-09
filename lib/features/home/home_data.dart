import '../../core/json/json_utils.dart';
import '../../core/money/money.dart';

/// Home feed content delivered by `ApiEndpoints.homeFeed`.
class HomeData {
  HomeData({
    required this.greeting,
    required this.creditLimit,
    required this.progress,
    required List<HomeBanner> banners,
    required List<LoanOffer> offers,
    required List<Announcement> announcements,
  })  : banners = List.unmodifiable(banners),
        offers = List.unmodifiable(offers),
        announcements = List.unmodifiable(announcements);

  factory HomeData.fromJson(Map<String, dynamic> json) {
    return HomeData(
      greeting: json.stringValue('greeting', fallback: 'Welcome'),
      creditLimit: Money.fromMinor(json.intValue('credit_limit_minor')),
      progress: CertificationProgress.fromJson(json.mapOf('progress')),
      banners: json.listValue('banners').maps.map(HomeBanner.fromJson).toList(),
      offers: json.listValue('offers').maps.map(LoanOffer.fromJson).toList(),
      announcements:
          json.listValue('announcements').maps.map(Announcement.fromJson).toList(),
    );
  }

  final String greeting;
  final Money creditLimit;
  final CertificationProgress progress;
  final List<HomeBanner> banners;
  final List<LoanOffer> offers;
  final List<Announcement> announcements;
}

class HomeBanner {
  const HomeBanner({required this.id, required this.title, required this.target});

  factory HomeBanner.fromJson(Map<String, dynamic> json) => HomeBanner(
        id: json.stringValue('id'),
        title: json.stringValue('title'),
        target: json.stringValue('target'),
      );

  final String id;
  final String title;
  final String target;
}

class LoanOffer {
  const LoanOffer({
    required this.productId,
    required this.title,
    required this.amount,
    required this.termDays,
    required this.aprPercent,
  });

  factory LoanOffer.fromJson(Map<String, dynamic> json) => LoanOffer(
        productId: json.stringValue('product_id'),
        title: json.stringValue('title', fallback: 'Cash loan'),
        amount: Money.fromMinor(json.intValue('amount_minor')),
        termDays: json.intValue('term_days', fallback: 30),
        aprPercent: json['apr_percent']?.toString() ?? '0',
      );

  final String productId;
  final String title;
  final Money amount;
  final int termDays;
  final String aprPercent;
}

class Announcement {
  const Announcement({required this.id, required this.title, required this.url});

  factory Announcement.fromJson(Map<String, dynamic> json) => Announcement(
        id: json.stringValue('id'),
        title: json.stringValue('title'),
        url: json.stringValue('url'),
      );

  final String id;
  final String title;
  final String url;
}

class CertificationProgress {
  const CertificationProgress({required this.completed, required this.total});

  factory CertificationProgress.fromJson(Map<String, dynamic> json) =>
      CertificationProgress(
        completed: json.intValue('completed'),
        total: json.intValue('total', fallback: 5),
      );

  final int completed;
  final int total;

  double get ratio => total == 0 ? 0 : (completed / total).clamp(0, 1).toDouble();

  bool get isComplete => total > 0 && completed >= total;
}
