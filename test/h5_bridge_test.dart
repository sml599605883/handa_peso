import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/network/gateway_reply.dart';
import 'package:handa_peso/core/order/order_redirect.dart';
import 'package:handa_peso/features/webview/app_webview_page.dart';
import 'package:handa_peso/features/webview/h5_bridge.dart';
import 'package:handa_peso/features/webview/payout_account_models.dart';

void main() {
  test('WebView 加载完成后后续低进度不会重新显示加载条', () {
    expect(
      keepWebViewLoadingAfterProgress(loading: false, progress: 30),
      isFalse,
    );
    expect(
      keepWebViewLoadingAfterProgress(loading: true, progress: 30),
      isTrue,
    );
    expect(
      keepWebViewLoadingAfterProgress(loading: true, progress: 100),
      isFalse,
    );
  });

  test('H5 桥接名称与交互 ID 使用 Handa 当前契约', () {
    expect(H5Bridge.handler, 'ph_handa_peso_ios');
    expect(H5Bridge.handlers, <String>['ph_handa_peso_ios']);
    expect(H5Bridge.reportLoan, 'handa_peso_9aVEhYqLCbo4HEw');
    expect(H5Bridge.openExternal, 'handa_peso_nJdWCogSiNgDih0');
    expect(H5Bridge.openLink, 'handa_peso_IfCsnOIi3iNbkbN');
    expect(H5Bridge.closePage, 'handa_peso_dQmLjJivOqwg07W');
    expect(H5Bridge.goHome, 'handa_peso_iBxwnEBwgWHNFiA');
    expect(H5Bridge.appReview, 'handa_peso_wxOCeAtVisJ1aHb');
    expect(H5Bridge.retryLoan, 'handa_peso_N49CG5gSlbEVpbr');
    expect(H5Bridge.replaceAccount, 'handa_peso_rCe7xygqL7gajXP');
    expect(H5Bridge.signedParams, 'handa_peso_WtSM7etm0nBvu2E');
  });

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
        '{"knife":"p1","redecorates":42}}',
      );

      expect(message.action, H5Bridge.replaceAccount);
      expect(message.text(const <String>['knife']), 'p1');
      expect(message.text(const <String>['redecorates']), '42');
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
          'data': {'knife': 'p1', 'redecorates': 42},
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
          'data': {'redecorates': 42},
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
            'data': {'redecorates': 42},
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
        result.callbackScript(H5Bridge.handler, 'cb_9'),
        contains('"callbackId":"cb_9"'),
      );
      expect(
        result.callbackScript(H5Bridge.handler, 'cb_9'),
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
    test('reads the product ID from the MyTools confirmation route', () {
      expect(
        confirmationProductIdFromH5Url(
          'http://host/#/BanefullyHorse?drippier=1000460',
        ),
        '1000460',
      );
    });

    test('reads the product ID from the current server confirmation URL', () {
      expect(
        confirmationProductIdFromH5Url(
          'http://8.220.176.2/#/BanefullyHorse?prefabricating=1&knife=1'
          '&changeAcount=1&redecorates=1772026101617112334539943',
        ),
        '1',
      );
    });

    test('still recognizes confirmation routes from older packages', () {
      for (final segment in const <String>[
        'OIUCatrionaMonodrame',
        'AmalgamatorsMarqueterie',
      ]) {
        expect(
          confirmationProductIdFromH5Url(
            'http://host/#/$segment?drippier=1000460',
          ),
          '1000460',
        );
      }
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

  test('换绑账户目录按 Handa 文档字段解析主卡与持卡人信息', () {
    final reply = GatewayReply.parse(<String, dynamic>{
      'unaccepted': 0,
      'unstably': 'ok',
      'indulgences': <String, dynamic>{
        'latchstrings': <Map<String, dynamic>>[
          <String, dynamic>{
            'scarriest': 2,
            'axmen': 'Bank',
            'ranulas': <Map<String, dynamic>>[
              <String, dynamic>{
                'eyeglasses': 555,
                'crankles': 'BDO',
                'calipash': '1234',
                'headway': '',
                'uppropped': 1,
                'assureds': 1,
                'unworked': <String, dynamic>{
                  'advisements': 'Ana',
                  'chyme': 'Cruz',
                  'recusant': 'Santos',
                },
              },
            ],
          },
        ],
      },
    });

    final catalog = PayoutAccountCatalog.fromReply(reply);
    expect(catalog.isEmpty, isFalse);
    expect(catalog.groups.single.title, 'Bank');
    expect(catalog.groups.single.type, '2');
    expect(catalog.accounts.single.id, '555');
    expect(catalog.accounts.single.bankName, 'BDO');
    expect(catalog.accounts.single.accountNumber, '1234');
    expect(catalog.accounts.single.holderName, 'Ana Cruz Santos');
    expect(catalog.accounts.single.isPrimary, isTrue);
    expect(catalog.accounts.single.available, isTrue);
    expect(catalog.accounts.single.holderFirstName, 'Ana');
    expect(catalog.accounts.single.holderMiddleName, 'Cruz');
    expect(catalog.accounts.single.holderLastName, 'Santos');
  });

  test('维护中的账户没有文案时用通用兜底', () {
    final reply = GatewayReply.parse(<String, dynamic>{
      'unaccepted': 0,
      'unstably': 'ok',
      'indulgences': <String, dynamic>{
        'latchstrings': <Map<String, dynamic>>[
          <String, dynamic>{
            'scarriest': 1,
            'axmen': 'E-wallet',
            'ranulas': <Map<String, dynamic>>[
              <String, dynamic>{
                'eyeglasses': 556,
                'crankles': 'GCash',
                'calipash': '09171234567',
                'uppropped': 0,
                'assureds': 0,
                'unworked': <String, dynamic>{},
              },
            ],
          },
        ],
      },
    });

    final account = PayoutAccountCatalog.fromReply(reply).accounts.single;
    expect(account.available, isFalse);
    expect(account.maintenanceNote, PayoutAccount.defaultMaintenanceNote);
    expect(account.isPrimary, isFalse);
  });

  test('维护中的账户带入参文案（jellies）时直接展示服务端文案', () {
    final reply = GatewayReply.parse(<String, dynamic>{
      'unaccepted': 0,
      'unstably': 'ok',
      'indulgences': <String, dynamic>{
        'latchstrings': <Map<String, dynamic>>[
          <String, dynamic>{
            'scarriest': 1,
            'axmen': 'E-wallet',
            'ranulas': <Map<String, dynamic>>[
              <String, dynamic>{
                'eyeglasses': 556,
                'crankles': 'GCash',
                'calipash': '09171234567',
                'uppropped': 0,
                'assureds': 0,
                'unworked': <String, dynamic>{},
                'jellies': 'GCash is temporarily unavailable. '
                    'Please choose another option.',
              },
            ],
          },
        ],
      },
    });

    final account = PayoutAccountCatalog.fromReply(reply).accounts.single;
    expect(account.available, isFalse);
    expect(
      account.maintenanceNote,
      'GCash is temporarily unavailable. Please choose another option.',
    );
  });

  test('换绑账户按实抓 /dropcloth/dullard 响应解析', () {
    // 2026-10-28 Proxyman 实抓（http://8.220.176.2/deliv/dropcloth/dullard）。
    // 注意：账户 id 是数字，可用性看 uppropped，维护提示看 jellies（text）。
    final reply = GatewayReply.parse(<String, dynamic>{
      'unaccepted': 0,
      'unstably': 'success',
      'indulgences': <String, dynamic>{
        'GA1Eb': 'QP2HCB',
        '3S1dUkgEf': null,
        'latchstrings': <Map<String, dynamic>>[
          <String, dynamic>{
            'scarriest': 2,
            'incapacitate':
                'https://pera-agad-ios-files-prod.oss-ap-southeast-6.'
                'aliyuncs.com/other/icon_card_bank.png',
            'axmen': 'Bank',
            'ranulas': <Map<String, dynamic>>[
              <String, dynamic>{
                'eyeglasses': 3,
                'calipash': '1102',
                'assureds': 1,
                'unworked': <String, dynamic>{
                  'advisements': 'ROLANDO',
                  'chyme': 'MAESTRE',
                  'recusant': 'SIMBAJON JR',
                },
                'headway': '',
                'crankles': 'Bank Of Commerce',
                'trollopy': 'BOC',
                'uppropped': 1,
                'jellies': '',
              },
            ],
          },
        ],
      },
    });

    final catalog = PayoutAccountCatalog.fromReply(reply);
    final account = catalog.accounts.single;
    expect(catalog.groups.single.title, 'Bank');
    expect(catalog.groups.single.type, '2');
    expect(account.id, '3');
    expect(account.bankName, 'Bank Of Commerce');
    expect(account.accountNumber, '1102');
    expect(account.holderName, 'ROLANDO MAESTRE SIMBAJON JR');
    expect(account.available, isTrue);
    expect(account.isPrimary, isTrue);
    expect(account.maintenanceNote, isEmpty);
  });

  test('换卡响应兼容历史跳转字段并返回首个非空地址', () {
    final reply = GatewayReply.parse(<String, dynamic>{
      'unaccepted': 0,
      'unstably': 'ok',
      'indulgences': <String, dynamic>{
        'flowerpot': '',
        'proclises': 'https://example.test/order-updated',
      },
    });

    expect(payoutRedirectUrlFrom(reply), 'https://example.test/order-updated');
  });
}
