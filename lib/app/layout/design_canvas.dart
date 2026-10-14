import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 设计稿画布：内容仍按设计稿坐标绘制，整棵子树再等比缩放到设备宽度。
///
/// 这样每个元素都写设计稿上的原始数值（`top: 58`、`fontSize: 16`），不必到处
/// 乘缩放系数，也不会出现「字号缩了、行高没缩」这类偏差；设备比设计稿更高时
/// 画布按同一比例补足高度，多出来的部分交给 [SingleChildScrollView] 承接。
class DesignCanvas extends StatelessWidget {
  const DesignCanvas({
    super.key,
    required this.designSize,
    required this.builder,
  });

  /// 设计稿画布尺寸（本项目统一 375x812）。
  final Size designSize;

  /// 在设计坐标系里构建内容；[metrics] 提供缩放系数与安全区换算。
  final Widget Function(BuildContext context, DesignCanvasMetrics metrics)
  builder;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          // 点到空白处收起键盘，与输入框的焦点行为保持一致。
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = constraints.maxWidth / designSize.width;
              final deviceHeight = math.max(
                constraints.maxHeight,
                designSize.height * scale,
              );
              return SingleChildScrollView(
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: deviceHeight,
                  // 画布尺寸由上面的 SizedBox 定死，`FittedBox` 再把固定尺寸的
                  // 设计稿子树缩放进来——子树的宽高比和画布一致，所以不会变形。
                  child: FittedBox(
                    fit: BoxFit.fill,
                    child: SizedBox(
                      width: designSize.width,
                      height: deviceHeight / scale,
                      child: builder(
                        context,
                        DesignCanvasMetrics(
                          scale: scale,
                          deviceHeight: deviceHeight,
                          // 设备安全区是设备像素，换算回设计坐标后才能和设计稿
                          // 上的数值直接比较。
                          safeTop: scale == 0
                              ? 0
                              : MediaQuery.paddingOf(context).top / scale,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// [DesignCanvas] 的度量结果。
class DesignCanvasMetrics {
  const DesignCanvasMetrics({
    required this.scale,
    required this.deviceHeight,
    required this.safeTop,
  });

  /// 设计坐标 → 设备像素的缩放系数。
  final double scale;

  /// 画布在设备上的实际高度（不小于设计稿高度，多出来的部分用于滚动）。
  final double deviceHeight;

  /// 设备顶部安全区，单位是设计坐标。
  final double safeTop;

  /// 画布在设计坐标下的高度。
  double get canvasHeight => deviceHeight / scale;
}
