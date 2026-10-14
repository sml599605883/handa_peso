import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

import '../json/json_utils.dart';
import 'api_config.dart';
import 'api_crypto.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';
import 'api_response.dart';
import 'api_signature.dart';

/// 强类型网关客户端。
///
/// 每个请求都会被签名（见 [ApiSignature]），每个响应都会被解包为
/// [ApiResponse]。业务失败以 [ApiException] 的形式抛出，调用方无需
/// 接触原始的 Dio 类型。
class ApiClient {
  ApiClient(this.config, {Dio? dio}) : dio = dio ?? Dio() {
    this.dio.options
      ..connectTimeout = const Duration(seconds: 20)
      ..receiveTimeout = const Duration(seconds: 20)
      ..contentType = Headers.formUrlEncodedContentType
      ..validateStatus = (_) => true;
  }

  final ApiConfig config;
  final Dio dio;

  late final ApiCrypto crypto = ApiCrypto(
    key: config.encryptKey,
    iv: config.encryptIv,
  );

  bool _handlingAuthExpired = false;
  String? _proxyHost;
  int? _proxyPort;

  /// 当前生效的系统代理；未配置代理时为 `null`。
  String? get proxyHost => _proxyHost;
  int? get proxyPort => _proxyPort;

  // ---------------------------------------------------------------------------
  // 鉴权与账号
  // ---------------------------------------------------------------------------

  Future<ApiResponse> sendSmsCode({
    required String fishtailed,
    String checkreins = 'sms',
  }) {
    return post(
      ApiEndpoints.sendSmsCode,
      data: {
        'fishtailed': fishtailed,
        'checkreins': checkreins,
        'hastened': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> smsChannels({required String fishtailed}) {
    return post(
      ApiEndpoints.smsChannels,
      data: {
        'fishtailed': fishtailed,
        'affluents': _randomDigits(6),
        'chaffers': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> smsCodeLogin({
    required String criminology,
    required String legongs,
  }) {
    return post(
      ApiEndpoints.smsCodeLogin,
      data: {
        'criminology': criminology,
        'legongs': legongs,
        'affluents': _randomDigits(6),
        'chaffers': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> logout() {
    return get(
      ApiEndpoints.logout,
      params: {'phellem': _randomDigits(6), 'postforming': _randomDigits(6)},
    );
  }

  Future<ApiResponse> deleteAccount() {
    return get(
      ApiEndpoints.deleteAccount,
      params: {'commuters': _randomDigits(6)},
    );
  }

  // ---------------------------------------------------------------------------
  // 应用外壳与首页
  // ---------------------------------------------------------------------------

  Future<ApiResponse> homePage() {
    return get(
      ApiEndpoints.homePage,
      params: {'riposted': _randomDigits(6), 'wresting': _randomDigits(6)},
    );
  }

  Future<ApiResponse> personalCenter() {
    return get(
      ApiEndpoints.personalCenter,
      params: {'uncloudedly': _randomDigits(6)},
    );
  }

  Future<ApiResponse> appReport({
    required String khedas,
    required String inanest,
  }) {
    return post(
      ApiEndpoints.appReport,
      data: {
        'khedas': khedas,
        'inanest': inanest,
        'treasuring': _randomDigits(6),
      },
    );
  }

  /// app上报 —— 动态域名切换上报（`khedas=1`）。
  ///
  /// [payload] 承载本次切换过程的日志载荷；`khedas` 固定为 `1`（动态域名上报），
  /// 另一个取值 `2` 用于流程埋点上报。失败由调用方兜底。
  Future<void> reportEndpointSwitch(String payload) {
    return appReport(khedas: '1', inanest: payload);
  }

  Future<ApiResponse> reCredit() {
    return get(
      ApiEndpoints.reCredit,
      params: {'contemplate': _randomDigits(6)},
    );
  }

  Future<ApiResponse> dialog({required int disobliges}) {
    return get(ApiEndpoints.dialog, params: {'disobliges': disobliges});
  }

  Future<ApiResponse> bannerClickRecord({required String interreligious}) {
    return post(
      ApiEndpoints.bannerClickRecord,
      data: {'interreligious': interreligious, 'hearten': _randomDigits(6)},
    );
  }

  Future<ApiResponse> getDeviceName({required String definitively}) {
    return post(
      ApiEndpoints.getDeviceName,
      data: {'definitively': definitively, 'hearten': _randomDigits(6)},
    );
  }

  // ---------------------------------------------------------------------------
  // 产品
  // ---------------------------------------------------------------------------

  Future<ApiResponse> productApply({
    required String cotype,
    String efflorescence = '0',
  }) {
    return post(
      ApiEndpoints.productApply,
      data: {
        'jumpiest': '1001',
        'plundered': '1000',
        'caesium': '1000',
        'cotype': cotype,
        'efflorescence': efflorescence,
        'strikes': _randomDigits(6),
        'somans': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> productDetail({required String cotype}) {
    return post(
      ApiEndpoints.productDetail,
      data: {
        'cotype': cotype,
        'suffocation': _randomDigits(6),
        'undraping': _randomDigits(6),
        'anecdotes': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> productPush({
    required String eelworm,
    required String luciferins,
    required String splashiest,
    required String curb,
  }) {
    return post(
      ApiEndpoints.productPush,
      data: {
        'eelworm': eelworm,
        'luciferins': luciferins,
        'splashiest': splashiest,
        'curb': curb,
        'floggers': _randomDigits(6),
        'sententia': _randomDigits(6),
        'colonics': _randomDigits(6),
        'scorekeepers': _randomDigits(6),
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 认证
  // ---------------------------------------------------------------------------

  Future<ApiResponse> basicPersonInfo({required String cotype}) {
    return get(
      ApiEndpoints.basicPersonInfo,
      params: {'cotype': cotype, 'prebendaries': _randomDigits(6)},
    );
  }

  Future<ApiResponse> uploadImage({
    required String filePath,
    String fileField = 'attach',
    Map<String, dynamic> data = const <String, dynamic>{},
  }) {
    return upload(
      ApiEndpoints.uploadImage,
      filePath: filePath,
      fileField: fileField,
      data: data,
    );
  }

  Future<ApiResponse> saveBasicInfo({required Map<String, dynamic> data}) {
    return post(ApiEndpoints.saveBasicInfo, data: data);
  }

  Future<ApiResponse> checkBasicPass({required String cotype}) {
    return post(
      ApiEndpoints.checkBasicPass,
      data: {
        'cotype': cotype,
        'nonperformer': _randomDigits(6),
        'gushes': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> getFaceIdToken({
    required String eelworm,
    required String trollopy,
  }) {
    return post(
      ApiEndpoints.getFaceIdToken,
      data: {
        'eelworm': eelworm,
        'trollopy': trollopy,
        'dis': _randomDigits(6),
        'popularizes': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> advanceLog({required Map<String, dynamic> data}) {
    return post(ApiEndpoints.advanceLog, data: data);
  }

  Future<ApiResponse> faceIdTokenUpload({required Map<String, dynamic> data}) {
    return post(ApiEndpoints.faceIdTokenUpload, data: data);
  }

  Future<ApiResponse> faceIdResultUpload({required Map<String, dynamic> data}) {
    return post(ApiEndpoints.faceIdResultUpload, data: data);
  }

  Future<ApiResponse> personalInfo({required String cotype}) {
    return post(
      ApiEndpoints.personalInfo,
      data: {'cotype': cotype, 'bondstone': _randomDigits(6)},
    );
  }

  Future<ApiResponse> savePersonalInfo({required Map<String, dynamic> data}) {
    return post(ApiEndpoints.savePersonalInfo, data: data);
  }

  Future<ApiResponse> jobInfo({required String cotype}) {
    return get(
      ApiEndpoints.jobInfo,
      params: {'cotype': cotype, 'bondstone': _randomDigits(6)},
    );
  }

  Future<ApiResponse> saveJobInfo({required Map<String, dynamic> data}) {
    return post(
      ApiEndpoints.saveJobInfo,
      data: {
        ...data,
        'salpinges': _randomDigits(6),
        'determiner': _randomDigits(6),
        'fertilizers': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> extInfoV2({required String cotype}) {
    return get(
      ApiEndpoints.extInfoV2,
      params: {'cotype': cotype, 'tatty': _randomDigits(6)},
    );
  }

  Future<ApiResponse> saveExtInfoV2({
    required String cotype,
    required List<Map<String, dynamic>> contacts,
  }) {
    return post(
      ApiEndpoints.saveExtInfoV2,
      data: {
        'cotype': cotype,
        'indulgences': jsonEncode(contacts),
        'monumentalizes': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> cardInit({required String cotype}) {
    return get(
      ApiEndpoints.cardInit,
      params: {
        'cotype': cotype,
        'pastorales': _randomDigits(6),
        'replunge': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> bindCard({required Map<String, dynamic> data}) {
    return post(ApiEndpoints.bindCard, data: data);
  }

  Future<ApiResponse> cityInit() => get(ApiEndpoints.cityInit);

  Future<ApiResponse> userCardList({required String cotype}) {
    return post(
      ApiEndpoints.userCardList,
      data: {
        'cotype': cotype,
        'tetracids': _randomDigits(6),
        'oozed': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> changeOrderAccount({
    required String eelworm,
    required String eyeglasses,
  }) {
    return post(
      ApiEndpoints.changeOrderAccount,
      data: {
        'eelworm': eelworm,
        'eyeglasses': eyeglasses,
        'guaiocums': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> retentionDialog({
    required String ulterior,
    required String knife,
  }) {
    return post(
      ApiEndpoints.retentionDialog,
      data: {
        'ulterior': ulterior,
        'knife': knife,
        'chauvinistic': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> trustDecisionReport({
    required String ediblenesses,
    required String eggplants,
    required String beet,
    required String murdering,
  }) {
    return post(
      ApiEndpoints.trustDecisionReport,
      data: {
        'ediblenesses': ediblenesses,
        'eggplants': eggplants,
        'beet': beet,
        'murdering': murdering,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 订单
  // ---------------------------------------------------------------------------

  Future<ApiResponse> orderList({
    required String corequisites,
    String girlies = '1',
    String uncompromisable = '50',
  }) {
    return post(
      ApiEndpoints.orderList,
      data: {
        'corequisites': corequisites,
        'girlies': girlies,
        'uncompromisable': uncompromisable,
      },
    );
  }

  Future<ApiResponse> userReloan({required String chattinesses}) {
    return post(ApiEndpoints.userReloan, data: {'chattinesses': chattinesses});
  }

  // ---------------------------------------------------------------------------
  // 风控与埋点上报
  // ---------------------------------------------------------------------------

  Future<ApiResponse> uploadLocation({required Map<String, dynamic> data}) {
    return post(ApiEndpoints.uploadLocation, data: data);
  }

  Future<ApiResponse> googleMarket({
    required String tunesmith,
    required String colickiest,
  }) {
    return post(
      ApiEndpoints.googleMarket,
      data: {
        'tunesmith': tunesmith,
        'nevoid': _randomDigits(6),
        'colickiest': colickiest,
      },
    );
  }

  Future<ApiResponse> buriedPoint({required Map<String, dynamic> data}) {
    return post(
      ApiEndpoints.buriedPoint,
      data: {...data, 'pastorales': _randomDigits(6)},
    );
  }

  /// 设备详情上报。[payload] 必须先通过 [crypto] 进行 AES 加密；
  /// 网关只接受密文。
  Future<ApiResponse> uploadDeviceInfo({required String payload}) {
    return postEncrypted(ApiEndpoints.uploadDeviceInfo, value: payload);
  }

  /// 通讯录上报。[payload] 必须先通过 [crypto] 进行 AES 加密。
  Future<ApiResponse> uploadContacts({
    required String payload,
    String trollopy = '3',
  }) {
    return postEncrypted(
      ApiEndpoints.uploadContacts,
      value: payload,
      data: {
        'trollopy': trollopy,
        'wharfingers': _randomDigits(6),
        'toga': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> uploadAppleToken({required String bettered}) {
    return post(ApiEndpoints.uploadAppleToken, data: {'bettered': bettered});
  }

  // ---------------------------------------------------------------------------
  // 客服中心
  // ---------------------------------------------------------------------------

  Future<ApiResponse> supportTicket({
    required String grapier,
    String? skells,
    String? vespid,
    String? filthily,
    String? redecorates,
  }) {
    return post(
      ApiEndpoints.supportTicket,
      data: {
        'skells': ?skells,
        'vespid': ?vespid,
        'grapier': grapier,
        'filthily': ?filthily,
        'redecorates': ?redecorates,
        'hidalgos': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> supportTicketList() {
    return post(
      ApiEndpoints.supportTicketList,
      data: {'undraping': _randomDigits(6), 'riposted': _randomDigits(6)},
    );
  }

  Future<ApiResponse> supportSupplement({
    required String polemists,
    required String grapier,
    String? filthily,
  }) {
    return post(
      ApiEndpoints.supportSupplement,
      data: {'polemists': polemists, 'grapier': grapier, 'filthily': ?filthily},
    );
  }

  Future<ApiResponse> faqList({
    String? tsaddik,
    String? quagmire,
    String? redecorates,
  }) {
    return get(
      ApiEndpoints.faqList,
      params: {
        'tsaddik': ?tsaddik,
        'quagmire': ?quagmire,
        'redecorates': ?redecorates,
        'witnessed': _randomDigits(6),
      },
    );
  }

  Future<ApiResponse> supportPhone() {
    return get(
      ApiEndpoints.supportPhone,
      params: {'treasuring': _randomDigits(6)},
    );
  }

  // ---------------------------------------------------------------------------
  // 传输层
  // ---------------------------------------------------------------------------

  /// 让 Dio 通过系统 HTTP 代理发送请求，供 Proxyman/Charles 抓包使用。
  ///
  /// Dart 的 `HttpClient` 不会自动读取 iOS 的系统代理，因此即使设备已配置
  /// 抓包代理，请求仍会直连。这里用原生层读到的 host/port 重建 Adapter，
  /// 使后续请求都经过该代理。
  ///
  /// [allowBadCertificates] 仅在抓包代理对 HTTPS 做中间人解密、且设备尚未
  /// 信任其根证书时才需要打开；默认保持系统的证书校验。
  void setProxy({
    required String host,
    required int port,
    bool allowBadCertificates = false,
  }) {
    _proxyHost = host;
    _proxyPort = port;
    dio.httpClientAdapter.close(force: true);
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient()..findProxy = (_) => 'PROXY $host:$port;';
        if (allowBadCertificates) {
          client.badCertificateCallback = (certificate, host, port) => true;
        }
        return client;
      },
    );
  }

  /// 供启动门禁使用的轻量级网关可达性探测。
  ///
  /// 只要网关返回任意状态码即解析为 `true`，因此应用层错误仍算作可达。
  /// 传输层失败（超时、DNS 解析失败、连接被拒绝）解析为 `false`。
  Future<bool> probeTransport() async {
    try {
      final response = await dio.getUri<String>(
        Uri.parse(config.apiBaseUrl),
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

  /// 拉取远程配置链接里发布的备用基础地址。
  ///
  /// 请求 [remoteConfigUrl]（为空时回退到 [ApiConfig.remoteConfigUrl]），
  /// 用响应中的 `api` / `web` 字段覆盖 [ApiConfig.apiBaseUrl] 与
  /// [ApiConfig.webBaseUrl]。响应体同时兼容 JSON 对象与 base64 编码的 JSON
  /// 对象，与 kaibigan_loan 的约定保持一致。
  ///
  /// 永不抛异常。仅当新的 API 基础地址被应用时返回 `true`，
  /// 便于调用方针对该地址重新探测。
  Future<bool> applyRemoteBaseUrls({String? remoteConfigUrl}) async {
    final configUrl = (remoteConfigUrl ?? config.remoteConfigUrl).trim();
    if (configUrl.isEmpty) return false;

    final String body;
    try {
      final response = await dio.get<String>(
        configUrl,
        options: Options(responseType: ResponseType.plain),
      );
      body = response.data ?? '';
    } catch (_) {
      return false;
    }

    final parsed = _parseRemoteConfig(body);
    final api = parsed.stringValue('api');
    if (api.isEmpty) return false;

    config.apiBaseUrl = api;
    final web = parsed.stringValue('web');
    if (web.isNotEmpty) config.webBaseUrl = web;
    return true;
  }

  /// 解析远程配置响应体，兼容 JSON 对象与 base64 编码的 JSON 对象。
  Map<String, dynamic> _parseRemoteConfig(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return const <String, dynamic>{};

    final direct = _decodeJsonObject(trimmed);
    if (direct != null) return direct;

    try {
      return _decodeJsonObject(utf8.decode(base64Decode(trimmed))) ??
          const <String, dynamic>{};
    } catch (_) {
      return const <String, dynamic>{};
    }
  }

  Map<String, dynamic>? _decodeJsonObject(String source) {
    try {
      final decoded = jsonDecode(source);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  Future<ApiResponse> get(
    String path, {
    Map<String, dynamic> params = const <String, dynamic>{},
  }) async {
    final query = await ApiSignature(config)
        .buildSignedQuery(path: path, extraQuery: params);
    final response = await _guard(
      () => dio.get<dynamic>(_url(path), queryParameters: query),
    );
    return _handleResponse(response);
  }

  Future<ApiResponse> post(
    String path, {
    Map<String, dynamic> data = const <String, dynamic>{},
    Map<String, dynamic> query = const <String, dynamic>{},
    Options? options,
  }) async {
    final signed = await ApiSignature(config)
        .buildSignedQuery(path: path, extraQuery: query);
    final response = await _guard(
      () => dio.post<dynamic>(
        _url(path),
        queryParameters: signed,
        data: data,
        options: options,
      ),
    );
    return _handleResponse(response);
  }

  Future<ApiResponse> upload(
    String path, {
    required String filePath,
    required String fileField,
    Map<String, dynamic> data = const <String, dynamic>{},
    Map<String, dynamic> query = const <String, dynamic>{},
  }) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      throw ApiException(
        'The selected file is no longer available.',
        code: 'upload_missing_file',
      );
    }

    final signed = await ApiSignature(config)
        .buildSignedQuery(path: path, extraQuery: query);
    final formData = FormData.fromMap({
      ...data,
      fileField: await MultipartFile.fromFile(file.path),
    });
    final response = await _guard(
      () => dio.post<dynamic>(
        _url(path),
        queryParameters: signed,
        data: formData,
        options: Options(contentType: Headers.multipartFormDataContentType),
      ),
    );
    return _handleResponse(response);
  }

  /// 将已加密的载荷以网关的 `data` 字段提交。
  Future<ApiResponse> postEncrypted(
    String path, {
    required String value,
    Map<String, dynamic> data = const <String, dynamic>{},
    Map<String, dynamic> query = const <String, dynamic>{},
  }) {
    return post(path, data: {...data, 'indulgences': value}, query: query);
  }

  Future<Response<dynamic>> _guard(
    Future<Response<dynamic>> Function() request,
  ) async {
    try {
      return await request();
    } on DioException catch (error) {
      throw _mapDioException(error);
    }
  }

  ApiException _mapDioException(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return ApiException.timeout(error);
      case DioExceptionType.cancel:
        return ApiException.cancelled();
      case DioExceptionType.connectionError:
        return ApiException.network(error);
      case DioExceptionType.badResponse:
        final status = error.response?.statusCode ?? 0;
        if (status == 401) return ApiException.unauthorized();
        return ApiException(
          'Request failed ($status).',
          code: 'http_$status',
          statusCode: status,
          cause: error,
        );
      case DioExceptionType.badCertificate:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return ApiException.network(error);
    }
  }

  Future<ApiResponse> _handleResponse(Response<dynamic> response) async {
    final status = response.statusCode ?? 0;
    if (status >= 400) {
      throw ApiException(
        'Request failed ($status).',
        code: 'http_$status',
        statusCode: status,
      );
    }
    final parsed = ApiResponse.fromRaw(response.data);
    if (parsed.isAuthExpired) {
      await _handleAuthExpired(parsed.message);
    }
    return parsed.ensureSuccess();
  }

  Future<void> _handleAuthExpired(String serverMessage) async {
    if (_handlingAuthExpired) {
      throw ApiException(serverMessage, code: '-2');
    }
    _handlingAuthExpired = true;
    try {
      await config.authExpiredHandler?.call();
    } finally {
      _handlingAuthExpired = false;
    }
    throw ApiException(serverMessage, code: '-2');
  }

  String _url(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    return '${config.apiBaseUrl}${path.startsWith('/') ? path : '/$path'}';
  }

  String _randomDigits(int length) {
    return config.randomDigitsProvider?.call(length) ??
        ApiSignature.randomDigits(length);
  }
}
