import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/features/home/home_data.dart';

/// 2026-10-13 从测试网关抓取的 `/dropcloth/indulgences` 游客响应。
///
/// 除 `Broodiest`（首页滚动广告，50 条）只保留前 2 条外，其余字段与网关
/// 原样一致。用例锁住网关真正下发的模块令牌：文档「首页元素」里的大写
/// 可读名（`LARGE_CARD` 等）只是语义标注，实际字段值是本应用专属令牌，
/// 一旦按可读名匹配，整个首页会因为解析不到模块而渲染成空状态。
const String _liveGuestResponse = r'''
{
  "unaccepted": 0,
  "unstably": "success",
  "indulgences": {
    "endoscopes": {
      "walleyed": "http://8.220.176.2/staticimg/kf.png",
      "counteract": "http://8.220.176.2/#/PonderersCollotypies"
    },
    "latchstrings": [
      {
        "trollopy": "TophBacks",
        "ranulas": [
          {
            "dependable": 3,
            "originator": "http://ph-handa-peso-ios-files-prod.oss-ap-southeast-6.aliyuncs.com/files/img/20240708/20240708183709_4h6k3wpoqd_img.png?OSSAccessKeyId=LTAI5tFoaHbXhN5cxfEjFcuK&Expires=1981103870&Signature=%2FnGunpElhIDjIMP6zhkG8%2BpRQBI%3D",
            "tidewaters": "http://8.220.178.113/ph-mti/suppose/hundred?elbow=3"
          },
          {
            "dependable": 2,
            "originator": "http://ph-handa-peso-ios-files-prod.oss-ap-southeast-6.aliyuncs.com/files/img/20240716/20240716142747_t4jumz6a6n_img.png?OSSAccessKeyId=LTAI5tFoaHbXhN5cxfEjFcuK&Expires=1981103870&Signature=LVWFGk9Gi5ioC1OB2azfqqMY%2B4c%3D",
            "tidewaters": "http://8.220.178.113/ph-mti/suppose/hundred?elbow=1"
          },
          {
            "dependable": 1,
            "originator": "http://ph-handa-peso-ios-files-prod.oss-ap-southeast-6.aliyuncs.com/files/img/20240716/20240716142705_cayujqrdbx_img.png?OSSAccessKeyId=LTAI5tFoaHbXhN5cxfEjFcuK&Expires=1981103870&Signature=DFBowR78p%2FeV0xOG2IKARAxjmYM%3D",
            "tidewaters": ""
          }
        ]
      },
      {
        "trollopy": "Jailbirds",
        "ranulas": [
          {
            "dependable": 2,
            "dullard": "Handa Peso",
            "circularise": "http://ph-mabilis-tala-ios-files-prod.oss-ap-southeast-6.aliyuncs.com/202407/20240704154448_8072gvdnet.png?OSSAccessKeyId=LTAI5t78TGu6HedpoZRABpsN&Expires=1909295088&Signature=8A6fB%2BlztSCeHkbZAaJyYruUb%2F8%3D",
            "unchivalrous": "Apply Now",
            "flaunter": "₱60,000",
            "outeating": "Maximum Loan Amount Upto",
            "pyranoside": "120 days",
            "farle": "Loan Term",
            "phalarope": "0.05% day",
            "disgruntle": "Interest Rate",
            "ochone": "",
            "masklike": "",
            "unglove": "Complete the authentication in just 3 minutes and got ₱60,000",
            "bioregional": 0,
            "microfarads": [],
            "varyingly": []
          }
        ]
      },
      {
        "trollopy": "Broodiest",
        "ranulas": [
          {
            "canonic": "<span style=\"font-family: Helvetica, system-ui, -apple-system, sans-serif; font-size: 12px; color: #666666;\"><span style=\"color: #FF8D32; font-weight: bold;\">2,500 pesos</span> to user J***</span>"
          },
          {
            "canonic": "<span style=\"font-family: Helvetica, system-ui, -apple-system, sans-serif; font-size: 12px; color: #666666;\"><span style=\"color: #FF8D32; font-weight: bold;\">1,500 pesos</span> to user U***</span>"
          }
        ]
      },
      {
        "trollopy": "PeriplasmAddition",
        "ranulas": []
      }
    ]
  }
}
''';

Map<String, dynamic> _dataFrom(String body) {
  final envelope = jsonDecode(body) as Map<String, dynamic>;
  return Map<String, dynamic>.from(envelope['indulgences'] as Map);
}

void main() {
  group('HomeData.fromJson', () {
    test('真实响应解析出主卡片，而不是空数据', () {
      final data = HomeData.fromJson(_dataFrom(_liveGuestResponse));

      expect(data.isEmpty, isFalse);
      final card = data.loanCard;
      expect(card, isNotNull);
      expect(card!.productId, '2');
      expect(card.productName, 'Handa Peso');
      expect(card.amountText, '₱60,000');
      expect(card.amountCaption, 'Maximum Loan Amount Upto');
      expect(card.termText, '120 days');
      expect(card.termCaption, 'Loan Term');
      expect(card.rateText, '0.05% day');
      expect(card.rateCaption, 'Interest Rate');
      expect(card.processText, contains('Complete the authentication'));
      // 游客未认证：授信进度条与期数列表都为空。
      expect(card.hasLimitSteps, isFalse);
      expect(card.periodTerms, isEmpty);
      // Banner 与滚动广告不属于信息流卡片：Banner 另走 banners 字段。
      expect(data.offers, isEmpty);
      expect(data.banners, hasLength(3));
      expect(data.banners.first.id, '3');
      expect(
        data.banners.first.imageUrl,
        contains('20240708183709_4h6k3wpoqd_img.png'),
      );
      expect(
        data.banners.first.targetUrl,
        'http://8.220.178.113/ph-mti/suppose/hundred?elbow=3',
      );
      // 最后一张没有跳转链接：只展示，不可点击。
      expect(data.banners.last.targetUrl, isEmpty);
    });

    test('Banner 条目缺少图片时被丢弃，字段两端空白被去掉', () {
      final data = HomeData.fromJson(<String, dynamic>{
        'latchstrings': <Map<String, dynamic>>[
          <String, dynamic>{
            'trollopy': 'TophBacks',
            'ranulas': <Map<String, dynamic>>[
              <String, dynamic>{
                'dependable': 1,
                'originator': '',
                'tidewaters': 'http://example.test/1',
              },
              <String, dynamic>{
                'dependable': 2,
                'originator': '  http://example.test/b.png  ',
                'tidewaters': '  http://example.test/landing  ',
              },
            ],
          },
        ],
      });

      expect(data.isEmpty, isFalse);
      expect(data.banners, hasLength(1));
      expect(data.banners.single.id, '2');
      expect(data.banners.single.imageUrl, 'http://example.test/b.png');
      expect(data.banners.single.targetUrl, 'http://example.test/landing');
    });

    test('推荐列表令牌解析为导流产品', () {
      final data = HomeData.fromJson(<String, dynamic>{
        'latchstrings': <Map<String, dynamic>>[
          <String, dynamic>{
            'trollopy': 'InspissateDismantling',
            'ranulas': <Map<String, dynamic>>[
              <String, dynamic>{
                'dependable': 7,
                'dullard': 'Pera Pitaka(AA)',
                'circularise': '',
                'unchivalrous': 'Apply',
                'flaunter': '₱50,000',
                'outeating': 'Maximum Loan Amount Upto',
                'pyranoside': '121day',
                'phalarope': '≥ 0.05%/day',
                'asbestine': 1,
              },
            ],
          },
        ],
      });

      expect(data.isEmpty, isFalse);
      expect(data.offers, hasLength(1));
      final offer = data.offers.single;
      expect(offer.productId, '7');
      expect(offer.productName, 'Pera Pitaka(AA)');
      expect(offer.amountText, '₱50,000');
      expect(offer.buttonText, 'Apply');
      expect(offer.tone, HomeApplyTone.highlight);
      expect(data.loanCard, isNull);
    });
  });
}
