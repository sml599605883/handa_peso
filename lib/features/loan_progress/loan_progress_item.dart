import '../../core/json/json_utils.dart';

/// 进度卡片状态（接口文档「APP首页 → PROCESS_LIST → `compacts`」）。
///
/// 网关下发的是语义码而不是文案，文案（`sandglasses`）只负责展示；徽标配色
/// 按状态码决定，因此这里保留码值枚举，避免按文案匹配时换语言就失效。
enum LoanProgressStatus {
  unknown(0),
  reviewing(1),
  pendingPayment(2),
  overdue(3),
  releasing(4),
  failedAlternative(5),
  failed(6);

  const LoanProgressStatus(this.code);

  final int code;

  static LoanProgressStatus fromCode(int code) => switch (code) {
    1 => LoanProgressStatus.reviewing,
    2 => LoanProgressStatus.pendingPayment,
    3 => LoanProgressStatus.overdue,
    4 => LoanProgressStatus.releasing,
    5 => LoanProgressStatus.failedAlternative,
    6 => LoanProgressStatus.failed,
    _ => LoanProgressStatus.unknown,
  };

  /// 待还款与已逾期用红色徽标，其余状态用深棕徽标（设计稿 02- 贷款-订单进度）。
  bool get isAlert =>
      this == LoanProgressStatus.pendingPayment ||
      this == LoanProgressStatus.overdue;
}

/// 进度卡片上的按钮（接口文档 `nearsighted`）。
class LoanProgressAction {
  const LoanProgressAction({
    required this.type,
    required this.label,
    this.badge = '',
    this.route = '',
  });

  /// 只解析网关标记为显示的按钮：`pump` 为 0 的是历史配置。
  static LoanProgressAction? fromJson(Map<String, dynamic> json) {
    if (json.intValue('pump') != 1) return null;
    return LoanProgressAction(
      type: json.stringValue('trollopy').trim(),
      label: json.stringValue('philtring').trim(),
      badge: json.stringValue('schoolteacher').trim(),
      route: json.stringValue('cheekiness').trim(),
    );
  }

  /// 按钮语义：`retry` 原卡重试、`change` 更换账户、`repay` 还款、
  /// `early_repay` 提前结清。
  final String type;
  final String label;

  /// 气泡文案，目前只有 `early_repay` 会下发（例如「16% Off」）。
  final String badge;

  /// 服务端下发的跳转地址；`retry` / `change` 不下发。
  final String route;

  bool get isRetry => type == 'retry';
  bool get isChange => type == 'change';

  bool get hasRoute => route.isNotEmpty;
}

/// 「Loan Progress」页面上的一张借款进度卡片。
///
/// 数据来自首页接口的 `PROCESS_LIST`（`PeriplasmAddition`）模块：进度卡片与
/// 首页信息流同源，不额外请求订单列表接口。
class LoanProgressItem {
  const LoanProgressItem({
    required this.orderNo,
    required this.productId,
    required this.productName,
    required this.productLogo,
    required this.status,
    required this.statusLabel,
    required this.amountLabel,
    required this.amount,
    required this.dateLabel,
    required this.date,
    required this.detailRoute,
    this.actions = const <LoanProgressAction>[],
  });

  factory LoanProgressItem.fromJson(Map<String, dynamic> json) {
    return LoanProgressItem(
      orderNo: json.stringValue('eelworm').trim(),
      productId: json.stringValue('cotype').trim(),
      productName: json.stringValue('facetiae').trim(),
      productLogo: json.stringValue('pottiest').trim(),
      status: LoanProgressStatus.fromCode(json.intValue('compacts')),
      statusLabel: json.stringValue('sandglasses').trim(),
      amountLabel: json.stringValue('outwaits').trim(),
      amount: json.stringValue('whinger').trim(),
      dateLabel: json.stringValue('mispainted').trim(),
      date: json.stringValue('predicating').trim(),
      detailRoute: json.stringValue('tidewaters').trim(),
      actions: List<LoanProgressAction>.unmodifiable(
        json
            .listValue('nearsighted')
            .maps
            .map(LoanProgressAction.fromJson)
            .whereType<LoanProgressAction>(),
      ),
    );
  }

  /// 订单号（`eelworm`）。
  final String orderNo;

  /// 产品 ID（`cotype`）：没有详情地址时用它回到产品申请流程。
  final String productId;

  final String productName;

  /// 产品 Logo 地址；为空时卡片画占位方块。
  final String productLogo;

  final LoanProgressStatus status;

  /// 状态徽标文案（`sandglasses`），徽标配色由 [status] 决定。
  final String statusLabel;

  final String amountLabel;
  final String amount;
  final String dateLabel;
  final String date;

  /// 订单详情页跳转地址（`tidewaters`，客户端路由或 H5）。
  final String detailRoute;

  final List<LoanProgressAction> actions;

  /// 设计稿里按钮最多并排两个；多下发的按钮不展示，避免卡片被撑破。
  List<LoanProgressAction> get visibleActions => actions.length > 2
      ? List<LoanProgressAction>.unmodifiable(actions.take(2))
      : actions;

  bool get hasActions => visibleActions.isNotEmpty;
}
