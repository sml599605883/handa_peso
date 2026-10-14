import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/bootstrap/app_bootstrap.dart';
import 'package:handa_peso/core/client/device_bridge.dart';
import 'package:handa_peso/core/network/api_client.dart';
import 'package:handa_peso/core/network/api_config.dart';
import 'package:handa_peso/core/session/session_store.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// 抓包回归：Dart 的 HttpClient 不读取 iOS 系统代理，因此代理必须由原生层
/// 透出，并在首个请求之前应用到 Dio 上。覆盖原生解析、Dio 改造与启动接线。
const _channel = MethodChannel(DeviceBridge.channelName);

final _successEnvelope = jsonEncode(<String, Object?>{
  'unaccepted': 0,
  'unstably': 'success',
  'indulgences': <String, Object?>{},
});

ApiConfig _config({String apiBaseUrl = 'http://127.0.0.1:1'}) {
  return ApiConfig(
    apiBaseUrl: apiBaseUrl,
    signatureSecret: 'unit-test-secret',
    sessionStore: SessionStore.memory(),
    timestampProvider: () => 1700000000000,
    randomDigitsProvider: (length) => '1' * length,
  );
}

void _mockBridge(Map<String, Object?> Function(MethodCall call) handler) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_channel, (call) async => handler(call));
}

Map<String, Object?> _platformInfo() => <String, Object?>{
  'platform': 'iPhone15,2',
  'systemVersion': '17.4',
  'appVersion': '1.0.0',
  'buildNumber': '1',
  'deviceId': 'idfv-stable',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
  });

  group('ClientProxySettings', () {
    test('accepts an enabled proxy payload from the native bridge', () {
      final settings = ClientProxySettings.fromMap(<Object?, Object?>{
        'enabled': true,
        'host': '192.168.1.8',
        'port': 8888,
      });

      expect(settings.enabled, isTrue);
      expect(settings.host, '192.168.1.8');
      expect(settings.port, 8888);
      expect(settings.canApply, isTrue);
    });

    test('rejects disabled or incomplete payloads', () {
      expect(
        ClientProxySettings.fromMap(<Object?, Object?>{
          'enabled': false,
          'host': '192.168.1.8',
          'port': 8888,
        }).canApply,
        isFalse,
      );
      expect(
        ClientProxySettings.fromMap(<Object?, Object?>{
          'enabled': true,
          'host': '',
          'port': 8888,
        }).canApply,
        isFalse,
      );
      expect(
        ClientProxySettings.fromMap(<Object?, Object?>{
          'enabled': true,
          'host': '192.168.1.8',
          'port': 0,
        }).canApply,
        isFalse,
      );
    });
  });

  group('DeviceBridge.proxySettings', () {
    test('reads host and port from the iOS bridge', () async {
      final methods = <String>[];
      _mockBridge((call) {
        methods.add(call.method);
        return <String, Object?>{
          'enabled': true,
          'host': '127.0.0.1',
          'port': 8888,
        };
      });

      final settings = await DeviceBridge(supported: true).proxySettings();

      expect(methods, <String>['getProxySettings']);
      expect(settings?.host, '127.0.0.1');
      expect(settings?.port, 8888);
      expect(settings?.canApply, isTrue);
    });

    test('returns null when the native side reports no proxy', () async {
      _mockBridge(
        (call) => <String, Object?>{'enabled': false, 'host': '', 'port': 0},
      );

      final settings = await DeviceBridge(supported: true).proxySettings();

      expect(settings?.canApply, isFalse);
    });

    test('returns null when the native bridge is unavailable', () async {
      expect(await DeviceBridge(supported: false).proxySettings(), isNull);
    });
  });

  group('ApiClient.setProxy', () {
    // flutter_test 的绑定会把所有请求拦截成 400，抓包验证需要真实的本机
    // HTTP 服务，因此这里恢复默认的 HttpClient 行为。
    setUp(() => HttpOverrides.global = null);

    test('routes requests through the configured system proxy', () async {
      final targetServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final proxyServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final proxiedPaths = <String>[];
      var targetRequests = 0;

      addTearDown(() async {
        await targetServer.close(force: true);
        await proxyServer.close(force: true);
      });

      targetServer.listen((request) {
        targetRequests++;
        request.response
          ..statusCode = 200
          ..write(_successEnvelope)
          ..close();
      });
      proxyServer.listen((request) {
        proxiedPaths.add(request.uri.path);
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(_successEnvelope)
          ..close();
      });

      final apiClient = ApiClient(_config())
        ..setProxy(host: '127.0.0.1', port: proxyServer.port);

      await apiClient.get('/dropcloth/fishtailed');

      expect(apiClient.proxyHost, '127.0.0.1');
      expect(apiClient.proxyPort, proxyServer.port);
      expect(proxiedPaths, <String>['/dropcloth/fishtailed']);
      expect(targetRequests, 0);
    });

    test('replaces an already-created direct connection', () async {
      final targetServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      final proxyServer = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      var targetRequests = 0;
      var proxyRequests = 0;

      addTearDown(() async {
        await targetServer.close(force: true);
        await proxyServer.close(force: true);
      });

      targetServer.listen((request) {
        targetRequests++;
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(_successEnvelope)
          ..close();
      });
      proxyServer.listen((request) {
        proxyRequests++;
        request.response
          ..statusCode = 200
          ..headers.contentType = ContentType.json
          ..write(_successEnvelope)
          ..close();
      });

      final apiClient = ApiClient(
        _config(apiBaseUrl: 'http://127.0.0.1:${targetServer.port}'),
      );

      await apiClient.get('/dropcloth/fishtailed');
      expect(apiClient.proxyHost, isNull);
      expect(targetRequests, 1);
      expect(proxyRequests, 0);

      apiClient.setProxy(host: '127.0.0.1', port: proxyServer.port);
      await apiClient.get('/dropcloth/fishtailed');

      expect(targetRequests, 1);
      expect(proxyRequests, 1);
    });
  });

  group('AppBootstrap.initialize', () {
    test('applies the native system proxy before returning', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Handa Peso',
        packageName: 'ph.handapeso.app',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      _mockBridge((call) {
        if (call.method == 'getPlatformInfo') return _platformInfo();
        expect(call.method, 'getProxySettings');
        return <String, Object?>{
          'enabled': true,
          'host': '127.0.0.1',
          'port': 8888,
        };
      });

      final dependencies = await AppBootstrap.initialize(
        sessionStoreFactory: SessionStore.memory,
        deviceBridge: DeviceBridge(supported: true),
      );

      expect(dependencies.apiClient.proxyHost, '127.0.0.1');
      expect(dependencies.apiClient.proxyPort, 8888);
    });

    test('stays direct when the device has no system proxy', () async {
      PackageInfo.setMockInitialValues(
        appName: 'Handa Peso',
        packageName: 'ph.handapeso.app',
        version: '1.0.0',
        buildNumber: '1',
        buildSignature: '',
      );
      _mockBridge((call) {
        if (call.method == 'getPlatformInfo') return _platformInfo();
        return <String, Object?>{'enabled': false, 'host': '', 'port': 0};
      });

      final dependencies = await AppBootstrap.initialize(
        sessionStoreFactory: SessionStore.memory,
        deviceBridge: DeviceBridge(supported: true),
      );

      expect(dependencies.apiClient.proxyHost, isNull);
      expect(dependencies.apiClient.proxyPort, isNull);
    });
  });
}
