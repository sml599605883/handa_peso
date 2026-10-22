import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/network/gateway_reply.dart';
import 'package:handa_peso/features/webview/app_webview_page.dart';
import 'package:handa_peso/features/webview/h5_bridge.dart';
import 'package:handa_peso/features/webview/payout_account_models.dart';

void main() {
  group('H5BridgeMessage', () {
    test('decodes string data and callback identifiers', () {
      final message = H5BridgeMessage.decode({
        'action': H5Bridge.signedParams,
        'data': '/Aegospotami/keddie',
        'callbackId': 'cb_7',
      });

      expect(message.action, H5Bridge.signedParams);
      expect(message.rawText, '/Aegospotami/keddie');
      expect(message.callbackId, 'cb_7');
      expect(message.expectsReply, isTrue);
    });

    test('accepts JSON strings and map payloads', () {
      final message = H5BridgeMessage.decode(
        '{"name":"${H5Bridge.replaceAccount}","payload":'
        '{"drippier":"p1","qktp":42}}',
      );

      expect(message.action, H5Bridge.replaceAccount);
      expect(message.text(const <String>['drippier']), 'p1');
      expect(message.text(const <String>['qktp']), '42');
    });
  });

  group('H5ActionDispatcher', () {
    test('forwards loan risk fields and finish scene', () async {
      String? seenProductId;
      String? seenOrderNo;
      int? seenStartedAt;
      final dispatcher = H5ActionDispatcher(
        nowSeconds: () => 101,
        reportLoan:
            ({
              required String productId,
              required String orderNo,
              required int startedAtSeconds,
            }) async {
              seenProductId = productId;
              seenOrderNo = orderNo;
              seenStartedAt = startedAtSeconds;
            },
      );

      final result = await dispatcher.dispatch(
        H5BridgeMessage.decode({
          'action': H5Bridge.reportLoan,
          'data': {'drippier': 'p1', 'qktp': 42},
        }),
      );

      expect(result.code, 0);
      expect(seenProductId, 'p1');
      expect(seenOrderNo, '42');
      expect(seenStartedAt, 101);
    });

    test('routes web and app links to separate destinations', () async {
      final web = <String>[];
      final internal = <String>[];
      final dispatcher = H5ActionDispatcher(
        openWebPage: (url) async => web.add(url),
        openInternal: (url) async => internal.add(url),
      );

      await dispatcher.dispatch(
        H5BridgeMessage.decode({
          'action': H5Bridge.openLink,
          'data': 'https://example.test/order',
        }),
      );
      await dispatcher.dispatch(
        H5BridgeMessage.decode({
          'action': H5Bridge.openLink,
          'data': 'ph://handa-peso/ios/Disaccording',
        }),
      );

      expect(web, <String>['https://example.test/order']);
      expect(internal, <String>['ph://handa-peso/ios/Disaccording']);
    });

    test('retry opens the URL returned by the native order API', () async {
      final opened = <String>[];
      var loading = 0;
      var dismissed = 0;
      final dispatcher = H5ActionDispatcher(
        retryLoan: (orderNo) async {
          expect(orderNo, '42');
          return 'https://example.test/retry';
        },
        openWebPage: (url) async => opened.add(url),
        showLoading: () async => loading++,
        dismissLoading: () async => dismissed++,
      );

      final result = await dispatcher.dispatch(
        H5BridgeMessage.decode({
          'action': H5Bridge.retryLoan,
          'data': {'qktp': 42},
        }),
      );

      expect(result.code, 0);
      expect(opened, <String>['https://example.test/retry']);
      expect(loading, 1);
      expect(dismissed, 1);
    });

    test(
      'retry does not navigate when the business result has no URL',
      () async {
        var opened = false;
        final dispatcher = H5ActionDispatcher(
          retryLoan: (orderNo) async => '',
          openWebPage: (url) async => opened = true,
          dismissLoading: () async {},
        );

        final result = await dispatcher.dispatch(
          H5BridgeMessage.decode({
            'action': H5Bridge.retryLoan,
            'data': {'qktp': 42},
          }),
        );

        expect(result.code, isNot(0));
        expect(opened, isFalse);
      },
    );

    test('signed parameters flow through the callback payload', () async {
      final dispatcher = H5ActionDispatcher(
        buildSignedQuery: (path) async {
          expect(path, '/Aegospotami/keddie');
          return <String, dynamic>{'sandman': 'session'};
        },
      );

      final result = await dispatcher.dispatch(
        H5BridgeMessage.decode({
          'action': H5Bridge.signedParams,
          'data': '/Aegospotami/keddie',
          'callbackId': 'cb_9',
        }),
      );

      expect(result.data, <String, dynamic>{'sandman': 'session'});
      expect(
        result.callbackScript(H5Bridge.legacyHandler, 'cb_9'),
        contains('"callbackId":"cb_9"'),
      );
      expect(
        result.callbackScript(H5Bridge.legacyHandler, 'cb_9'),
        contains('"sandman":"session"'),
      );
    });

    test('external app schemes are accepted for email links', () async {
      final opened = <Uri>[];
      final dispatcher = H5ActionDispatcher(
        openExternalApp: (uri) async {
          opened.add(uri);
          return true;
        },
      );

      await dispatcher.dispatch(
        H5BridgeMessage.decode({
          'action': H5Bridge.openExternal,
          'data': 'mailto:support@example.test',
        }),
      );

      expect(opened.single.scheme, 'mailto');
    });

    test('script and local-file schemes are rejected', () async {
      var opened = false;
      final dispatcher = H5ActionDispatcher(
        openExternalApp: (uri) async {
          opened = true;
          return true;
        },
      );

      final result = await dispatcher.dispatch(
        H5BridgeMessage.decode({
          'action': H5Bridge.openExternal,
          'data': 'javascript:alert(1)',
        }),
      );

      expect(result.code, isNot(0));
      expect(opened, isFalse);
    });
  });

  group('confirmationProductIdFromH5Url', () {
    test('reads the product ID from the live confirmation route', () {
      expect(
        confirmationProductIdFromH5Url(
          'http://host/#/OIUCatrionaMonodrame?drippier=1000460',
        ),
        '1000460',
      );
    });

    test('ignores unrelated routes', () {
      expect(
        confirmationProductIdFromH5Url(
          'http://host/#/HatchbacksCoccolithophoridBicentenarnaries'
          '?drippier=1000460',
        ),
        '',
      );
    });
  });

  test('换绑账户目录解析主卡与持卡人信息', () {
    final reply = GatewayReply.parse(<String, dynamic>{
      'unaccepted': 0,
      'unstably': 'ok',
      'indulgences': <String, dynamic>{
        'applicants': <Map<String, dynamic>>[
          <String, dynamic>{
            'burlesquer': 'Bank',
            'geochronologist': <Map<String, dynamic>>[
              <String, dynamic>{
                'retraction': 'card-1',
                'photoduplicated': 'Example Bank',
                'banisters': '1234',
                'week': '',
                'premillenarian': 1,
                'rivieres': <String, dynamic>{
                  'barehanded': 'Ana',
                  'unforced': 'Cruz',
                  'unenlightened': 'Santos',
                },
              },
            ],
          },
        ],
      },
    });

    final catalog = PayoutAccountCatalog.fromReply(reply);
    expect(catalog.isEmpty, isFalse);
    expect(catalog.accounts.single.id, 'card-1');
    expect(catalog.accounts.single.holderName, 'Ana Cruz Santos');
    expect(catalog.accounts.single.isPrimary, isTrue);
  });
}
