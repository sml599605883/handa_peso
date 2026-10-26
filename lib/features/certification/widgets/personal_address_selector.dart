import 'package:flutter/material.dart';

import '../../../app/navigation/app_navigator.dart';
import '../../../core/network/gateway_client.dart';
import '../personal_information_models.dart';
import 'personal_information_selectors.dart';

/// 地址请求与弹层的统一入口。
///
/// 地址目录在本次 App 进程内不会变化，因此首次请求成功后缓存到静态变量。
/// 这里不落盘，App 重启后缓存自然失效并重新请求。请求进行中复用同一个
/// Future，避免连续点击产生并发请求。
abstract final class PersonalAddressSelector {
  static List<PersonalAddressNode>? _cached;
  static Future<List<PersonalAddressNode>>? _pending;

  static Future<String?> show(
    BuildContext context, {
    required GatewayClient apiClient,
  }) async {
    final List<PersonalAddressNode> addresses;
    try {
      addresses = await _load(apiClient);
    } catch (_) {
      return null;
    }
    if (!context.mounted) return null;
    return showPersonalInformationAddressSheet(
      context: context,
      nodes: addresses,
    );
  }

  /// 进入个人信息 / 工作信息页时预取地址目录。
  ///
  /// 地址接口只在点开地址字段时才需要结果，但那一刻再请求会让弹层先转圈等
  /// 接口；页面一进来就拉好，点选时直接命中缓存。预取失败不打扰用户：真正
  /// 点开时会重新请求并给出提示。
  static Future<void> prefetch(GatewayClient apiClient) async {
    if (_cached != null) return;
    try {
      await _load(apiClient, silent: true);
    } catch (_) {
      // 预取失败只影响这一次提速，不是用户可感知的错误。
    }
  }

  static Future<List<PersonalAddressNode>> _load(
    GatewayClient apiClient, {
    bool silent = false,
  }) async {
    final cached = _cached;
    if (cached != null) return cached;

    final pending = _pending;
    if (pending != null) return pending;

    final request = _request(apiClient, silent: silent);
    _pending = request;
    try {
      return await request;
    } finally {
      if (identical(_pending, request)) _pending = null;
    }
  }

  static Future<List<PersonalAddressNode>> _request(
    GatewayClient apiClient, {
    bool silent = false,
  }) async {
    if (!silent) await AppNavigator.showLoading();
    try {
      final reply = await apiClient.fetchCityOptions();
      reply.orThrow();
      final addresses = PersonalAddressNode.fromReply(reply);
      _cached = addresses;
      return addresses;
    } catch (_) {
      if (!silent) AppNavigator.showError('Unable to load address options');
      rethrow;
    } finally {
      if (!silent) await AppNavigator.dismissLoading();
    }
  }

  /// 测试或显式刷新地址目录时使用。
  static void clearCache() {
    _cached = null;
    _pending = null;
  }
}
