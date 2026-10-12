import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/client/device_bridge.dart';
import 'package:handa_peso/core/device/device_info_sync.dart';
import 'package:handa_peso/core/network/api_client.dart';
import 'package:handa_peso/core/network/api_config.dart';
import 'package:handa_peso/core/network/api_exception.dart';
import 'package:handa_peso/core/network/api_protocol.dart';
import 'package:handa_peso/core/network/api_response.dart';
import 'package:handa_peso/core/network/api_signature.dart';
import 'package:handa_peso/core/session/session_store.dart';

ApiConfig buildConfig({String secret = 'unit-test-secret'}) {
  return ApiConfig(
    signatureSecret: secret,
    appVersion: '1.0.0',
    deviceName: 'iPhone15,2',
    deviceId: 'idfv-123',
    osVersion: '17.0',
    sessionStore: SessionStore.memory(),
    timestampProvider: () => 1700000000000,
    randomDigitsProvider: (length) => '1' * length,
  );
}

void main() {
  group('ApiSignature', () {
    test('builds the signed public parameter set for a path', () async {
      final config = buildConfig();
      final query = await ApiSignature(config)
          .buildSignedQuery(path: '/dropcloth/fishtailed');

      expect(query['procuration'], '1.0.0');
      expect(query['especially'], 'iPhone15,2');
      expect(query['corkscrewed'], 'idfv-123');
      expect(query['parcener'], 'idfv-123');
      expect(query['truculency'], '17.0');
      expect(query['muttonfishes'], 'appstore-ph-handa-peso-ios');
      expect(query['sandman'], '');
      expect(query['absorbing'], '1700000000000');
      expect(query['wrencher'], '111111');

      final expected = ApiSignature.sign({
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
      final signature = ApiSignature.sign({'b': '2', 'a': '1'}, 'secret');
      expect(signature, ApiSignature.sign({'a': '1', 'b': '2'}, 'secret'));
      expect(
        signature,
        isNot(ApiSignature.sign({'a': '2', 'b': '1'}, 'secret')),
      );
    });

    test('strips host and query before signing', () {
      expect(
        ApiSignature.clearPath('http://8.220.135.86/dropcloth/checkreins?x=1'),
        '/dropcloth/checkreins',
      );
      expect(
        ApiSignature.clearPath('/dropcloth/checkreins?x=1'),
        '/dropcloth/checkreins',
      );
    });

    test('fails fast when the signing secret is missing', () async {
      final config = buildConfig(secret: '');
      await expectLater(
        ApiSignature(config).buildSignedQuery(path: '/dropcloth/fishtailed'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'configuration'),
        ),
      );
    });
  });

  group('ApiResponse', () {
    test('unwraps a success envelope', () {
      final response = ApiResponse.fromRaw({
        ApiProtocol.code: 0,
        ApiProtocol.message: 'success',
        ApiProtocol.data: {'sandman': 'session-1'},
      });

      expect(response.isSuccess, isTrue);
      expect(response.message, 'success');
      expect(response.data['sandman'], 'session-1');
    });

    test('treats 20000 as success for the liveness bind-card flow', () {
      final response = ApiResponse.fromRaw({
        ApiProtocol.code: 20000,
        ApiProtocol.message: '',
        ApiProtocol.data: <String, dynamic>{},
      });
      expect(response.isSuccess, isTrue);
    });

    test('nests a bare list payload under list', () {
      final response = ApiResponse.fromRaw({
        ApiProtocol.code: '0',
        ApiProtocol.message: 'success',
        ApiProtocol.data: [1, 2, 3],
      });
      expect(response.data['list'], [1, 2, 3]);
    });

    test('flags an expired session', () {
      final response = ApiResponse.fromRaw({
        ApiProtocol.code: -2,
        ApiProtocol.message: 'not logged in',
      });
      expect(response.isAuthExpired, isTrue);
    });

    test('throws a coded error for business failures', () {
      final response = ApiResponse.fromRaw({
        ApiProtocol.code: 505,
        ApiProtocol.message: 'rejected',
      });
      expect(
        () => response.ensureSuccess(),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 505)
              .having((e) => e.message, 'message', 'rejected'),
        ),
      );
    });

    test('rejects a non-map payload', () {
      final response = ApiResponse.fromRaw('<html>gateway error</html>');
      expect(response.code, ApiResponse.invalidFormatCode);
      expect(response.isSuccess, isFalse);
    });
  });

  group('DeviceInfoSync', () {
    const channel = MethodChannel(DeviceBridge.channelName);

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

      final config = ApiConfig(
        sessionStore: SessionStore.memory(),
        appVersion: '',
        timestampProvider: () => 1700000000000,
        randomDigitsProvider: (length) => '1' * length,
      );
      final sync = DeviceInfoSync(
        apiClient: ApiClient(config),
        bridge: DeviceBridge(supported: true, channel: channel),
        store: SessionStore.memory(),
      );

      final model = await sync.applyDeviceIdentity(config);

      expect(model, 'iPhone15,2');
      expect(config.deviceId, 'idfv-stable');
      expect(config.gpsAdId, 'idfv-stable');
      expect(config.osVersion, '17.4');
      expect(config.appVersion, '2.3.1');
      expect(config.deviceName, 'iPhone15,2');

      final query = await ApiSignature(config)
          .buildSignedQuery(path: '/dropcloth/pyranoside');
      expect(query['corkscrewed'], 'idfv-stable');
      expect(query['parcener'], 'idfv-stable');
      expect(query['truculency'], '17.4');
      expect(query['procuration'], '2.3.1');
      expect(query['especially'], 'iPhone15,2');
    });

    test('falls back to the cached device name without the bridge', () async {
      final store = SessionStore.memory();
      await store.saveDeviceName('Handa Tester');
      final config = ApiConfig(sessionStore: store, appVersion: '1.0.0');
      final sync = DeviceInfoSync(
        apiClient: ApiClient(config),
        bridge: DeviceBridge(supported: false),
        store: store,
      );

      final model = await sync.applyDeviceIdentity(config);

      expect(model, isNull);
      expect(config.deviceName, 'Handa Tester');
    });
  });
}
