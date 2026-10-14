import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/app/startup/startup_network_gate.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/session/local_session.dart';

GatewaySettings _buildConfig({
  String apiOrigin = 'http://primary.test',
  String spareSourceUrl = '',
}) {
  return GatewaySettings(
    apiOrigin: apiOrigin,
    spareSourceUrl: spareSourceUrl,
    signSecret: 'unit-test-secret',
    localSession: LocalSession.memory(),
    clock: () => 1700000000000,
    noiseDigits: (length) => '1' * length,
  );
}

/// Scripted Dio adapter: routes every request through [handler] so a test can
/// model "primary host down, remote config up".
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<String> urls = <String>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    urls.add(options.uri.toString());
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

GatewayClient _client(GatewaySettings config, _StubAdapter adapter) {
  return GatewayClient(config, dio: Dio()..httpClientAdapter = adapter);
}

void main() {
  group('probeStartupTransport', () {
    test('uses the compiled-in host and reports reachable', () async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString('ok', 200),
      );
      final config = _buildConfig();
      var reached = 0;

      final ok = await probeStartupTransport(
        _client(config, adapter),
        onReachable: () async => reached++,
      );

      expect(ok, isTrue);
      expect(reached, 1);
      expect(config.apiOrigin, 'http://primary.test');
      expect(adapter.urls, ['http://primary.test']);
    });

    test('does not fetch remote config or run the callback when it fails and '
        'no link is configured', () async {
      final adapter = _StubAdapter(
        (options) async =>
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            ),
      );
      final config = _buildConfig();
      var reached = 0;

      final ok = await probeStartupTransport(
        _client(config, adapter),
        onReachable: () async => reached++,
      );

      expect(ok, isFalse);
      expect(reached, 0);
      expect(adapter.urls, ['http://primary.test']);
    });

    test('switches to the base64 remote config and re-probes it', () async {
      final adapter = _StubAdapter((options) async {
        switch (options.uri.toString()) {
          case 'http://primary.test':
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            );
          case 'http://config.test/api.json':
            return ResponseBody.fromString(
              base64Encode(
                utf8.encode(
                  '{"api":"http://backup.test","web":"http://h5.test"}',
                ),
              ),
              200,
            );
          case 'http://backup.test':
            return ResponseBody.fromString('ok', 200);
          default:
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            );
        }
      });
      final config = _buildConfig(
        spareSourceUrl: 'http://config.test/api.json',
      );
      var reached = 0;

      final ok = await probeStartupTransport(
        _client(config, adapter),
        onReachable: () async => reached++,
      );

      expect(ok, isTrue);
      expect(reached, 1);
      expect(config.apiOrigin, 'http://backup.test');
      expect(config.webOrigin, 'http://h5.test');
      expect(adapter.urls, [
        'http://primary.test',
        'http://config.test/api.json',
        'http://backup.test',
      ]);
    });

    test('stays unreachable when the backup host also fails', () async {
      final adapter = _StubAdapter((options) async {
        if (options.uri.toString() == 'http://config.test/api.json') {
          return ResponseBody.fromString(
            '{"api":"http://backup.test"}',
            200,
          );
        }
        throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        );
      });
      final config = _buildConfig(
        spareSourceUrl: 'http://config.test/api.json',
      );
      var reached = 0;

      final ok = await probeStartupTransport(
        _client(config, adapter),
        onReachable: () async => reached++,
      );

      expect(ok, isFalse);
      expect(reached, 0);
      expect(config.apiOrigin, 'http://backup.test');
    });
  });

  group('GatewayClient.applyRemoteBaseUrls', () {
    test('is a no-op when no remote link is configured', () async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString('{}', 200),
      );
      final config = _buildConfig();

      final applied = await _client(config, adapter).refreshOrigins();

      expect(applied, isFalse);
      expect(adapter.urls, isEmpty);
      expect(config.apiOrigin, 'http://primary.test');
    });

    test('applies api and web from a plain JSON body', () async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          '{"api":"https://remote-api.test","web":"https://h5.test"}',
          200,
        ),
      );
      final config = _buildConfig(
        spareSourceUrl: 'https://config.test/api.json',
      );

      final applied = await _client(config, adapter).refreshOrigins();

      expect(applied, isTrue);
      expect(config.apiOrigin, 'https://remote-api.test');
      expect(config.webOrigin, 'https://h5.test');
    });

    test('ignores a body without an api field', () async {
      final adapter = _StubAdapter(
        (options) async =>
            ResponseBody.fromString('{"web":"https://h5.test"}', 200),
      );
      final config = _buildConfig(
        spareSourceUrl: 'https://config.test/api.json',
      );

      final applied = await _client(config, adapter).refreshOrigins();

      expect(applied, isFalse);
      expect(config.apiOrigin, 'http://primary.test');
      expect(config.webOrigin, 'http://8.220.176.2');
    });
  });

  group('endpoint switch reporting', () {
    _StubAdapter switchingAdapter() {
      return _StubAdapter((options) async {
        switch (options.uri.toString()) {
          case 'http://config.test/api.json':
            return ResponseBody.fromString('{"api":"http://backup.test"}', 200);
          case 'http://backup.test':
            return ResponseBody.fromString('ok', 200);
          default:
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            );
        }
      });
    }

    test('reports the accumulated log when the spare host takes over', () async {
      final config = _buildConfig(
        spareSourceUrl: 'http://config.test/api.json',
      );
      final payloads = <String>[];

      final ok = await probeStartupTransport(
        _client(config, switchingAdapter()),
        reportSwitch: (payload) async => payloads.add(payload),
      );
      await pumpEventQueue();

      expect(ok, isTrue);
      expect(payloads, hasLength(1));

      final entries = (jsonDecode(payloads.single) as List).cast<String>();
      expect(entries, hasLength(4));
      expect(entries.first, contains('primary.test'));
      expect(
        entries.any((line) => line.contains('primary.test -> backup.test')),
        isTrue,
      );
    });

    test('stays quiet when the built-in host answers', () async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString('ok', 200),
      );
      final payloads = <String>[];

      final ok = await probeStartupTransport(
        _client(_buildConfig(), adapter),
        reportSwitch: (payload) async => payloads.add(payload),
      );
      await pumpEventQueue();

      expect(ok, isTrue);
      expect(payloads, isEmpty);
    });

    test('stays quiet when the spare host also fails', () async {
      final config = _buildConfig(
        spareSourceUrl: 'http://config.test/api.json',
      );
      final payloads = <String>[];

      final ok = await probeStartupTransport(
        _client(
          config,
          _StubAdapter((options) async {
            if (options.uri.toString() == 'http://config.test/api.json') {
              return ResponseBody.fromString('{"api":"http://backup.test"}', 200);
            }
            throw DioException.connectionError(
              requestOptions: options,
              reason: 'offline',
            );
          }),
        ),
        reportSwitch: (payload) async => payloads.add(payload),
      );
      await pumpEventQueue();

      expect(ok, isFalse);
      expect(payloads, isEmpty);
    });

    test('ignores a reporter failure', () async {
      final config = _buildConfig(
        spareSourceUrl: 'http://config.test/api.json',
      );

      final ok = await probeStartupTransport(
        _client(config, switchingAdapter()),
        reportSwitch: (payload) async => throw StateError('reporter down'),
      );
      await pumpEventQueue();

      expect(ok, isTrue);
    });
  });
}
