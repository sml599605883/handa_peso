import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/startup/startup_network_gate.dart';
import 'package:handa_peso/core/bootstrap/app_bootstrap.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/report/report_bridge.dart';
import 'package:handa_peso/core/report/report_service.dart';
import 'package:handa_peso/core/report/report_store.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/main.dart';

/// 空转适配器：本次回归只关心上报模块是否被启动与转发，不关心具体请求。
class _IdleAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    jsonEncode(<String, Object?>{
      'unaccepted': 0,
      'unstably': 'ok',
      'indulgences': <String, Object?>{},
    }),
    200,
    headers: <String, List<String>>{
      Headers.contentTypeHeader: <String>[Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

/// 只记录调用次数的上报服务：避免测试触碰原生通道与落盘。
class _SpyReportService extends ReportService {
  _SpyReportService(GatewayClient client)
    : super(
        gatewayClient: client,
        store: ReportStore.memory(),
        bridge: ReportNativeBridge(available: false),
      );

  int startCalls = 0;
  int resumeCalls = 0;

  @override
  Future<void> start() async => startCalls++;

  @override
  Future<void> resumed() async => resumeCalls++;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SpyReportService spy;
  late AppDependencies dependencies;

  setUp(() {
    final session = LocalSession.memory();
    final settings = GatewaySettings(
      apiOrigin: 'http://127.0.0.1:1',
      signSecret: 'unit-test-secret',
      localSession: session,
      noiseDigits: (length) => '1' * length,
    );
    final client = GatewayClient(
      settings,
      dio: Dio()..httpClientAdapter = _IdleAdapter(),
    );
    spy = _SpyReportService(client);
    dependencies = AppDependencies(
      gatewayClient: client,
      localSession: session,
      reportService: spy,
    );
  });

  tearDown(Get.reset);

  testWidgets('启动流程注册并启动上报服务，同时挂上生命周期转发', (tester) async {
    Widget? launched;
    await startHandaPeso(
      bootstrap: () async => dependencies,
      runApplication: (app) => launched = app,
      lockOrientation: () async {},
    );

    expect(Get.isRegistered<ReportService>(), isTrue);
    expect(Get.find<ReportService>(), same(spy));
    expect(spy.startCalls, 1);
    expect(launched, isA<StartupNetworkGate>());

    // 回到前台才补报；系统弹窗造成的 inactive/paused 不得触发。
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(spy.resumeCalls, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(spy.resumeCalls, 1);
  });

  testWidgets('上报服务缺席时启动流程仍能跑通', (tester) async {
    final withoutReport = AppDependencies(
      gatewayClient: dependencies.gatewayClient,
      localSession: dependencies.localSession,
    );

    await startHandaPeso(
      bootstrap: () async => withoutReport,
      runApplication: (_) {},
      lockOrientation: () async {},
    );

    expect(Get.isRegistered<ReportService>(), isFalse);
  });
}
