import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../identity_design.dart';
import '../identity_models.dart';

/// 弹出出生日期选择器（设计稿 03-02 - 个人信息-日期选择）。
///
/// 面板从设计坐标 344 起，里面是 5 行滚轮（顺序与设计稿一致：日 / 月 / 年），中间
/// 那一行盖一条 327x48 的选中条（右上角带圆点），Submit 与取图弹层同在 y=706。
///
/// 返回归一成接口格式（`d-m-Y`）的日期；用户从面板左上角退出时返回 `null`。
Future<String?> showIdentityBirthdayPicker(
  BuildContext context, {
  required DateTime initialDate,
}) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'identity-birthday',
    barrierColor: AppColors.identitySheetBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _IdentityBirthdayPicker(initialDate: initialDate),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _IdentityBirthdayPicker extends StatefulWidget {
  const _IdentityBirthdayPicker({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_IdentityBirthdayPicker> createState() =>
      _IdentityBirthdayPickerState();
}

class _IdentityBirthdayPickerState extends State<_IdentityBirthdayPicker> {
  /// 可选的年份：下限用接口允许的最早年份，上限是今年。
  static final int _lastYear = DateTime.now().year;
  late final List<int> _years = List<int>.generate(
    _lastYear - IdentityBirthday.minimumYear + 1,
    (index) => IdentityBirthday.minimumYear + index,
  );

  late int _year = widget.initialDate.year.clamp(
    IdentityBirthday.minimumYear,
    _lastYear,
  );
  late int _month = widget.initialDate.month;
  late int _day = widget.initialDate.day;

  late final FixedExtentScrollController _dayWheel =
      FixedExtentScrollController(initialItem: _day - 1);
  late final FixedExtentScrollController _monthWheel =
      FixedExtentScrollController(initialItem: _month - 1);
  late final FixedExtentScrollController _yearWheel =
      FixedExtentScrollController(initialItem: _years.indexOf(_year));

  /// 当前年月的天数（含闰年）。
  List<int> get _days => List<int>.generate(
    DateTime(_year, _month + 1, 0).day,
    (index) => index + 1,
  );

  @override
  void dispose() {
    _dayWheel.dispose();
    _monthWheel.dispose();
    _yearWheel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = IdentityMetrics(
      screenWidth: MediaQuery.sizeOf(context).width,
    );
    final days = _days;

    return IdentityBottomPanel(
      panelKey: const Key('identity-birthday-panel'),
      height: IdentityDesign.birthdaySheetHeight,
      metrics: metrics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: IdentityPanelBackButton(
              key: const Key('identity-birthday-back'),
              metrics: metrics,
            ),
          ),
          SizedBox(height: metrics.size(_wheelGap)),
          SizedBox(
            height: metrics.size(IdentityDesign.birthdayWheelHeight),
            child: Stack(
              children: <Widget>[
                // 选中条（设计稿 `矩形` 327x48）与右上角的圆点；滚轮文字压在它上面。
                Positioned(
                  left: 0,
                  right: 0,
                  top: metrics.size(
                    IdentityDesign.birthdayBandTop -
                        IdentityDesign.birthdayWheelTop,
                  ),
                  height: metrics.size(IdentityDesign.birthdayBandHeight),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: <Widget>[
                      Positioned.fill(
                        child: DecoratedBox(
                          key: const Key('identity-birthday-band'),
                          decoration: BoxDecoration(
                            color: AppColors.identityPanelSurface,
                            borderRadius: BorderRadius.circular(
                              metrics.size(IdentityDesign.sheetRowRadius),
                            ),
                            border: Border.all(
                              color: AppColors.identityCardBorder,
                              width: metrics.size(1),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: metrics.size(IdentityDesign.sheetMarkerRight),
                        top: metrics.size(
                          IdentityDesign.sheetMarkerCenterOffset,
                        ),
                        child: Container(
                          width: metrics.size(IdentityDesign.sheetMarkerSize),
                          height: metrics.size(IdentityDesign.sheetMarkerSize),
                          decoration: const BoxDecoration(
                            color: AppColors.identitySheetMarker,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned.fill(
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _buildWheel(
                          wheelKey: const Key('identity-birthday-day'),
                          controller: _dayWheel,
                          count: days.length,
                          selectedIndex: _day - 1,
                          label: (index) => days[index].toString(),
                          metrics: metrics,
                          onChanged: (index) =>
                              setState(() => _day = days[index]),
                        ),
                      ),
                      Expanded(
                        child: _buildWheel(
                          wheelKey: const Key('identity-birthday-month'),
                          controller: _monthWheel,
                          count: 12,
                          selectedIndex: _month - 1,
                          label: (index) =>
                              (index + 1).toString().padLeft(2, '0'),
                          metrics: metrics,
                          onChanged: _changeMonth,
                        ),
                      ),
                      Expanded(
                        child: _buildWheel(
                          wheelKey: const Key('identity-birthday-year'),
                          controller: _yearWheel,
                          count: _years.length,
                          selectedIndex: _years.indexOf(_year),
                          label: (index) => '${_years[index]}',
                          metrics: metrics,
                          onChanged: _changeYear,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: metrics.size(_submitGap)),
          IdentitySubmitButton(
            key: const Key('identity-birthday-submit'),
            metrics: metrics,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }

  /// 滚轮顶端与返回键之间的间距（设计坐标 394 - 344 - 14 - 24）。
  static const double _wheelGap =
      IdentityDesign.birthdayWheelTop -
      IdentityDesign.sheetPaddingTop -
      IdentityDesign.backSize;

  /// 滚轮底部与 Submit 之间的间距（设计坐标 706 - 394 - 300）。
  static const double _submitGap =
      IdentityDesign.birthdaySubmitTop -
      IdentityDesign.birthdayWheelTop -
      IdentityDesign.birthdayWheelHeight;

  Widget _buildWheel({
    required Key wheelKey,
    required FixedExtentScrollController controller,
    required int count,
    required int selectedIndex,
    required String Function(int index) label,
    required IdentityMetrics metrics,
    required ValueChanged<int> onChanged,
  }) {
    return ListWheelScrollView.useDelegate(
      key: wheelKey,
      controller: controller,
      itemExtent: metrics.size(IdentityDesign.birthdayWheelRowPitch),
      // 设计稿里每一行字号一致、没有近大远小：把直径比放到很大，
      // 滚轮几乎是平面（默认的 2.0 会明显透视缩放）。
      diameterRatio: 100,
      overAndUnderCenterOpacity: 1,
      physics: const FixedExtentScrollPhysics(),
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: count,
        builder: (context, index) => Center(
          child: Text(
            label(index),
            style: TextStyle(
              color: index == selectedIndex
                  ? AppColors.identityTitle
                  : AppColors.loginLabelText,
              fontSize: metrics.size(16),
              fontWeight: index == selectedIndex
                  ? FontWeight.w700
                  : FontWeight.w400,
              height: 20 / 16,
            ),
          ),
        ),
      ),
    );
  }

  void _changeMonth(int index) {
    setState(() {
      _month = index + 1;
      _clampDay();
    });
  }

  void _changeYear(int index) {
    setState(() {
      _year = _years[index];
      _clampDay();
    });
  }

  /// 换月/换年后，原来选中的「日」可能已经超出当月天数（例如 31 号 -> 2 月）。
  void _clampDay() {
    final days = _days.length;
    if (_day <= days) return;
    _day = days;
    if (_dayWheel.hasClients) _dayWheel.jumpToItem(_day - 1);
  }

  void _submit() {
    Navigator.of(context)
        .pop(IdentityBirthday.format(DateTime(_year, _month, _day)));
  }
}
