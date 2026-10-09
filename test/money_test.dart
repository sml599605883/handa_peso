import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/money/money.dart';

void main() {
  group('Money', () {
    test('formats minor units with thousands separators', () {
      expect(Money.fromMinor(123456).formatPlain(), '1,234.56');
      expect(Money.fromMajor(1500).format(), '₱1,500.00');
    });

    test('keeps exact arithmetic without floating point drift', () {
      final total = Money.fromMajor(0.1) + Money.fromMajor(0.2);
      expect(total, Money.fromMajor(0.3));
      expect(total.formatPlain(), '0.30');
    });

    test('multiplies by a decimal ratio and rounds to the centavo', () {
      final interest = Money.fromMajor(10000).multipliedBy(Decimal.parse('0.05'));
      expect(interest, Money.fromMajor(500));
    });

    test('rejects mismatched currencies', () {
      expect(
        () => Money.fromMinor(100).compareTo(Money.fromMinor(100, currency: 'USD')),
        throwsArgumentError,
      );
    });
  });
}
