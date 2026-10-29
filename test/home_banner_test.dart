import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/features/home/home_banner.dart';
import 'package:handa_peso/features/home/home_data.dart';

/// 缺陷 reczz28T3eWSK6tN 的回归测试：刷新首页时 Banner 不能闪。
///
/// 现场表现是「Banner → 空白 → 内置宣传条 → Banner」：刷新拿到的是同一张图，
/// 但图片元素被重建、`ImageProvider` 重新解析，旧的一帧被丢掉，加载中又被
/// 占位图顶掉。这里的用例把这几条约束固定下来：
/// * 刷新在途（[HomeBanner.isRefreshing]）时旧 Banner 还在树上；
/// * 图片 widget（`State` 实例）与 `ImageProvider` 都不重建；
/// * 换图时靠 `gaplessPlayback` 保留旧的一帧，不再挂加载占位；
/// * 这一格任何状态下都有内置宣传条兜底，不会是一块空白。

const HomeBannerData _bannerA = HomeBannerData(
  id: '7',
  imageUrl: 'http://example.test/banner-7.png',
  targetUrl: 'http://example.test/landing/7',
);

const HomeBannerData _bannerB = HomeBannerData(
  id: '7',
  imageUrl: 'http://example.test/banner-7-v2.png',
  targetUrl: 'http://example.test/landing/7',
);

Widget _host(HomeBanner banner) => MaterialApp(
  home: Scaffold(
    body: SizedBox(width: 375, child: banner),
  ),
);

/// Banner 里真正加载服务端图片的那个 `Image`（内置宣传条用的是 AssetImage）。
Finder _networkImage() => find.descendant(
  of: find.byKey(const ValueKey('home-banner-7')),
  matching: find.byWidgetPredicate(
    (widget) => widget is Image && widget.image is NetworkImage,
  ),
);

void main() {
  testWidgets('刷新在途时旧 Banner 仍在树上，图片 widget 不重建', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBanner(
          banners: const <HomeBannerData>[_bannerA],
          scale: 1,
          onTap: (_) {},
        ),
      ),
    );

    final image = tester.widget<Image>(_networkImage());
    final state = tester.state(_networkImage());
    final provider = image.image;

    // 刷新在途：网关这一帧还没有新数据（列表为空），标记为刷新中。
    await tester.pumpWidget(
      _host(
        HomeBanner(
          banners: const <HomeBannerData>[],
          scale: 1,
          isRefreshing: true,
          onTap: (_) {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('home-banner-7')), findsOneWidget);
    expect(identical(tester.state(_networkImage()), state), isTrue);
    expect(tester.widget<Image>(_networkImage()).image, equals(provider));
  });

  testWidgets('同一张图的新数据只换数据，不重建图片元素', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBanner(
          banners: const <HomeBannerData>[_bannerA],
          scale: 1,
          onTap: (_) {},
        ),
      ),
    );
    final state = tester.state(_networkImage());
    final provider = tester.widget<Image>(_networkImage()).image;

    // 刷新回来：id / URL 都一样，只是新的对象实例。
    await tester.pumpWidget(
      _host(
        HomeBanner(
          banners: const <HomeBannerData>[
            HomeBannerData(
              id: '7',
              imageUrl: 'http://example.test/banner-7.png',
              targetUrl: 'http://example.test/landing/7',
            ),
          ],
          scale: 1,
          isRefreshing: true,
          onTap: (_) {},
        ),
      ),
    );

    expect(identical(tester.state(_networkImage()), state), isTrue);
    expect(tester.widget<Image>(_networkImage()).image, equals(provider));
  });

  testWidgets('换图时保留旧的一帧，不挂加载占位', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBanner(
          banners: const <HomeBannerData>[_bannerA],
          scale: 1,
          onTap: (_) {},
        ),
      ),
    );
    final state = tester.state(_networkImage());

    await tester.pumpWidget(
      _host(
        HomeBanner(
          banners: const <HomeBannerData>[_bannerB],
          scale: 1,
          onTap: (_) {},
        ),
      ),
    );

    final image = tester.widget<Image>(_networkImage());
    // 元素没被重建，换图交给 gaplessPlayback：新图解码好之前一直画旧的一帧。
    expect(identical(tester.state(_networkImage()), state), isTrue);
    expect(
      image.image,
      equals(const NetworkImage('http://example.test/banner-7-v2.png')),
    );
    expect(image.gaplessPlayback, isTrue);
    // 没有 loadingBuilder：加载中不会把这一格换成占位图。
    expect(image.loadingBuilder, isNull);
  });

  testWidgets('网络图未就绪或失败时，这一格仍有内置宣传条', (tester) async {
    // widget 测试里所有网络请求都会失败，正好覆盖「加载失败」这条路径。
    await tester.pumpWidget(
      _host(
        HomeBanner(
          banners: const <HomeBannerData>[_bannerA],
          scale: 1,
          onTap: (_) {},
        ),
      ),
    );

    final promo = find.descendant(
      of: find.byKey(const ValueKey('home-banner-7')),
      matching: find.byWidgetPredicate(
        (widget) => widget is Image && widget.image is AssetImage,
      ),
    );
    expect(promo, findsOneWidget);
    expect(tester.getSize(find.byType(HomeBanner)).height, 130);
  });

  testWidgets('刷新结束且确认没有 Banner 时才退回内置宣传条', (tester) async {
    await tester.pumpWidget(
      _host(
        HomeBanner(
          banners: const <HomeBannerData>[_bannerA],
          scale: 1,
          onTap: (_) {},
        ),
      ),
    );

    await tester.pumpWidget(
      _host(
        HomeBanner(
          banners: const <HomeBannerData>[],
          scale: 1,
          isRefreshing: false,
          onTap: (_) {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('home-banner-7')), findsNothing);
    expect(
      find.descendant(
        of: find.byType(HomeBanner),
        matching: find.byWidgetPredicate(
          (widget) => widget is Image && widget.image is AssetImage,
        ),
      ),
      findsOneWidget,
    );
  });
}
