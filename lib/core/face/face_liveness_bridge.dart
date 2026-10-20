import 'dart:io' show Platform;

import 'package:flutter/services.dart';

class FaceLivenessResult {
  const FaceLivenessResult({
    required this.success,
    required this.code,
    required this.message,
    required this.image,
    required this.livenessId,
    required this.requestId,
    required this.rawJson,
  });

  final bool success;
  final int code;
  final String message;
  final String image;
  final String livenessId;
  final String requestId;
  final String rawJson;
}

/// 同盾活体是否返回了可用于上传的数据。
///
/// 与 `peso_shield` 一致，以图片和 liveness_id 是否齐全作为上传门控，避免
/// SDK 回调里的结果码与可上传数据不一致时误拦截。
bool hasUploadableLivenessData(FaceLivenessResult result) =>
    result.image.isNotEmpty && result.livenessId.isNotEmpty;

abstract interface class FaceLivenessLauncher {
  Future<FaceLivenessResult> start(String license);
}

class FaceLivenessBridge implements FaceLivenessLauncher {
  FaceLivenessBridge({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'handa_peso/face_bridge';
  static final instance = FaceLivenessBridge();

  final MethodChannel _channel;

  @override
  Future<FaceLivenessResult> start(String license) async {
    if (!Platform.isIOS) {
      return const FaceLivenessResult(
        success: false,
        code: -1,
        message: 'Face verification is only available on iOS.',
        image: '',
        livenessId: '',
        requestId: '',
        rawJson: '',
      );
    }
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'showTrustDecisionLiveness',
        license,
      );
      if (result == null) {
        return const FaceLivenessResult(
          success: false,
          code: -1,
          message: 'Face verification returned no result.',
          image: '',
          livenessId: '',
          requestId: '',
          rawJson: '',
        );
      }
      return FaceLivenessResult(
        success: _parseBool(result['success']),
        code: _parseInt(result['code']),
        message: _parseString(result['message']),
        image: _parseString(result['image']),
        livenessId: _parseString(result['liveness_id']),
        requestId: _parseString(result['request_id']),
        rawJson: _parseString(result['raw_json']),
      );
    } on PlatformException catch (error) {
      return FaceLivenessResult(
        success: false,
        code: -1,
        message: error.message ?? 'Unable to start face verification.',
        image: '',
        livenessId: '',
        requestId: '',
        rawJson: '',
      );
    } on MissingPluginException {
      return const FaceLivenessResult(
        success: false,
        code: -1,
        message: 'Face verification is unavailable.',
        image: '',
        livenessId: '',
        requestId: '',
        rawJson: '',
      );
    }
  }

  static bool _parseBool(Object? value) {
    if (value is bool) return value;
    return value?.toString().trim().toLowerCase() == 'true';
  }

  static int _parseInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? -1;
  }

  static String _parseString(Object? value) =>
      value is String ? value.trim() : '';
}
