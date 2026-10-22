import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/network/gateway_reply.dart';
import 'package:handa_peso/features/home/home_popup_models.dart';

GatewayReply _reply(int type, Map<String, dynamic> content) {
  return GatewayReply.parse(<String, dynamic>{
    'unaccepted': 0,
    'unstably': 'success',
    'indulgences': <String, dynamic>{'trollopy': type, 'revetting': content},
  });
}

void main() {
  test('营销弹窗解析图片和 Web 跳转地址', () {
    final config = HomePopupConfig.fromReply(
      _reply(3, <String, dynamic>{
        'delinquency': 'https://example.test/popup.png',
        'tidewaters': 'https://example.test/offer',
      }),
    );

    expect(config.kind, HomePopupKind.marketing);
    expect(config.imageUrl, 'https://example.test/popup.png');
    expect(config.targetUrl, 'https://example.test/offer');
    expect(config.shouldShow, isTrue);
  });

  test('应用升级弹窗解析版本、文案和下载地址', () {
    final config = HomePopupConfig.fromReply(
      _reply(1, <String, dynamic>{
        'noncounty': '1.2.0',
        'tubby': 'A newer version is available',
        'tidewaters': 'https://example.test/app',
      }),
    );

    expect(config.kind, HomePopupKind.appUpgrade);
    expect(config.version, '1.2.0');
    expect(config.message, 'A newer version is available');
    expect(config.targetUrl, 'https://example.test/app');
  });

  test('会员升级弹窗解析前后等级与权益', () {
    final config = HomePopupConfig.fromReply(
      _reply(2, <String, dynamic>{
        'botanic': <String, dynamic>{
          'definitively': 'Level I',
          'headway': 'https://example.test/level-1.png',
        },
        'ward': <String, dynamic>{
          'definitively': 'Level II',
          'headway': 'https://example.test/level-2.png',
        },
        'debilities': <Map<String, dynamic>>[
          <String, dynamic>{
            'flatfish': 'Increase loan amount',
            'headway': 'https://example.test/benefit.png',
          },
        ],
      }),
    );

    expect(config.previousLevel, 'Level I');
    expect(config.currentLevel, 'Level II');
    expect(config.benefits.single.title, 'Increase loan amount');
  });

  test('无弹窗和未知类型不展示', () {
    expect(
      HomePopupConfig.fromReply(_reply(0, const <String, dynamic>{}))
          .shouldShow,
      isFalse,
    );
    expect(
      HomePopupConfig.fromReply(_reply(9, const <String, dynamic>{}))
          .shouldShow,
      isFalse,
    );
  });
}
