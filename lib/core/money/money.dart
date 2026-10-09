import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// Immutable monetary value stored as integer minor units (centavos).
///
/// Financial code must never use `double` for money. [Money] keeps an exact
/// integer representation and only converts to [Decimal] for arithmetic, so
/// rounding behaviour stays deterministic across iOS, Android and Flutter.
final class Money implements Comparable<Money> {
  const Money._(this.minorUnits, this.currency);

  /// Builds a value from an integer amount of minor units (e.g. centavos).
  factory Money.fromMinor(int minorUnits, {String currency = php}) {
    return Money._(minorUnits, currency);
  }

  /// Builds a value from a whole-unit amount, e.g. `Money.fromMajor(1500)`.
  factory Money.fromMajor(num amount, {String currency = php}) {
    return Money.fromDecimal(Decimal.parse(amount.toString()), currency: currency);
  }

  /// Builds a value from a decimal amount measured in major units (pesos).
  factory Money.fromDecimal(Decimal amount, {String currency = php}) {
    final minor = (amount * Decimal.fromInt(_minorPerMajor)).round();
    return Money._(minor.toBigInt().toInt(), currency);
  }

  static const php = 'PHP';
  static const zero = Money._(0, php);
  static const _minorPerMajor = 100;

  final int minorUnits;
  final String currency;

  bool get isZero => minorUnits == 0;
  bool get isNegative => minorUnits < 0;

  Decimal get decimalValue =>
      (Decimal.fromInt(minorUnits) / Decimal.fromInt(_minorPerMajor)).toDecimal();

  Money operator +(Money other) {
    _assertSameCurrency(other);
    return Money._(minorUnits + other.minorUnits, currency);
  }

  Money operator -(Money other) {
    _assertSameCurrency(other);
    return Money._(minorUnits - other.minorUnits, currency);
  }

  Money operator *(int factor) => Money._(minorUnits * factor, currency);

  /// Multiplies by an arbitrary ratio and rounds half-up to the nearest cent.
  Money multipliedBy(Decimal ratio) {
    return Money.fromDecimal(decimalValue * ratio, currency: currency);
  }

  /// Formats as grouped currency, e.g. `PHP 1,234.56`.
  String format({bool withSymbol = true, bool withCode = false}) {
    final formatter = NumberFormat('#,##0.00', 'en_PH');
    final major = formatter.format(minorUnits.abs() / _minorPerMajor);
    final signed = isNegative ? '-$major' : major;
    if (!withSymbol) {
      return signed;
    }
    final symbol = switch (currency) {
      php => '₱',
      _ => '$currency ',
    };
    final code = withCode ? '$currency ' : '';
    return '$code$symbol$signed';
  }

  /// Formats as grouped digits only, e.g. `1,234.56` (no currency symbol).
  String formatPlain() => format(withSymbol: false);

  @override
  int compareTo(Money other) {
    _assertSameCurrency(other);
    return minorUnits.compareTo(other.minorUnits);
  }

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits && other.currency == currency;

  @override
  int get hashCode => Object.hash(minorUnits, currency);

  @override
  String toString() => 'Money(${formatPlain()} $currency)';

  void _assertSameCurrency(Money other) {
    if (other.currency != currency) {
      throw ArgumentError('Currency mismatch: $currency vs ${other.currency}');
    }
  }
}
