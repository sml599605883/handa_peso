import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../json/json_utils.dart';
import 'gateway_failure.dart';
import 'gateway_reply.dart';
import 'gateway_settings.dart';
import 'payload_cipher.dart';
import 'request_signer.dart';
import 'wire_format.dart';

/// 网关传输层。
///
/// 只做四件事：给每个请求附加公有参数与签名、把响应解包成 [GatewayReply]、
/// 把 Dio 与业务错误统一成 [GatewayFailure]、会话失效时通知上层重新登录。
/// 具体接口方法见 `gateway_client.dart`。
class GatewayTransport {
  GatewayTransport(this.settings, {Dio? dio}) : dio = dio ?? Dio() {
    this.dio.options
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 20)
      ..contentType = Headers.formUrlEncodedContentType
      ..validateStatus = (_) => true;
  }

  final GatewaySettings settings;
  final Dio dio;

  /// 混淆字段的位数：网关要求每个请求带上几位随机数字。
  static const _noiseLength = 6;

  late final RequestSigner signer = RequestSigner(settings);

  /// 上报类接口的载荷加密器，密钥来自 [settings]。
  late final PayloadCipher cipher = PayloadCipher(
    secret: settings.cipherSecret,
    vector: settings.cipherVector,
  );

  bool _recoveringSession = false;
  String? _proxyHost;
  int? _proxyPort;

  /// 当前生效的系统代理；没有配置代理时为 `null`。
  String? get proxyHost => _proxyHost;
  int? get proxyPort => _proxyPort;

  /// 让后续请求都走指定的 HTTP 代理（抓包用）。
  ///
  /// Dart 的 `HttpClient` 不会自动读取 iOS 的系统代理设置，所以 host/port 得
  /// 由原生层读出来再回灌到这里。开启 [trustAnyCertificate] 只有在抓包工具对
  /// HTTPS 做中间人解密、而设备还没信任其根证书时才需要；默认保持系统校验。
  void useProxy({
    required String host,
    required int port,
    bool trustAnyCertificate = false,
  }) {
    _proxyHost = host;
    _proxyPort = port;
    dio.httpClientAdapter.close(force: true);
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()..findProxy = (_) => 'PROXY $host:$port;';
        if (trustAnyCertificate) {
          client.badCertificateCallback = (_, _, _) => true;
        }
        return client;
      },
    );
  }

  /// 启动门禁用的轻量可达性探测。
  ///
  /// 网关只要回了任意 HTTP 状态码就算可达（业务错误也算），只有传输层失败
  /// （超时、DNS 失败、连接被拒）才是不可达。
  Future<bool> probeReachability() async {
    try {
      final response = await dio.getUri<String>(
        Uri.parse(settings.apiOrigin),
        options: Options(
          responseType: ResponseType.plain,
          validateStatus: (_) => true,
        ),
      );
      return response.statusCode != null;
    } on DioException catch (error) {
      return error.response?.statusCode != null;
    }
  }

  /// 从备用地址源拉取域名配置，成功后覆盖 [settings] 的 API/Web 域名。
  ///
  /// 响应体兼容纯 JSON 与 base64 编码的 JSON 两种写法（沿用同族项目的服务端
  /// 约定）。永不抛异常；只有真的应用了新地址才返回 `true`，调用方据此重新探测。
  Future<bool> refreshOrigins({String? sourceUrl}) async {
    final url = (sourceUrl ?? settings.spareSourceUrl).trim();
    if (url.isEmpty) return false;

    final config = _decodeConfig(await _readPlainBody(url));
    final api = config.stringValue('api');
    if (api.isEmpty) return false;

    settings.apiOrigin = api;
    final web = config.stringValue('web');
    if (web.isNotEmpty) settings.webOrigin = web;
    return true;
  }

  /// GET 请求。[noise] 里的键会带上随机数字一起发送。
  Future<GatewayReply> read(
    String route, {
    Map<String, dynamic> query = const <String, dynamic>{},
    List<String> noise = const <String>[],
  }) async {
    final signed = await signer.signedQuery(
      path: route,
      extra: <String, dynamic>{...query, ..._noise(noise)},
    );
    final response = await _guard(
      () => dio.get<dynamic>(_absolutize(route), queryParameters: signed),
    );
    return _unwrap(response);
  }

  /// POST 表单请求。[body] 是业务参数，[noise] 里的键会带上随机数字。
  Future<GatewayReply> write(
    String route, {
    Map<String, dynamic> body = const <String, dynamic>{},
    Map<String, dynamic> query = const <String, dynamic>{},
    List<String> noise = const <String>[],
  }) async {
    final signed = await signer.signedQuery(path: route, extra: query);
    final response = await _guard(
      () => dio.post<dynamic>(
        _absolutize(route),
        queryParameters: signed,
        data: <String, dynamic>{...body, ..._noise(noise)},
      ),
    );
    return _unwrap(response);
  }

  /// multipart 上传。[field] 是文件字段名。
  Future<GatewayReply> multipart(
    String route, {
    required String filePath,
    required String field,
    Map<String, dynamic> body = const <String, dynamic>{},
    Map<String, dynamic> query = const <String, dynamic>{},
    List<String> noise = const <String>[],
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw const GatewayFailure(
        'The selected file is no longer available.',
        code: 'upload_missing_file',
      );
    }

    final signed = await signer.signedQuery(path: route, extra: query);
    final form = FormData.fromMap(<String, dynamic>{
      ...body,
      ..._noise(noise),
      field: await MultipartFile.fromFile(file.path),
    });
    final response = await _guard(
      () => dio.post<dynamic>(
        _absolutize(route),
        queryParameters: signed,
        data: form,
        options: Options(contentType: Headers.multipartFormDataContentType),
      ),
    );
    return _unwrap(response);
  }

  /// 提交已经加密过的载荷：明文先过 [cipher]，密文放进信封的载荷字段。
  Future<GatewayReply> sealed(
    String route, {
    required String value,
    Map<String, dynamic> body = const <String, dynamic>{},
    Map<String, dynamic> query = const <String, dynamic>{},
    List<String> noise = const <String>[],
  }) {
    return write(
      route,
      body: <String, dynamic>{...body, WireFormat.payloadField: value},
      query: query,
      noise: noise,
    );
  }

  Map<String, dynamic> _noise(List<String> keys) {
    final provider = settings.noiseDigits;
    return <String, dynamic>{
      for (final key in keys)
        key:
            provider?.call(_noiseLength) ??
            RequestSigner.secureDigits(_noiseLength),
    };
  }

  Future<Response<dynamic>> _guard(
    Future<Response<dynamic>> Function() send,
  ) async {
    try {
      return await send();
    } on DioException catch (error) {
      throw _translate(error);
    }
  }

  GatewayFailure _translate(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return GatewayFailure.timedOut(error);
      case DioExceptionType.cancel:
        return GatewayFailure.aborted();
      case DioExceptionType.connectionError:
        return GatewayFailure.unreachable(error);
      case DioExceptionType.badResponse:
        return _httpFailure(error.response?.statusCode ?? 0, error);
      case DioExceptionType.badCertificate:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return GatewayFailure.unreachable(error);
    }
  }

  GatewayFailure _httpFailure(int status, [Object? cause]) {
    if (status == 401) return GatewayFailure.sessionExpired();
    final note = _noteFromBody(cause);
    return GatewayFailure(
      note.isEmpty ? 'Request failed ($status).' : note,
      code: 'http_$status',
      statusCode: status,
      cause: cause,
    );
  }

  /// 从 HTTP 错误响应里取网关自己的文案（`unstably`）。
  ///
  /// 状态码 >= 400 时响应体通常还是那条标准信封，里面的文案（例如「验证码错误」）
  /// 比本地拼的 `Request failed (500).` 有用得多。
  String _noteFromBody(Object? cause) {
    final raw = cause is DioException ? cause.response?.data : cause;
    Object? body = raw;
    if (raw is String) {
      try {
        body = jsonDecode(raw);
      } on FormatException {
        return '';
      }
    }
    if (body is! Map) return '';
    return '${body[WireFormat.noteField] ?? ''}'.trim();
  }

  Future<GatewayReply> _unwrap(Response<dynamic> response) async {
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      throw _httpFailure(status, response.data);
    }
    final reply = GatewayReply.parse(response.data);
    if (reply.isSessionExpired) {
      await _recoverSession(reply.note);
    }
    return reply.orThrow();
  }

  /// 会话失效只通知一次：并发请求里第一个负责跳登录，其余的立即失败。
  Future<void> _recoverSession(String note) async {
    if (_recoveringSession) {
      throw GatewayFailure(note, code: '-2');
    }
    _recoveringSession = true;
    try {
      await settings.onSessionExpired?.call();
    } finally {
      _recoveringSession = false;
    }
    throw GatewayFailure(note, code: '-2');
  }

  String _absolutize(String route) {
    if (route.startsWith('http://') || route.startsWith('https://')) {
      return route;
    }
    return route.startsWith('/')
        ? '${settings.apiOrigin}$route'
        : '${settings.apiOrigin}/$route';
  }

  Future<String> _readPlainBody(String url) async {
    try {
      final response = await dio.get<String>(
        url,
        options: Options(responseType: ResponseType.plain),
      );
      return response.data ?? '';
    } catch (_) {
      return '';
    }
  }

  /// 兼容纯 JSON 与 base64(JSON) 两种响应体。
  Map<String, dynamic> _decodeConfig(String body) {
    final text = body.trim();
    if (text.isEmpty) return const <String, dynamic>{};

    final direct = _asJsonObject(text);
    if (direct != null) return direct;

    try {
      return _asJsonObject(utf8.decode(base64Decode(text))) ??
          const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Map<String, dynamic>? _asJsonObject(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }
}
