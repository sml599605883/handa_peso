import 'dart:async';

import 'package:flutter/material.dart';

import 'home_data.dart';

/// 首页服务端 Banner 轮播（设计稿 08-04：347x130，圆角 14，左右留白 14）。
///
/// 内容来自首页 `BANNER`（`TophBacks`）模块：多张时每 3 秒自动翻页，也支持
/// 手动滑动；只有一张时不套 `PageView`，避免出现没有意义的翻页手势。模块缺失
/// 或条目都不带图片时，退回设计稿内置的宣传条，保证这个位置不会出现空洞。
///
/// 自动翻页只在首页可见（[isActive]）且应用位于前台时进行：被二级页面覆盖、
/// 切到其它 Tab 或退到后台都会停下来。
class HomeBanner extends StatefulWidget {
  const HomeBanner({
    super.key,
    required this.banners,
    required this.onTap,
    required this.scale,
    this.isActive = true,
  });

  /// 设计稿尺寸（02-01 默认态与 08-04 Banner）。
  static const double _designHeight = 130;
  static const double _designRadius = 14;
  static const double _designSideInset = 14;

  /// 设计稿内置的宣传条（02-01「MONEY IN MINUTES」）。
  static const String _fallbackAsset = 'assets/home_money_banner.png';

  /// 网关下发的 Banner，按顺序展示。
  final List<HomeBannerData> banners;

  final ValueChanged<HomeBannerData> onTap;

  /// 由首页按设计稿 375 宽换算出来的缩放比。
  final double scale;

  /// 首页是否可见；不可见时暂停自动翻页。
  final bool isActive;

  @override
  State<HomeBanner> createState() => _HomeBannerState();
}

class _HomeBannerState extends State<HomeBanner> with WidgetsBindingObserver {
  /// 从一个很大的页码起步，轮播永远向后翻，再靠取模回到第一张，
  /// 这样从最后一张翻回第一张时不会反向滚动。
  static const int _pageBase = 10000;
  static const Duration _interval = Duration(seconds: 3);
  static const Duration _transition = Duration(milliseconds: 300);

  /// 起始页码取 [count] 的整数倍，保证轮播从网关下发的第一张开始。
  static int _startPage(int count) =>
      count <= 0 ? _pageBase : _pageBase - (_pageBase % count);

  late int _page = _startPage(widget.banners.length);
  late final PageController _controller = PageController(initialPage: _page);
  Timer? _timer;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || state == AppLifecycleState.resumed;
    _syncTimer();
  }

  @override
  void didUpdateWidget(HomeBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.banners.length != widget.banners.length) {
      _page = _startPage(widget.banners.length);
      if (_controller.hasClients) _controller.jumpToPage(_page);
    }
    _syncTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!widget.isActive || !_foreground || widget.banners.length < 2) return;
    _timer = Timer.periodic(_interval, (_) {
      // 用户正在手动滑动时不抢翻页，等他松手后下一拍再继续。
      if (!_controller.hasClients ||
          _controller.position.isScrollingNotifier.value) {
        return;
      }
      unawaited(
        _controller.animateToPage(
          _page + 1,
          duration: _transition,
          curve: Curves.easeOut,
        ),
      );
    });
  }

  Widget _fallback() =>
      Image.asset(HomeBanner._fallbackAsset, fit: BoxFit.fill);

  Widget _slide(HomeBannerData banner) => GestureDetector(
    key: ValueKey('home-banner-${banner.id}'),
    behavior: HitTestBehavior.opaque,
    onTap: () => widget.onTap(banner),
    child: Image.network(
      banner.imageUrl,
      fit: BoxFit.cover,
      width: double.infinity,
      height: double.infinity,
      loadingBuilder: (context, child, progress) =>
          progress == null ? child : _fallback(),
      errorBuilder: (context, error, stackTrace) => _fallback(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final banners = widget.banners;
    final Widget content;
    if (banners.isEmpty) {
      content = _fallback();
    } else if (banners.length == 1) {
      content = _slide(banners.single);
    } else {
      content = PageView.builder(
        controller: _controller,
        onPageChanged: (page) => _page = page,
        itemBuilder: (context, index) =>
            _slide(banners[index % banners.length]),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: HomeBanner._designSideInset * widget.scale,
      ),
      child: SizedBox(
        height: HomeBanner._designHeight * widget.scale,
        width: double.infinity,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(
            HomeBanner._designRadius * widget.scale,
          ),
          child: content,
        ),
      ),
    );
  }
}
