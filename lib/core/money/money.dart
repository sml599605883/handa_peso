import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

/// 以整数最小货币单位（分/centavos）存储的不可变金额值。
///
/// 金融代码绝不能使用 `double` 表示金额。[Money] 保留精确的整数表示，
/// 仅在参与运算时转换为 [Decimal]，从而保证舍入行为在 iOS、Android 和
/// Flutter 上保持一致。
final class Money implements Comparable<Money> {
  const Money._(this.minorUnits, this.currency);

  /// 以整数最小货币单位（如 centavos）构造金额值。
  factory Money.fromMinor(int minorUnits, {String currency = php}) {
    return Money._(minorUnits, currency);
  }

  /// 以整数主单位构造金额值，例如 `Money.fromMajor(1500)`。
  factory Money.fromMajor(num amount, {String currency = php}) {
    return Money.fromDecimal(Decimal.parse(amount.toString()), currency: currency);
  }

  /// 以主单位（比索）的十进制金额构造金额值。
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

  /// 乘以任意比例，并按四舍五入取整到最近的 1 分。
  Money multipliedBy(Decimal ratio) {
    return Money.fromDecimal(decimalValue * ratio, currency: currency);
  }

  /// 格式化为带千分位的货币形式，例如 `PHP 1,234.56`。
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

  /// 仅格式化为带千分位的数字，例如 `1,234.56`（不含货币符号）。
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
