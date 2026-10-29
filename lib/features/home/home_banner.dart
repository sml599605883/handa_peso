import 'dart:async';

import 'package:flutter/material.dart';

import 'home_data.dart';

/// 首页服务端 Banner 轮播（设计稿 08-04：347x130，圆角 14，左右留白 14）。
///
/// 内容来自首页 `BANNER`（`TophBacks`）模块：多张时每 3 秒自动翻页，也支持
/// 手动滑动；只有一张时不套 `PageView`，避免出现没有意义的翻页手势。模块缺失
/// 或条目都不带图片时，退回设计稿内置的宣传条，保证这个位置不会出现空洞。
///
/// 刷新首页时这个位置不允许闪，因此这里只换数据、不重建图片：
/// * 同一张图（URL 不变）沿用原来的 `Image` 元素，不会重新解析一遍
///   （`ImageProvider` 相等即不再拉图）；
/// * 换图时用 `gaplessPlayback`，新图解码好之前继续画旧的一帧，不出现空框；
/// * 内置宣传条是这一格的常驻底色，加载中 / 加载失败只是把底色露出来，
///   不会先塌成空白再弹回来；
/// * 刷新在途（[isRefreshing]）时拿到空列表不算数，继续展示上一次的 Banner，
///   等刷新结束、确认服务端确实没下发 Banner 才退回内置宣传条。
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
    this.isRefreshing = false,
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

  /// 首页是否正在刷新（下拉刷新 / 切回 Tab / 回到前台）。
  ///
  /// 刷新在途时列表可能短暂为空，这个标记让组件沿用上一次的 Banner，
  /// 而不是先把这一格换成内置宣传条、等新数据回来再换回去。
  final bool isRefreshing;

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

  /// 真正渲染出来的列表：刷新在途时可能是上一次下发的那一份。
  ///
  /// 单独存一份状态而不是直接用 `widget.banners`，是为了让「刷新期间列表短暂
  /// 为空」不会把已经展示的 Banner 拔掉；也顺带保证了同一批数据下子树的
  /// 位置稳定，不会因为父级重建而换掉 `Image` 元素。
  late List<HomeBannerData> _banners = widget.banners;

  late int _page = _startPage(_banners.length);
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
    // 刷新过程中下发的空列表先不认，等刷新结束再说；有新列表就立刻换新的。
    if (widget.banners.isNotEmpty || !widget.isRefreshing) {
      _banners = widget.banners;
    }
    if (oldWidget.banners.length != _banners.length) {
      _page = _startPage(_banners.length);
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
    if (!widget.isActive || !_foreground || _banners.length < 2) return;
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

  /// 设计稿内置的宣传条：这一格的常驻底色。
  ///
  /// 本地打包资源，首帧就能解码；网络图没就绪或加载失败时用户看到的是它，
  /// 而不是一块空白。
  Widget _promo() => Image.asset(
    HomeBanner._fallbackAsset,
    fit: BoxFit.fill,
    gaplessPlayback: true,
  );

  Widget _slide(HomeBannerData banner) => GestureDetector(
    key: ValueKey('home-banner-${banner.id}'),
    behavior: HitTestBehavior.opaque,
    onTap: () => widget.onTap(banner),
    child: Stack(
      fit: StackFit.expand,
      children: [
        _promo(),
        // 服务端 Banner 盖在底色上：还没解码出第一帧时它不画任何东西，露出的
        // 是底色；换图时 `gaplessPlayback` 让旧的一帧一直画到新图就绪。
        // 这里刻意不给 `loadingBuilder`：一旦加载中就换占位图，刷新时
        // 用户会看到「Banner → 宣传条 → Banner」的闪动。
        Image.network(
          banner.imageUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          // 失败时同样只留底色，不额外画错误占位。
          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final banners = _banners;
    final Widget content;
    if (banners.isEmpty) {
      content = _promo();
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
