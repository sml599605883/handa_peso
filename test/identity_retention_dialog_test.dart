import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/features/certification/identity_models.dart';
import 'package:handa_peso/features/certification/widgets/identity_retention_dialog.dart';

const _prompt = IdentityRetentionPrompt(
  title: "Don't lose your loan offer.",
  message: 'Verify your ID now.',
  imageUrl: 'https://example.test/retention.png',
  continueText: 'Get Funds',
  exitText: 'Go Back',
);

/// 服务端下发的是整幅弹窗背景（设计稿 327x379），这里按同尺寸生成一张，
/// 让按钮的叠放位置可以按设计坐标断言。
Future<Uint8List> _backgroundPng(WidgetTester tester) async {
  late Uint8List bytes;
  await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 327, 379),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final image = await recorder.endRecording().toImage(327, 379);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = data!.buffer.asUint8List();
  });
  return bytes;
}

Future<void> _open(
  WidgetTester tester, {
  required ImageProvider<Object> image,
  void Function(bool value)? onResult,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () async {
                final result = await showIdentityRetentionDialog(
                  context,
                  prompt: _prompt,
                  imageProvider: image,
                );
                onResult?.call(result);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  // 背景图先解码：测试环境里图片解码是真实异步，等弹窗自己加载会一直是占位态。
  await tester.runAsync(() async {
    await precacheImage(image, tester.element(find.byType(MaterialApp)));
  });
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('挽留弹窗用下发背景，按钮按设计坐标叠在背景底部', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final background = await _backgroundPng(tester);
    await _open(tester, image: MemoryImage(background));

    // 背景就是接口下发的那张图，不是客户端打包的切图。
    final backgroundImage = tester.widget<Image>(
      find.byKey(const Key('identity-retention-image')),
    );
    expect(backgroundImage.image, isA<MemoryImage>());

    final backgroundRect = tester.getRect(
      find.byKey(const Key('identity-retention-image')),
    );
    expect(backgroundRect.width, 327);
    expect(backgroundRect.height, 379);
    expect(backgroundRect.left, 24);

    // 标题与正文由背景图承载，客户端不再重复绘制。
    expect(find.text(_prompt.title), findsNothing);
    expect(find.text(_prompt.message), findsNothing);

    // 两枚按钮：138x52、间距 11、左右各让出 20、距背景底边 27。
    final exit = tester.getRect(find.byKey(const Key('identity-retention-exit')));
    final stay = tester.getRect(
      find.byKey(const Key('identity-retention-continue')),
    );
    expect(exit.width, 138);
    expect(exit.height, 52);
    expect(exit.left, 44);
    expect(stay.left, 193);
    expect(stay.width, 138);
    expect(exit.bottom, backgroundRect.bottom - 27);
    expect(stay.top, exit.top);

    // 按钮文案仍然取接口字段。
    expect(find.text('Go Back'), findsOneWidget);
    expect(find.text('Get Funds'), findsOneWidget);
  });

  testWidgets('继续与返回分别回传 true / false', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final background = await _backgroundPng(tester);
    bool? result;
    await _open(
      tester,
      image: MemoryImage(background),
      onResult: (value) => result = value,
    );

    await tester.tap(find.byKey(const Key('identity-retention-continue')));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('identity-retention-exit')));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });
}
