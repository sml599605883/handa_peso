import '../../core/json/json_utils.dart';
import '../../core/network/gateway_reply.dart';

/// 人脸认证页走完后回传给调用方的完成标记。
class FaceVerificationOutcome {
  static const String argumentKey = 'faceVerificationOutcome';

  bool completed = false;

  static FaceVerificationOutcome? of(Object? arguments) {
    if (arguments is! Map) return null;
    final value = arguments[argumentKey];
    return value is FaceVerificationOutcome ? value : null;
  }
}

/// MyTools「获取face++ token」接口的响应。
///
/// 只有 `beet=200`、`obsoletely` 非空且 `esplanades=7` 时才能交给
/// TrustDecision SDK；`beet=400` 表示需要重新上传身份证，`500` 表示其他错误。
class FaceTokenResult {
  const FaceTokenResult({
    required this.resultCode,
    required this.faceType,
    required this.license,
    required this.faceBaseUrl,
    required this.error,
  });

  factory FaceTokenResult.fromReply(GatewayReply reply) {
    final payload = reply.payload;
    return FaceTokenResult(
      resultCode: payload.intValue('beet'),
      faceType: payload.intValue('esplanades'),
      license: payload.stringValue('obsoletely').trim(),
      faceBaseUrl: payload.stringValue('districts').trim(),
      error: payload.stringValue('genomes').trim(),
    );
  }

  final int resultCode;
  final int faceType;
  final String license;
  final String faceBaseUrl;
  final String error;

  bool get isReady => resultCode == 200 && faceType == 7 && license.isNotEmpty;

  bool get needsIdentityUpload => resultCode == 400;
}
