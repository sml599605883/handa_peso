import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/report/report_bridge.dart';
import 'package:handa_peso/core/report/report_models.dart';
import 'package:handa_peso/core/report/report_payload.dart';
import 'package:handa_peso/core/report/report_scene.dart';
import 'package:handa_peso/core/report/report_service.dart';
import 'package:handa_peso/core/report/report_store.dart';
import 'package:handa_peso/core/session/local_session.dart';

/// 一次被捕获的请求：路径、查询参数与表单字段。
class _Call {
  _Call(this.path, this.query, this.body);

  final String path;
  final Map<String, String> query;
  final Map<String, String> body;
}

/// 把 Dio 传给适配器的请求体归一化成字段表（表单编码可能是 Map，也可能是串）。
Map<String, String> _fields(Object? data) {
  if (data is Map) {
    return <String, String>{
      for (final entry in data.entries) '${entry.key}': '${entry.value}',
    };
  }
  if (data is String && data.isNotEmpty) return Uri.splitQueryString(data);
  return <String, String>{};
}

/// 脚本化 Dio 适配器：记录请求并统一回成功信封。
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter({this.payload = const <String, Object?>{}});

  /// 信封里 `indulgences` 的内容；用来验证对响应字段的处理。
  final Map<String, Object?> payload;

  final calls = <_Call>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls.add(
      _Call(
        options.uri.path,
        options.uri.queryParameters,
        _fields(options.data),
      ),
    );
    return ResponseBody.fromString(
      jsonEncode(<String, Object?>{
        'unaccepted': 0,
        'unstably': 'ok',
        'indulgences': payload,
      }),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _Harness {
  _Harness({
    bool withSession = true,
    Map<String, Object?> payload = const <String, Object?>{},
  }) : session = LocalSession.memory(),
       adapter = _RecordingAdapter(payload: payload) {
    settings = GatewaySettings(
      // 域名不带路径，断言里就能直接用文档登记的路由做 key。
      apiOrigin: 'http://127.0.0.1:1',
      signSecret: 'unit-test-secret',
      localSession: session,
      clock: () => 1700000000000,
      noiseDigits: (length) => '1' * length,
    );
    client = GatewayClient(settings, dio: Dio()..httpClientAdapter = adapter);
    if (withSession) session.writeSessionId('session-1');
  }

  final LocalSession session;
  final _RecordingAdapter adapter;
  late final GatewaySettings settings;
  late final GatewayClient client;

  List<_Call> get calls => adapter.calls;

  _Call callTo(String path) => calls.firstWhere(
    (call) => call.path == path,
    orElse: () => _Call('', {}, {}),
  );

  bool hasCall(String path) => calls.any((call) => call.path == path);
}

/// 原生通道的脚本；同时记录调用顺序，供时序断言使用。
class _NativeScript {
  _NativeScript();

  final order = <String>[];

  /// 每次原生方法被调用前触发，用来在测试里模拟耗时（例如推进注入的时钟）。
  void Function(String method)? onMethod;
  Map<String, Object?> snapshot = const <String, Object?>{};
  Map<String, Object?> location = const <String, Object?>{};
  List<Object?> contacts = const <Object?>[];
  String pushToken = '';
  String trackingStatus = 'not_determined';

  /// 模拟系统定位授权弹窗：非空时 `requestLocationPermission` 会挂起，
  /// 直到测试把它 complete（等价于用户点了允许或不允许）。
  Completer<void>? locationPermissionGate;
  String locationPermissionStatus = 'authorized_when_in_use';

  static const _channel = MethodChannel('handa_peso/report_bridge.test');
  static const _events = EventChannel('handa_peso/report_events.test');

  void install() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
          order.add(call.method);
          onMethod?.call(call.method);
          switch (call.method) {
            case 'getDeviceSnapshot':
              return snapshot;
            case 'getLocation':
              return location;
            case 'getContacts':
              return contacts;
            case 'getPushToken':
              return pushToken;
            case 'getTrackingStatus':
              return trackingStatus;
            case 'requestLocationPermission':
              await locationPermissionGate?.future;
              return locationPermissionStatus;
            default:
              return null;
          }
        });
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handa_peso/report_events.test'),
          (call) async {
            order.add(call.method);
            return null;
          },
        );
  }

  void remove() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('handa_peso/report_events.test'),
          null,
        );
  }

  ReportNativeBridge bridge() =>
      ReportNativeBridge(available: true, methods: _channel, events: _events);
}

const _snapshot = <String, Object?>{
  'idfv': 'IDFV-1',
  'board': 'D79AP',
  'advertisingId': 'IDFA-1',
  'systemVersion': '17.4',
  'packageName': 'com.handa.peso',
  'batteryLevel': 70,
  'isCharging': 1,
  'networkType': 'WIFI',
  'screenWidth': 390,
  'screenHeight': 844,
  'availableStorage': '1000',
  'totalStorage': '2000',
  'totalMemory': '3000',
  'availableMemory': '4000',
};

const _location = <String, Object?>{
  'province': 'Metro Manila',
  'fullAddress': 'Ayala Ave, Makati, Metro Manila, Philippines',
  'countryCode': 'PH',
  'country': 'Philippines',
  'street': 'Ayala Ave',
  'latitude': '14.554729',
  'longitude': '121.024445',
  'city': 'Makati',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportPayload', () {
    test('maps a location snapshot onto the documented field names', () {
      final body = ReportPayload.locationBody(
        ReportLocation.fromMap(_location),
      );

      expect(body['sardonic'], 'Metro Manila');
      expect(body['psychrometry'], 'PH');
      expect(body['eyehole'], 'Philippines');
      expect(body['widemouthed'], 'Ayala Ave');
      expect(body['carnets'], '14.554729');
      expect(body['polyembryonies'], '121.024445');
      expect(body['marbleizes'], 'Makati');
    });

    test('builds the nested device payload with the documented keys', () {
      final payload = jsonDecode(
        ReportPayload.deviceJson(
          snapshot: DeviceSnapshot.fromMap(_snapshot),
          location: ReportLocation.fromMap(_location),
          lastLoginAtMillis: 1700000000000,
          nowMillis: 1700000001000,
        ),
      ) as Map<String, dynamic>;

      expect(payload['litigiousness'], '17.4');
      expect(payload['scribbling'], 1700000000000);
      expect(payload['tamarinds'], 'com.handa.peso');
      expect((payload['squares'] as Map)['purselike'], 70);
      expect((payload['squares'] as Map)['merganser'], 1);

      final device = payload['ruddling'] as Map;
      expect(device['tunesmith'], 'IDFV-1');
      expect(device['colickiest'], 'IDFA-1');
      expect(device['marathoners'], 1700000001000);
      expect(device['counterblockade'], 'WIFI');
      // 传感器清单没有采集能力时按空数组上报，不用占位数据冒充。
      expect(device['overhard'], isEmpty);

      final hardware = payload['interterm'] as Map;
      expect(hardware['passionflowers'], 390);
      expect(hardware['scrimshanders'], 844);
      // capitulating 是主板标识，不是风控设备号。
      expect(hardware['capitulating'], 'D79AP');

      // gps_info 有一组自己的键，不能沿用定位接口的 carnets / polyembryonies /
      // widemouthed，否则服务端在设备详情里读不到经纬度与完整地址。
      final gps = payload['shrouded'] as Map;
      expect(gps['parasiticidal'], '14.554729');
      expect(gps['apteria'], '121.024445');
      expect(
        gps['blackthorns'],
        'Ayala Ave, Makati, Metro Manila, Philippines',
      );
      expect(gps.containsKey('carnets'), isFalse);
      expect((gps['gadgeteers'] as Map)['psychrometry'], 'PH');

      final storage = payload['biogenetically'] as Map;
      expect(storage['guardhouses'], '1000');
      expect(storage['ineffabilities'], '4000');
    });

    test('encrypts contacts and skips entries without a name or number', () {
      final json = ReportPayload.contactsJson(const <ContactRecord>[
        ContactRecord(
          name: 'Ana',
          phone: '+639170000001',
          email: 'ana@example.com',
        ),
        ContactRecord(name: '', phone: ''),
      ], noiseDigits: (length) => '9' * length);

      final rows = jsonDecode(json) as List<dynamic>;
      expect(rows, hasLength(1));
      final row = rows.single as Map<String, dynamic>;
      expect(row['definitively'], 'Ana');
      expect(row['fishtailed'], '+639170000001');
      expect(row['eyestrain'], 'ana@example.com');
      expect(row['prebendaries'], '999999');
    });
  });

  group('ReportService lifecycle', () {
    late _NativeScript native;
    late _Harness harness;
    late ReportService service;
    late ReportStore store;

    setUp(() {
      native = _NativeScript()..install();
      harness = _Harness();
      store = ReportStore.memory();
      service = ReportService(
        gatewayClient: harness.client,
        store: store,
        bridge: native.bridge(),
        clock: () => 1700000000000,
        pause: (_) async {},
      );
    });

    tearDown(() => native.remove());

    test(
      'asks for notification authorization before registering APNs',
      () async {
        native.pushToken = 'abc123';

        await service.start();

        expect(
          native.order.indexOf('requestNotificationPermission'),
          lessThan(native.order.indexOf('registerForRemoteNotifications')),
        );
        expect(
          harness.callTo('/dropcloth/calipash').body['bettered'],
          'abc123',
        );
      },
    );

    test('uploads whatever push token the device has, empty or not', () async {
      await service.reportPushToken();

      // 本机还没拿到 token 就直接报空串，不做客户端拦截。
      expect(harness.callTo('/dropcloth/calipash').body['bettered'], '');

      native.pushToken = 'abc123';
      await service.reportPushToken();
      await service.reportPushToken();

      final uploads = harness.calls
          .where((call) => call.path == '/dropcloth/calipash')
          .toList();
      // 不去重：每次触发都上报，覆盖交给服务端。
      expect(uploads.length, 3);
      expect(uploads.last.body['bettered'], 'abc123');
    });

    test('skips location and device upload without a session', () async {
      final anonymous = _Harness(withSession: false);
      final anonymousService = ReportService(
        gatewayClient: anonymous.client,
        store: ReportStore.memory(),
        bridge: native.bridge(),
        clock: () => 1700000000000,
        pause: (_) async {},
      );

      await anonymousService.reportLocationAndDevice();

      expect(anonymous.hasCall('/dropcloth/farle'), isFalse);
      expect(anonymous.hasCall('/dropcloth/unglove'), isFalse);
    });

    test(
      'uploads the encrypted device profile only when a session exists',
      () async {
        native.snapshot = _snapshot;
        native.location = _location;

        await service.reportLocationAndDevice();

        expect(harness.callTo('/dropcloth/farle').body['carnets'], '14.554729');

        final sealedBody = harness.callTo('/dropcloth/unglove').body;
        final plaintext = harness.client.cipher.decipher(
          sealedBody['indulgences']!,
        );
        final payload = jsonDecode(plaintext) as Map<String, dynamic>;
        expect((payload['ruddling'] as Map)['tunesmith'], 'IDFV-1');
      },
    );

    test('falls back to the location cached in this process', () async {
      native.location = _location;
      native.snapshot = _snapshot;
      await service.reportLocationAndDevice();

      // 第二次原生给不出有效坐标：退回本次进程里上一次拿到的定位。
      native.location = const <String, Object?>{};
      await service.reportLocationAndDevice();

      final uploads = harness.calls
          .where((call) => call.path == '/dropcloth/farle')
          .toList();
      expect(uploads.length, 2);
      expect(uploads.last.body['polyembryonies'], '121.024445');
    });

    test(
      'reports the registration scene with the caller-supplied start time',
      () async {
        native.snapshot = _snapshot;

        await service.reportScene(
          scene: ReportScene.registration,
          startedAtSeconds: 1700000000,
        );

        final body = harness.callTo('/dropcloth/disgruntle').body;
        expect(body['proves'], '1');
        expect(body['sparkler'], '1700000000');
        // 结束时间取上报时刻，与开始时间同为秒级时间戳。
        expect(
          int.parse(body['spectacled']!),
          greaterThanOrEqualTo(1700000000),
        );
        expect(body['pastorales'], '111111');
      },
    );

    test('takes the scene end time before the async device work', () async {
      var nowMillis = 1700000000000;
      final timed = ReportService(
        gatewayClient: harness.client,
        store: ReportStore.memory(),
        bridge: native.bridge(),
        clock: () => nowMillis,
        pause: (_) async {},
      );
      native.snapshot = _snapshot;
      native.location = _location;
      // 取定位的过程“耗时” 5 秒：结束时间不能在它之后才取。
      native.onMethod = (method) {
        if (method == 'getLocation') nowMillis += 5000;
      };

      await timed.reportScene(
        scene: ReportScene.certificationChoice,
        startedAtSeconds: 1700000000,
      );

      final body = harness.callTo('/dropcloth/disgruntle').body;
      expect(body['proves'], '2');
      expect(body['sparkler'], '1700000000');
      expect(body['spectacled'], '1700000000');
    });

    test('defers google_market until tracking is decided, then reports on every trigger', () async {
      native.snapshot = _snapshot;

      await service.reportInstallSource();
      expect(harness.hasCall('/dropcloth/phalarope'), isFalse);

      native.trackingStatus = 'authorized';
      await service.reportInstallSource();
      expect(
        harness.callTo('/dropcloth/phalarope').body['tunesmith'],
        'IDFV-1',
      );
      expect(
        harness.callTo('/dropcloth/phalarope').body['colickiest'],
        'IDFA-1',
      );

      // 没有去重签名：每次触发都重新上报，归因 token 才有机会刷新。
      await service.reportInstallSource();
      expect(
        harness.calls
            .where((call) => call.path == '/dropcloth/phalarope')
            .length,
        2,
      );
    });

    test(
      'hands the google_market attribution token to the injected handler',
      () async {
        final withToken = _Harness(
          payload: const <String, Object?>{'guardsman': 'adjust-token-1'},
        );
        native.trackingStatus = 'authorized';
        native.snapshot = _snapshot;
        String? received;
        final installAware = ReportService(
          gatewayClient: withToken.client,
          store: ReportStore.memory(),
          bridge: native.bridge(),
          clock: () => 1700000000000,
          pause: (_) async {},
          onInstallToken: (token) async => received = token,
        );

        await installAware.reportInstallSource();

        expect(received, 'adjust-token-1');
      },
    );

    test(
      'waits for the location prompt before the login-time uploads',
      () async {
        native.snapshot = _snapshot;
        native.location = _location;
        final gate = Completer<void>();
        native.locationPermissionGate = gate;

        await service.loginSucceeded(registeredAtSeconds: 1699999990);
        await pumpEventQueue();

        // 授权弹窗还开着：注册埋点、定位、设备详情都先不发。
        expect(native.order, contains('requestLocationPermission'));
        expect(harness.hasCall('/dropcloth/disgruntle'), isFalse);
        expect(harness.hasCall('/dropcloth/farle'), isFalse);
        expect(harness.hasCall('/dropcloth/unglove'), isFalse);

        gate.complete();
        await pumpEventQueue();

        final scene = harness.callTo('/dropcloth/disgruntle').body;
        expect(scene['proves'], '1');
        expect(scene['sparkler'], '1699999990');
        // 结束时间是「登录成功」那一刻，不含用户看弹窗的时间。
        expect(scene['spectacled'], '1700000000');
        expect(harness.callTo('/dropcloth/farle').body['carnets'], '14.554729');
        expect(harness.hasCall('/dropcloth/unglove'), isTrue);
      },
    );

    test(
      'sends the login-time uploads right away when the prompt is settled',
      () async {
        native.snapshot = _snapshot;
        // 弹窗已经弹过：原生不再弹，直接给出状态，上报不再等。
        native.locationPermissionStatus = 'denied';
        native.location = _location;

        await service.loginSucceeded(registeredAtSeconds: 1699999990);
        await pumpEventQueue();

        expect(harness.callTo('/dropcloth/disgruntle').body['proves'], '1');
        expect(harness.hasCall('/dropcloth/unglove'), isTrue);
      },
    );

    test('skips the contacts upload when there is nothing to send', () async {
      await service.reportContacts(const <ContactRecord>[]);

      expect(harness.hasCall('/dropcloth/bioregional'), isFalse);
    });

    test('uploads encrypted contacts collected from the device', () async {
      native.contacts = <Object?>[
        <String, Object?>{
          'name': 'Ana',
          'phone': '+639170000001',
          'upTimeMillis': 0,
          'createTimeMillis': 0,
        },
      ];

      await service.reportDeviceContacts();

      final body = harness.callTo('/dropcloth/bioregional').body;
      expect(body['trollopy'], '3');
      final rows = jsonDecode(
        harness.client.cipher.decipher(body['indulgences']!),
      ) as List<dynamic>;
      expect((rows.single as Map)['definitively'], 'Ana');
    });
  });
}
