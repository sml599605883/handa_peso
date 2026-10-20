import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/certification/face_recognition_page.dart';
import 'package:handa_peso/features/certification/identity_design.dart';
import 'package:handa_peso/features/certification/identity_result_page.dart';
import 'package:handa_peso/features/certification/identity_type_page.dart';
import 'package:handa_peso/features/certification/identity_upload_page.dart';

/// 证件类型接口的固定载荷：两组各 5 项，与设计稿的按钮数量一致。
const String _typesBody =
    '{"unaccepted":"0","unstably":"success","indulgences":{'
    '"alleviated":[{"tonsil":[{"apivorous":"PRC ID"},{"apivorous":"SSS ID"},'
    '{"apivorous":"PHILIPPINE PASSPORT"},{"apivorous":"POSTAL ID"},'
    '{"apivorous":"UMID ID"}],'
    '"divagations":[{"apivorous":"TIN ID"},{"apivorous":"VOTER ID"},'
    '{"apivorous":"NATIONAL ID"},{"apivorous":"PAGIBIG ID"},'
    '{"apivorous":"HEALTH CARD"}]}]}}';

/// 真机抓到的形状：`alleviated` 为空、证件列表在 `pricklier` 的两行 code 里
/// （`GET /dropcloth/blockader?cotype=1`）。
const String _pricklierBody =
    '{"unaccepted":"0","unstably":"success","indulgences":{'
    '"chemistry":{"uppropped":0},'
    '"melancholies":{"uppropped":0},'
    '"alleviated":[],'
    '"pricklier":[["DRIVINGLICENSE","PRC","SSS","PASSPORT","POSTALID","UMID"],'
    '["TIN","VOTERID","NATIONALID","PAGIBIG","HEALTHCARD"]]}}';

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({this.body = _typesBody});

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    body,
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// 逐个方向核对矩形：设计坐标 → 逻辑像素是 1:1（画布 375 宽、缩放系数 1）。
void _expectRect(
  Rect rect, {
  required double left,
  required double top,
  required double width,
  required double height,
}) {
  expect(rect.left, moreOrLessEquals(left, epsilon: 0.51), reason: 'left');
  expect(rect.top, moreOrLessEquals(top, epsilon: 0.51), reason: 'top');
  expect(rect.width, moreOrLessEquals(width, epsilon: 0.51), reason: 'width');
  expect(
    rect.height,
    moreOrLessEquals(height, epsilon: 0.51),
    reason: 'height',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.put<GatewayClient>(
      GatewayClient(
        GatewaySettings(
          signSecret: 'unit-test-secret',
          localSession: LocalSession.memory(),
        ),
        dio: Dio()..httpClientAdapter = _StubAdapter(),
      ),
      permanent: true,
    );
  });
  tearDown(Get.reset);

  /// 按真实用法打开某一页：命名路由 + 路由参数。
  Future<void> openPage(
    WidgetTester tester, {
    required String route,
    required Widget page,
    Map<String, dynamic>? arguments,
    Size size = const Size(375, 812),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/stub',
        builder: EasyLoading.init(),
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/stub',
            page: () => const Scaffold(body: SizedBox()),
          ),
          GetPage<void>(name: route, page: () => page),
        ],
      ),
    );
    await tester.pumpAndSettle();
    Get.toNamed<void>(route, arguments: arguments);
    await tester.pumpAndSettle();
  }

  testWidgets('证件类型选择页的两张卡片、横幅与按钮落在设计坐标上', (tester) async {
    await openPage(
      tester,
      route: AppRoutes.certificationIdentity,
      page: const IdentityTypePage(),
      arguments: <String, dynamic>{'productId': '1000460'},
      size: const Size(375, 988),
    );

    // 卡片（设计稿 `box_3` / `box_4`：347x374 @ y=134 / 560）。
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-type-group-0'))),
      left: 14,
      top: 134,
      width: 347,
      height: 374,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-type-group-1'))),
      left: 14,
      top: 560,
      width: 347,
      height: 374,
    );

    // 横幅（设计稿 `编组 5` 349x66）压在卡片上沿之外 32px。
    final ribbons = find.byKey(const Key('identity-type-ribbon'));
    expect(ribbons, findsNWidgets(2));
    _expectRect(
      tester.getRect(ribbons.first),
      left: 12,
      top: 102,
      width: 349,
      height: 66,
    );
    _expectRect(
      tester.getRect(ribbons.last),
      left: 12,
      top: 528,
      width: 349,
      height: 66,
    );

    // 按钮 332x56 @ x=20，行距 68。
    for (final entry in <String, double>{
      'PRC ID': 166,
      'SSS ID': 234,
      'PHILIPPINE PASSPORT': 302,
      'POSTAL ID': 370,
      'UMID ID': 438,
    }.entries) {
      _expectRect(
        tester.getRect(find.byKey(Key('identity-type-${entry.key}'))),
        left: 20,
        top: entry.value,
        width: 332,
        height: 56,
      );
    }
    // 第二组按钮从 592 起，间距同样是 68。
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-type-TIN ID'))),
      left: 20,
      top: 592,
      width: 332,
      height: 56,
    );
  });

  testWidgets('线上只有 pricklier 时同样渲染两组证件，文案按设计稿', (tester) async {
    // 真机抓包：`alleviated` 为空，证件列表只在 `pricklier` 的两行 code 里。
    // `Get.put` 不会覆盖已注册实例，这里显式替换 setUp 里的那个。
    Get.replace<GatewayClient>(
      GatewayClient(
        GatewaySettings(
          signSecret: 'unit-test-secret',
          localSession: LocalSession.memory(),
        ),
        dio: Dio()..httpClientAdapter = _StubAdapter(body: _pricklierBody),
      ),
    );
    await openPage(
      tester,
      route: AppRoutes.certificationIdentity,
      page: const IdentityTypePage(),
      arguments: <String, dynamic>{'productId': '1'},
      size: const Size(375, 988),
    );

    // 第一组 6 项：卡片按数量撑开到 32 + 6 行 * 68 + 14 = 442。
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-type-group-0'))),
      left: 14,
      top: 134,
      width: 347,
      height: 442,
    );
    // 第二组 5 项：还是设计稿的 374，起点随第一组下移（134 + 442 + 52 = 628）。
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-type-group-1'))),
      left: 14,
      top: 628,
      width: 347,
      height: 374,
    );
    // 第 6 个按钮落在卡片内的最后一行。
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-type-UMID'))),
      left: 20,
      top: 134 + 32 + 5 * 68,
      width: 332,
      height: 56,
    );
    // 直接展示服务端下发的内容，不做显示名映射。
    for (final code in const <String>[
      'DRIVINGLICENSE',
      'PRC',
      'SSS',
      'PASSPORT',
      'POSTALID',
      'UMID',
      'TIN',
      'VOTERID',
      'NATIONALID',
      'PAGIBIG',
      'HEALTHCARD',
    ]) {
      expect(find.text(code), findsOneWidget, reason: code);
    }

    // 画布要跟着卡片一起长高：6 项时内容比设计稿的 988 更高，
    // 画布固定高度的话多出来的部分滚不到，第二张卡会被截断。
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
  });

  testWidgets('上传页的卡片头部、卡片正文、示范切图与按钮落在设计坐标上', (tester) async {
    await openPage(
      tester,
      route: AppRoutes.certificationIdentityUpload,
      page: const IdentityUploadPage(),
      arguments: <String, dynamic>{
        'productId': '1000460',
        'cardType': 'SSS ID',
      },
    );

    _expectRect(
      tester.getRect(find.byKey(const Key('identity-upload-pill'))),
      left: 14,
      top: 186,
      width: 347,
      height: 46,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-upload-card'))),
      left: 14,
      top: 186,
      width: 347,
      height: 397,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-upload-demo'))),
      left: 19,
      top: 250,
      width: 328,
      height: 312,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-upload-submit'))),
      left: 77.5,
      top: 603,
      width: 220,
      height: 52,
    );

    // 设计稿里标题层直接叠在整张卡片的顶部：底卡也从 y=186 开始，标题和
    // 下面的示范内容同属一个 347x397 的容器。
    final card = tester.widget<Container>(
      find.byKey(const Key('identity-upload-card')),
    );
    final header = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('identity-upload-pill')),
            matching: find.byType(Container),
          )
          .first,
    );
    final cardDecoration = card.decoration! as BoxDecoration;
    final headerDecoration = header.decoration! as BoxDecoration;
    expect(cardDecoration.border, isNotNull);
    expect(headerDecoration.border, isNotNull);
    expect(
      tester.getRect(find.byKey(const Key('identity-upload-card'))).top,
      tester.getRect(find.byKey(const Key('identity-upload-pill'))).top,
    );
    expect(find.byKey(const Key('identity-hero-banner')), findsOneWidget);
    expect(
      headerDecoration.borderRadius,
      BorderRadius.vertical(top: Radius.circular(IdentityDesign.cardRadius)),
    );
    expect(
      cardDecoration.borderRadius,
      BorderRadius.vertical(bottom: Radius.circular(IdentityDesign.cardRadius)),
    );
  });

  testWidgets('人脸识别页按设计稿还原标题、示范卡与 Next 按钮', (tester) async {
    await openPage(
      tester,
      route: AppRoutes.certificationFace,
      page: const FaceRecognitionPage(),
      arguments: <String, dynamic>{
        'productId': '1000460',
        'orderNo': 'ORDER-1000460',
        'cardType': 'SSS ID',
      },
    );

    expect(find.text('Document verification'), findsOneWidget);
    expect(find.text('Demonstration!'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.byKey(const Key('identity-hero-banner')), findsOneWidget);
    final background = tester.widget<DecoratedBox>(
      find.byKey(const Key('identity-background')),
    );
    final gradient =
        (background.decoration as BoxDecoration).gradient! as LinearGradient;
    expect(gradient.begin, Alignment.topCenter);
    expect(gradient.end, Alignment.bottomCenter);
    expect(gradient.colors.first, const Color(0xFFF09D87));
    expect(gradient.colors.last, const Color(0xFFFFFFFF));
    _expectRect(
      tester.getRect(find.byKey(const Key('face-recognition-pill'))),
      left: 14,
      top: 186,
      width: 347,
      height: 46,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('face-recognition-card'))),
      left: 14,
      top: 186,
      width: 347,
      height: 397,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('face-recognition-demo'))),
      left: 19,
      top: 250,
      width: 328,
      height: 312,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('face-recognition-submit'))),
      left: 77.5,
      top: 603,
      width: 220,
      height: 52,
    );
    final demo = tester.widget<Image>(
      find.byKey(const Key('face-recognition-demo')),
    );
    expect((demo.image as AssetImage).assetName, IdentityAssets.faceDemoCard);
  });

  testWidgets('上传成功页的卡片、证件位、三条信息与按钮落在设计坐标上', (tester) async {
    await openPage(
      tester,
      route: AppRoutes.certificationIdentityResult,
      page: const IdentityResultPage(),
      arguments: <String, dynamic>{
        'productId': '1000460',
        'cardType': 'SSS ID',
        'sceneStartSeconds': 0,
        'definitively': 'BANBU',
        'optically': '3877409801987862',
        'gleeking': '23-02-1996',
        'tidewaters': '',
      },
    );

    _expectRect(
      tester.getRect(find.byKey(const Key('identity-result-pill'))),
      left: 14,
      top: 186,
      width: 347,
      height: 46,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-result-card'))),
      left: 14,
      top: 186,
      width: 347,
      height: 254,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-result-photo'))),
      left: 34,
      top: 252,
      width: 307,
      height: 167,
    );
    for (var index = 0; index < 3; index++) {
      _expectRect(
        tester.getRect(find.byKey(Key('identity-result-row-$index'))),
        left: 14,
        top: 454 + index * 62,
        width: 347,
        height: 48,
      );
    }
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-result-submit'))),
      left: 77.5,
      top: 646,
      width: 220,
      height: 52,
    );

    // 识别结果原样展示在右侧（证件号不加空格、生日归一成 `d-m-Y`）。
    expect(find.text('BANBU'), findsOneWidget);
    expect(find.text('3877409801987862'), findsOneWidget);
    expect(find.text('23-02-1996'), findsOneWidget);
    expect(find.byKey(const Key('identity-hero-banner')), findsOneWidget);
    final nameField = tester.widget<TextField>(
      find.byKey(const Key('identity-result-name')),
    );
    expect(nameField.decoration?.filled, isFalse);
    final row = tester.getRect(find.byKey(const Key('identity-result-row-0')));
    final input = tester.getRect(find.byKey(const Key('identity-result-name')));
    expect(
      input.right,
      moreOrLessEquals(
        row.right -
            IdentityDesign.resultRowBorder -
            IdentityDesign.resultRowPadding,
        epsilon: 0.51,
      ),
    );
    expect(
      input.width,
      moreOrLessEquals(
        row.width -
            IdentityDesign.resultRowBorder * 2 -
            IdentityDesign.resultRowPadding * 2 -
            IdentityDesign.resultLabelWidth,
        epsilon: 0.51,
      ),
    );

    final card = tester.widget<Container>(
      find.byKey(const Key('identity-result-card')),
    );
    final header = tester.widget<Container>(
      find
          .descendant(
            of: find.byKey(const Key('identity-result-pill')),
            matching: find.byType(Container),
          )
          .first,
    );
    final cardDecoration = card.decoration! as BoxDecoration;
    final headerDecoration = header.decoration! as BoxDecoration;
    expect(
      tester.getRect(find.byKey(const Key('identity-result-card'))).top,
      tester.getRect(find.byKey(const Key('identity-result-pill'))).top,
    );
    expect(
      cardDecoration.borderRadius,
      BorderRadius.vertical(bottom: Radius.circular(IdentityDesign.cardRadius)),
    );
    expect(
      headerDecoration.borderRadius,
      BorderRadius.vertical(top: Radius.circular(IdentityDesign.cardRadius)),
    );
  });

  testWidgets('宽屏机型（iPhone XR 414）不会横向超出屏幕', (tester) async {
    // 适配口径与 Dali 的 ScreenAdapter 一致：缩放系数 = 屏幕宽 / 375，
    // 页面里只换算一次；再叠一层画布缩放会让右边出屏。
    const screenWidth = 414.0;
    const ratio = screenWidth / IdentityDesign.pageWidth;
    await openPage(
      tester,
      route: AppRoutes.certificationIdentity,
      page: const IdentityTypePage(),
      arguments: <String, dynamic>{'productId': '1'},
      size: const Size(screenWidth, 896),
    );

    for (final key in const <String>[
      'identity-type-group-0',
      'identity-type-group-1',
    ]) {
      final rect = tester.getRect(find.byKey(Key(key)));
      expect(rect.left, moreOrLessEquals(14 * ratio, epsilon: 0.5));
      expect(rect.width, moreOrLessEquals(347 * ratio, epsilon: 0.5));
      expect(rect.right, lessThanOrEqualTo(screenWidth - 14 * ratio + 0.5));
    }
    // setUp 的桩用的是 `alleviated` 里的显示名，因此 key 就是这名。
    final button = tester.getRect(
      find.byKey(const Key('identity-type-PRC ID')),
    );
    expect(button.right, lessThanOrEqualTo(screenWidth));
  });

  testWidgets('认证方式弹层的 Camera / Album 两行与按钮落在设计坐标上', (tester) async {
    await openPage(
      tester,
      route: AppRoutes.certificationIdentityUpload,
      page: const IdentityUploadPage(),
      arguments: <String, dynamic>{
        'productId': '1000460',
        'cardType': 'SSS ID',
      },
    );
    await tester.tap(find.byKey(const Key('identity-upload-submit')));
    await tester.pumpAndSettle();

    _expectRect(
      tester.getRect(find.byKey(const Key('identity-upload-method-sheet'))),
      left: 0,
      top: 504,
      width: 375,
      height: 308,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-upload-method-camera'))),
      left: 24,
      top: 566,
      width: 327,
      height: 48,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-upload-method-submit'))),
      left: 77.5,
      top: 706,
      width: 220,
      height: 52,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-upload-method-album'))),
      left: 24,
      top: 634,
      width: 327,
      height: 48,
    );
  });

  testWidgets('成功页三行可编辑，生日选择器落在设计坐标上', (tester) async {
    await openPage(
      tester,
      route: AppRoutes.certificationIdentityResult,
      page: const IdentityResultPage(),
      arguments: <String, dynamic>{
        'productId': '1000460',
        'cardType': 'SSS ID',
        'sceneStartSeconds': 0,
        'definitively': 'BANBU',
        'optically': '3877409801987862',
        'gleeking': '23-02-1996',
        'tidewaters': '',
      },
    );
    // 姓名 / 证件号是输入框，出生日期是点开滚轮的只读行。
    expect(find.byKey(const Key('identity-result-name')), findsOneWidget);
    expect(find.byKey(const Key('identity-result-id')), findsOneWidget);

    await tester.tap(find.byKey(const Key('identity-result-row-2')));
    await tester.pumpAndSettle();

    // 面板从 y=344 起、高 468；选中条 327x48 @ (24,520)；Submit 与取图弹层同在 706。
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-birthday-panel'))),
      left: 0,
      top: 344,
      width: 375,
      height: 468,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-birthday-band'))),
      left: 24,
      top: 520,
      width: 327,
      height: 48,
    );
    _expectRect(
      tester.getRect(find.byKey(const Key('identity-birthday-submit'))),
      left: 77.5,
      top: 706,
      width: 220,
      height: 52,
    );
    // 日 / 月 / 年三列滚轮。
    expect(find.byKey(const Key('identity-birthday-day')), findsOneWidget);
    expect(find.byKey(const Key('identity-birthday-month')), findsOneWidget);
    expect(find.byKey(const Key('identity-birthday-year')), findsOneWidget);
  });
}
