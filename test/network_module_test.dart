import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/client/platform_bridge.dart';
import 'package:handa_peso/core/device/device_info_sync.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/network/gateway_failure.dart';
import 'package:handa_peso/core/network/wire_format.dart';
import 'package:handa_peso/core/network/gateway_reply.dart';
import 'package:handa_peso/core/network/request_signer.dart';
import 'package:handa_peso/core/session/local_session.dart';

GatewaySettings buildConfig({String secret = 'unit-test-secret'}) {
  return GatewaySettings(
    signSecret: secret,
    appVersion: '1.0.0',
    deviceLabel: 'iPhone15,2',
    deviceId: 'idfv-123',
    systemVersion: '17.0',
    localSession: LocalSession.memory(),
    clock: () => 1700000000000,
    noiseDigits: (length) => '1' * length,
  );
}

/// 脚本化 Dio 适配器：按测试给的脚本决定状态码与响应体。
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) => handler(options);

  @override
  void close({bool force = false}) {}
}

GatewayClient _stubbedClient(_StubAdapter adapter) =>
    GatewayClient(buildConfig(), dio: Dio()..httpClientAdapter = adapter);

void main() {
  group('RequestSigner', () {
    test('builds the signed public parameter set for a path', () async {
      final config = buildConfig();
      final query = await RequestSigner(config)
          .signedQuery(path: '/dropcloth/fishtailed');

      expect(query['procuration'], '1.0.0');
      expect(query['especially'], 'iPhone15,2');
      expect(query['corkscrewed'], 'idfv-123');
      expect(query['parcener'], 'idfv-123');
      expect(query['truculency'], '17.0');
      expect(query['muttonfishes'], 'appstore-ph-handa-peso-ios');
      expect(query['sandman'], '');
      expect(query['absorbing'], '1700000000000');
      expect(query['wrencher'], '111111');

      final expected = RequestSigner.signatureOf({
        'procuration': '1.0.0',
        'especially': 'iPhone15,2',
        'corkscrewed': 'idfv-123',
        'truculency': '17.0',
        'muttonfishes': 'appstore-ph-handa-peso-ios',
        'sandman': '',
        'parcener': 'idfv-123',
        'absorbing': '1700000000000',
        'distorters': '/dropcloth/fishtailed',
      }, 'unit-test-secret');
      expect(query['lasses'], expected);
    });

    test('signs values in ascending key order', () {
      final signature = RequestSigner.signatureOf({'b': '2', 'a': '1'}, 'secret');
      expect(signature, RequestSigner.signatureOf({'a': '1', 'b': '2'}, 'secret'));
      expect(
        signature,
        isNot(RequestSigner.signatureOf({'a': '2', 'b': '1'}, 'secret')),
      );
    });

    test('strips host and query before signing', () {
      expect(
        RequestSigner.routeOf('http://8.220.135.86/dropcloth/checkreins?x=1'),
        '/dropcloth/checkreins',
      );
      expect(
        RequestSigner.routeOf('/dropcloth/checkreins?x=1'),
        '/dropcloth/checkreins',
      );
    });

    test('fails fast when the signing secret is missing', () async {
      final config = buildConfig(secret: '');
      await expectLater(
        RequestSigner(config).signedQuery(path: '/dropcloth/fishtailed'),
        throwsA(
          isA<GatewayFailure>().having((e) => e.code, 'code', 'configuration'),
        ),
      );
    });
  });

  group('GatewayReply', () {
    test('unwraps a success envelope', () {
      final response = GatewayReply.parse({
        WireFormat.statusField: 0,
        WireFormat.noteField: 'success',
        WireFormat.payloadField: {'sandman': 'session-1'},
      });

      expect(response.isAccepted, isTrue);
      expect(response.note, 'success');
      expect(response.payload['sandman'], 'session-1');
    });

    test('treats 20000 as success for the liveness bind-card flow', () {
      final response = GatewayReply.parse({
        WireFormat.statusField: 20000,
        WireFormat.noteField: '',
        WireFormat.payloadField: <String, dynamic>{},
      });
      expect(response.isAccepted, isTrue);
    });

    test('nests a bare list payload under list', () {
      final response = GatewayReply.parse({
        WireFormat.statusField: '0',
        WireFormat.noteField: 'success',
        WireFormat.payloadField: [1, 2, 3],
      });
      expect(response.payload['list'], [1, 2, 3]);
    });

    test('flags an expired session', () {
      final response = GatewayReply.parse({
        WireFormat.statusField: -2,
        WireFormat.noteField: 'not logged in',
      });
      expect(response.isSessionExpired, isTrue);
    });

    test('throws a coded error for business failures', () {
      final response = GatewayReply.parse({
        WireFormat.statusField: 505,
        WireFormat.noteField: 'rejected',
      });
      expect(
        () => response.orThrow(),
        throwsA(
          isA<GatewayFailure>()
              .having((e) => e.code, 'code', 505)
              .having((e) => e.message, 'message', 'rejected'),
        ),
      );
    });

    test('rejects a non-map payload', () {
      final response = GatewayReply.parse('<html>gateway error</html>');
      expect(response.status, GatewayReply.malformedStatus);
      expect(response.isAccepted, isFalse);
    });
  });

  group('GatewayTransport 的 HTTP 错误', () {
    test('优先展示响应体里接口下发的文案', () async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            WireFormat.statusField: 500,
            WireFormat.noteField: 'Verification code has expired',
          }),
          500,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );

      await expectLater(
        _stubbedClient(adapter).requestSmsCode(phone: '9171234567'),
        throwsA(
          isA<GatewayFailure>()
              .having(
                (e) => e.message,
                'message',
                'Verification code has expired',
              )
              .having((e) => e.code, 'code', 'http_500')
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('响应体不是网关信封时退回本地文案', () async {
      final adapter = _StubAdapter(
        (options) async =>
            ResponseBody.fromString('<html>502 Bad Gateway</html>', 502),
      );

      await expectLater(
        _stubbedClient(adapter).requestSmsCode(phone: '9171234567'),
        throwsA(
          isA<GatewayFailure>()
              .having((e) => e.message, 'message', 'Request failed (502).')
              .having((e) => e.code, 'code', 'http_502'),
        ),
      );
    });

    test('401 仍然按会话失效处理', () async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          jsonEncode(<String, dynamic>{
            WireFormat.statusField: 401,
            WireFormat.noteField: 'Unauthorized',
          }),
          401,
          headers: const <String, List<String>>{
            Headers.contentTypeHeader: <String>[Headers.jsonContentType],
          },
        ),
      );

      await expectLater(
        _stubbedClient(adapter).requestSmsCode(phone: '9171234567'),
        throwsA(
          isA<GatewayFailure>().having(
            (e) => e.isUnauthorized,
            'isUnauthorized',
            isTrue,
          ),
        ),
      );
    });
  });

  group('DeviceInfoSync', () {
    const channel = MethodChannel(PlatformBridge.channelName);

    setUp(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null);
    });

    test('fills the signed public parameters from the native bridge', () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'getPlatformInfo') {
              return <String, Object?>{
                'platform': 'iPhone15,2',
                'systemVersion': '17.4',
                'appVersion': '2.3.1',
                'buildNumber': '42',
                'deviceId': 'idfv-stable',
              };
            }
            return null;
          });

      final config = GatewaySettings(
        localSession: LocalSession.memory(),
        appVersion: '',
        clock: () => 1700000000000,
        noiseDigits: (length) => '1' * length,
      );
      final sync = DeviceInfoSync(
        gatewayClient: GatewayClient(config),
        bridge: PlatformBridge(available: true, channel: channel),
        localSession: LocalSession.memory(),
      );

      final model = await sync.applyDeviceIdentity(config);

      expect(model, 'iPhone15,2');
      expect(config.deviceId, 'idfv-stable');
      expect(config.pairedDeviceId, 'idfv-stable');
      expect(config.systemVersion, '17.4');
      expect(config.appVersion, '2.3.1');
      expect(config.deviceLabel, 'iPhone15,2');

      final query = await RequestSigner(config)
          .signedQuery(path: '/dropcloth/pyranoside');
      expect(query['corkscrewed'], 'idfv-stable');
      expect(query['parcener'], 'idfv-stable');
      expect(query['truculency'], '17.4');
      expect(query['procuration'], '2.3.1');
      expect(query['especially'], 'iPhone15,2');
    });

    test('falls back to the cached device name without the bridge', () async {
      final store = LocalSession.memory();
      await store.writeDeviceLabel('Handa Tester');
      final config = GatewaySettings(localSession: store, appVersion: '1.0.0');
      final sync = DeviceInfoSync(
        gatewayClient: GatewayClient(config),
        bridge: PlatformBridge(available: false),
        localSession: store,
      );

      final model = await sync.applyDeviceIdentity(config);

      expect(model, isNull);
      expect(config.deviceLabel, 'Handa Tester');
    });
  });
}
