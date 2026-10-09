import '../../core/json/json_utils.dart';
import '../../core/money/money.dart';

/// Loan order status as presented in the order list.
enum OrderStatus {
  reviewing('Under review'),
  disbursing('Disbursing'),
  repaying('Repaying'),
  overdue('Overdue'),
  settled('Settled'),
  cancelled('Cancelled'),
  failed('Failed'),
  unknown('Unknown');

  const OrderStatus(this.label);

  final String label;

  static OrderStatus fromCode(String code) {
    return switch (code.toUpperCase()) {
      'REVIEWING' => OrderStatus.reviewing,
      'DISBURSING' => OrderStatus.disbursing,
      'REPAYING' => OrderStatus.repaying,
      'OVERDUE' => OrderStatus.overdue,
      'SETTLED' => OrderStatus.settled,
      'CANCELLED' => OrderStatus.cancelled,
      'FAILED' => OrderStatus.failed,
      _ => OrderStatus.unknown,
    };
  }
}

class OrderItem {
  const OrderItem({
    required this.orderNo,
    required this.productTitle,
    required this.amount,
    required this.status,
    required this.dueDate,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        orderNo: json.stringValue('order_no'),
        productTitle: json.stringValue('product_title', fallback: 'Cash loan'),
        amount: Money.fromMinor(json.intValue('amount_minor')),
        status: OrderStatus.fromCode(json.stringValue('status')),
        dueDate: DateTime.tryParse(json.stringValue('origin_end_time')),
      );

  final String orderNo;
  final String productTitle;
  final Money amount;
  final OrderStatus status;

  /// Original contractual due date (`origin_end_time`).
  ///
  /// Overdue analytics must be derived from this field rather than any
  /// adjusted/extension date, otherwise repayment statistics drift.
  final DateTime? dueDate;

  bool get isOverdue {
    final due = dueDate;
    if (due == null) return status == OrderStatus.overdue;
    return DateTime.now().isAfter(due) && status != OrderStatus.settled;
  }
}
