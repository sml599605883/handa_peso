import 'dart:convert';

import 'gateway_reply.dart';
import 'gateway_routes.dart';
import 'gateway_transport.dart';

/// 强类型网关接口。
///
/// 每个方法只声明三件事：发到哪条路由、带哪些业务参数、哪些键是混淆字段。
/// 签名、超时、错误归一化与信封解包都由 [GatewayTransport] 统一处理，因此这
/// 一层保持扁平。
///
/// 参数名是给 Dart 侧看的，请求里的键一律以接口文档为准。
class GatewayClient extends GatewayTransport {
  GatewayClient(super.settings, {super.dio});

  /// 为 H5 请求生成同一套已签名公有参数。
  ///
  /// 这里不发送请求，只复用网关签名器，避免网页端自行持有签名密钥。
  Future<Map<String, dynamic>> publicParametersFor(String path) =>
      signer.signedQuery(path: path);

  // ---------------------------------------------------------------------------
  // 鉴权与账号
  // ---------------------------------------------------------------------------

  /// 发送短信验证码。
  Future<GatewayReply> requestSmsCode({
    required String phone,
    String channel = 'sms',
  }) {
    return write(
      GatewayRoutes.sendSmsCode,
      body: <String, dynamic>{'fishtailed': phone, 'checkreins': channel},
      noise: const <String>['hastened'],
    );
  }

  /// 查询可用的短信通道。
  Future<GatewayReply> fetchSmsChannels({required String phone}) {
    return write(
      GatewayRoutes.smsChannels,
      body: <String, dynamic>{'fishtailed': phone},
      noise: const <String>['affluents', 'chaffers'],
    );
  }

  /// 用手机号 + 验证码登录；成功后载荷里带会话标识。
  Future<GatewayReply> signInWithSmsCode({
    required String phone,
    required String code,
  }) {
    return write(
      GatewayRoutes.smsCodeLogin,
      body: <String, dynamic>{'criminology': phone, 'legongs': code},
      noise: const <String>['affluents', 'chaffers'],
    );
  }

  /// 退出登录（服务端注销当前会话）。
  Future<GatewayReply> signOut() {
    return read(
      GatewayRoutes.logout,
      noise: const <String>['phellem', 'postforming'],
    );
  }

  /// 注销账号。
  Future<GatewayReply> closeAccount() {
    return read(
      GatewayRoutes.deleteAccount,
      noise: const <String>['commuters'],
    );
  }

  // ---------------------------------------------------------------------------
  // 应用外壳与首页
  // ---------------------------------------------------------------------------

  /// 首页信息流（Banner、产品、公告）。
  Future<GatewayReply> fetchHomeOverview() {
    return read(
      GatewayRoutes.homePage,
      noise: const <String>['riposted', 'wresting'],
    );
  }

  /// 个人中心头部信息。
  Future<GatewayReply> fetchMineOverview() {
    return read(
      GatewayRoutes.personalCenter,
      noise: const <String>['uncloudedly'],
    );
  }

  /// app 上报。[reportType] 为 `1` 表示动态域名切换，`2` 表示流程埋点。
  Future<GatewayReply> submitAppReport({
    required String reportType,
    required String reportPayload,
  }) {
    return write(
      GatewayRoutes.appReport,
      body: <String, dynamic>{'khedas': reportType, 'inanest': reportPayload},
      noise: const <String>['treasuring'],
    );
  }

  /// 换址成功后上报本次切换过程的日志；失败由调用方兜底。
  Future<void> reportEndpointSwitch(String payload) {
    return submitAppReport(reportType: '1', reportPayload: payload);
  }

  /// 重新授信入口的展示信息。
  Future<GatewayReply> fetchRecreditInfo() {
    return read(GatewayRoutes.reCredit, noise: const <String>['contemplate']);
  }

  /// 弹窗配置。[scene] 是接口文档定义的分镜编号。
  Future<GatewayReply> fetchDialogConfig({required int scene}) {
    return read(
      GatewayRoutes.dialog,
      query: <String, dynamic>{'disobliges': scene},
    );
  }

  /// 记录一次 Banner 点击。
  Future<GatewayReply> recordBannerClick({required String bannerId}) {
    return write(
      GatewayRoutes.bannerClickRecord,
      body: <String, dynamic>{'interreligious': bannerId},
      noise: const <String>['hearten'],
    );
  }

  /// 用硬件标识（如 `iPhone15,2`）换取可读设备名。
  Future<GatewayReply> lookupDeviceName({required String modelCode}) {
    return write(
      GatewayRoutes.getDeviceName,
      body: <String, dynamic>{'definitively': modelCode},
      noise: const <String>['hearten'],
    );
  }

  // ---------------------------------------------------------------------------
  // 产品
  // ---------------------------------------------------------------------------

  /// 进入产品申请流程。
  ///
  /// 文档「点击申请」里的 `jumpiest` / `plundered` / `caesium`（模块id、位置、
  /// 子模块id，固定值 1001/1000/1000）都标注了「已弃用」，本端不再发送。
  Future<GatewayReply> startProductApplication({
    required String productId,
    String source = '0',
  }) {
    return write(
      GatewayRoutes.productApply,
      body: <String, dynamic>{'cotype': productId, 'efflorescence': source},
      noise: const <String>['strikes', 'somans'],
    );
  }

  /// 产品详情。
  Future<GatewayReply> fetchProductDetail({required String productId}) {
    return write(
      GatewayRoutes.productDetail,
      body: <String, dynamic>{'cotype': productId},
      noise: const <String>['suffocation', 'undraping', 'anecdotes'],
    );
  }

  /// 下单。
  Future<GatewayReply> pushOrder({
    required String orderNo,
    required String amount,
    required String term,
    required String termUnit,
  }) {
    return write(
      GatewayRoutes.productPush,
      body: <String, dynamic>{
        'eelworm': orderNo,
        'luciferins': amount,
        'splashiest': term,
        'curb': termUnit,
      },
      noise: const <String>[
        'floggers',
        'sententia',
        'colonics',
        'scorekeepers',
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 认证：身份、人脸、个人信息、职业、通讯录、银行卡
  // ---------------------------------------------------------------------------

  /// 身份认证（第一项）的用户信息。
  Future<GatewayReply> fetchBasicProfile({required String productId}) {
    return read(
      GatewayRoutes.basicPersonInfo,
      query: <String, dynamic>{'cotype': productId},
      noise: const <String>['prebendaries'],
    );
  }

  /// 上传证件/人脸照片。[field] 是服务端约定的文件字段名。
  Future<GatewayReply> uploadEvidence({
    required String filePath,
    String field = 'attach',
    Map<String, dynamic> body = const <String, dynamic>{},
  }) {
    return multipart(
      GatewayRoutes.uploadImage,
      filePath: filePath,
      field: field,
      body: body,
    );
  }

  /// 保存身份证信息。
  ///
  /// 参数名按接口文档「保存用户身份证信息（第一项）」：`definitively` 姓名、
  /// `optically` 证件号、`gleeking` 出生日期（`d-m-Y`）、`trollopy` 11 证件正面、
  /// `scarriest` 证件类型；`wrencher` 是文档登记的混淆字段。
  Future<GatewayReply> saveBasicProfile({
    required String name,
    required String idNumber,
    required String birthday,
    required String cardType,
    String tileType = '11',
  }) {
    return write(
      GatewayRoutes.saveBasicInfo,
      body: <String, dynamic>{
        'definitively': name,
        'optically': idNumber,
        'gleeking': birthday,
        'trollopy': tileType,
        'scarriest': cardType,
      },
      noise: const <String>['wrencher'],
    );
  }

  /// 检查基础信息是否通过。
  Future<GatewayReply> verifyBasicProfile({required String productId}) {
    return write(
      GatewayRoutes.checkBasicPass,
      body: <String, dynamic>{'cotype': productId},
      noise: const <String>['nonperformer', 'gushes'],
    );
  }

  /// 获取活体检测凭据。[livenessType] 为 `1` 表示绑卡前的活体校验。
  Future<GatewayReply> fetchLivenessToken({
    required String orderNo,
    required String livenessType,
  }) {
    return write(
      GatewayRoutes.getFaceIdToken,
      body: <String, dynamic>{'eelworm': orderNo, 'trollopy': livenessType},
      noise: const <String>['dis', 'popularizes'],
    );
  }

  /// 认证流程的步骤埋点。
  Future<GatewayReply> reportStepLog({required Map<String, dynamic> body}) {
    return write(GatewayRoutes.advanceLog, body: body);
  }

  /// 回传活体凭据。
  Future<GatewayReply> submitLivenessToken({
    required Map<String, dynamic> body,
  }) {
    return write(GatewayRoutes.faceIdTokenUpload, body: body);
  }

  /// 回传活体检测结果。
  Future<GatewayReply> submitLivenessResult({
    required Map<String, dynamic> body,
  }) {
    return write(GatewayRoutes.faceIdResultUpload, body: body);
  }

  /// 个人信息（第二项）。
  Future<GatewayReply> fetchPersonalProfile({required String productId}) {
    return write(
      GatewayRoutes.personalInfo,
      body: <String, dynamic>{'cotype': productId},
      noise: const <String>['bondstone'],
    );
  }

  /// 保存个人信息（第二项）。
  Future<GatewayReply> submitPersonalProfile({
    required Map<String, dynamic> body,
  }) {
    return write(GatewayRoutes.savePersonalInfo, body: body);
  }

  /// 工作信息（第三项）。
  Future<GatewayReply> fetchJobProfile({required String productId}) {
    return read(
      GatewayRoutes.jobInfo,
      query: <String, dynamic>{'cotype': productId},
      noise: const <String>['bondstone'],
    );
  }

  /// 保存工作信息（第三项）。
  Future<GatewayReply> submitJobProfile({required Map<String, dynamic> body}) {
    return write(
      GatewayRoutes.saveJobInfo,
      body: body,
      noise: const <String>['salpinges', 'determiner', 'fertilizers'],
    );
  }

  /// 联系人信息（第四项）。
  Future<GatewayReply> fetchContactProfile({required String productId}) {
    return read(
      GatewayRoutes.extInfoV2,
      query: <String, dynamic>{'cotype': productId},
      noise: const <String>['tatty'],
    );
  }

  /// 保存联系人信息（第四项）。
  Future<GatewayReply> submitContactProfile({
    required String productId,
    required List<Map<String, dynamic>> contacts,
  }) {
    return write(
      GatewayRoutes.saveExtInfoV2,
      body: <String, dynamic>{
        'cotype': productId,
        'indulgences': jsonEncode(contacts),
      },
      noise: const <String>['monumentalizes'],
    );
  }

  /// 绑卡页初始化数据（城市、银行列表等）。
  Future<GatewayReply> fetchCardForm({required String productId}) {
    return read(
      GatewayRoutes.cardInit,
      query: <String, dynamic>{'cotype': productId},
      noise: const <String>['pastorales', 'replunge'],
    );
  }

  /// 提交绑卡。
  Future<GatewayReply> submitCardBinding({required Map<String, dynamic> body}) {
    return write(
      GatewayRoutes.bindCard,
      body: body,
      noise: const <String>['fatheadedly'],
    );
  }

  /// 地址初始化。
  Future<GatewayReply> fetchCityOptions() => read(GatewayRoutes.cityInit);

  /// 已绑定的银行卡列表。
  Future<GatewayReply> fetchBoundCards({required String productId}) {
    return write(
      GatewayRoutes.userCardList,
      body: <String, dynamic>{'cotype': productId},
      noise: const <String>['tetracids', 'oozed'],
    );
  }

  /// 更换放款银行卡。
  Future<GatewayReply> switchPayoutCard({
    required String orderNo,
    required String cardId,
  }) {
    return write(
      GatewayRoutes.changeOrderAccount,
      body: <String, dynamic>{'eelworm': orderNo, 'eyeglasses': cardId},
      noise: const <String>['guaiocums'],
    );
  }

  /// 挽留弹窗。
  Future<GatewayReply> fetchRetentionPrompt({
    required String scene,
    required String productId,
  }) {
    return write(
      GatewayRoutes.retentionDialog,
      body: <String, dynamic>{'ulterior': scene, 'knife': productId},
      noise: const <String>['chauvinistic'],
    );
  }

  /// 同盾活体结果上报：只要有响应就上报一次。
  Future<GatewayReply> reportLivenessDecision({
    required String livenessId,
    required String requestId,
    required String resultCode,
    required String resultJson,
  }) {
    return write(
      GatewayRoutes.trustDecisionReport,
      body: <String, dynamic>{
        'ediblenesses': livenessId,
        'eggplants': requestId,
        'beet': resultCode,
        'murdering': resultJson,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // 订单
  // ---------------------------------------------------------------------------

  /// 订单列表。[status] 见接口文档的订单状态映射。
  Future<GatewayReply> fetchOrders({
    required String status,
    String page = '1',
    String pageSize = '50',
  }) {
    return write(
      GatewayRoutes.orderList,
      body: <String, dynamic>{
        'corequisites': status,
        'girlies': page,
        'uncompromisable': pageSize,
      },
    );
  }

  /// 用历史订单重新下单（原卡重试）。
  ///
  /// 契约按接口文档《原卡重试确认订单》：`POST /dropcloth/cotype`，表单里只有
  /// 一个必填参数 `redecorates`（订单号）；`chattinesses` 在文档里不存在，
  /// `api_doc_get_map` 的字段映射同样是 `orderNo → redecorates`。
  ///
  /// 文档没有要求该接口对请求体做 AES 加密（全部 78 篇文档里只有
  /// 《设备信息上报详细信息 [上报数据需要加密]》标了加密，且加密的是
  /// `indulgences` 整包）。因此这里维持表单明文：客户端单方面加密会让服务端
  /// 拿到不可解析的订单号，加密方案需要后端先给出字段名与密钥约定。
  Future<GatewayReply> reorderExistingLoan({required String orderNo}) {
    return write(
      GatewayRoutes.userReloan,
      body: <String, dynamic>{'redecorates': orderNo},
    );
  }

  // ---------------------------------------------------------------------------
  // 风控与埋点上报
  // ---------------------------------------------------------------------------

  /// 上报定位快照。定位接口的 `chads` / `elastases` 是文档登记过的混淆字段。
  Future<GatewayReply> reportLocation({required Map<String, dynamic> body}) {
    return write(
      GatewayRoutes.uploadLocation,
      body: body,
      noise: const <String>['chads', 'elastases'],
    );
  }

  /// google_market 上报：渠道归因用的设备标识。
  Future<GatewayReply> reportInstallSource({
    required String deviceId,
    required String advertisingId,
  }) {
    return write(
      GatewayRoutes.googleMarket,
      body: <String, dynamic>{
        'tunesmith': deviceId,
        'colickiest': advertisingId,
      },
      noise: const <String>['nevoid'],
    );
  }

  /// 上报风控埋点。
  Future<GatewayReply> reportEvent({required Map<String, dynamic> body}) {
    return write(
      GatewayRoutes.buriedPoint,
      body: body,
      noise: const <String>['pastorales'],
    );
  }

  /// 设备详情上报。[encryptedPayload] 必须先用 `cipher` 加密，网关只收密文。
  Future<GatewayReply> reportDeviceProfile({required String encryptedPayload}) {
    return sealed(GatewayRoutes.uploadDeviceInfo, value: encryptedPayload);
  }

  /// 上报 Apple 推送 token。
  Future<GatewayReply> reportPushToken({required String token}) {
    return write(
      GatewayRoutes.uploadAppleToken,
      body: <String, dynamic>{'bettered': token},
    );
  }

  // ---------------------------------------------------------------------------
  // 客服中心
  // ---------------------------------------------------------------------------

  /// 提交客服问题。
  Future<GatewayReply> openSupportTicket({
    required String description,
    String? subjectType,
    String? subCategory,
    String? imageUrl,
    String? orderNo,
  }) {
    return write(
      GatewayRoutes.supportTicket,
      body: <String, dynamic>{
        'skells': ?subjectType,
        'vespid': ?subCategory,
        'grapier': description,
        'filthily': ?imageUrl,
        'redecorates': ?orderNo,
      },
      noise: const <String>['hidalgos'],
    );
  }

  /// 客服问题列表。
  Future<GatewayReply> fetchSupportTickets() {
    return write(
      GatewayRoutes.supportTicketList,
      noise: const <String>['undraping', 'riposted'],
    );
  }

  /// 补充客服问题。
  Future<GatewayReply> appendSupportMessage({
    required String ticketId,
    required String description,
    String? imageUrl,
  }) {
    return write(
      GatewayRoutes.supportSupplement,
      body: <String, dynamic>{
        'polemists': ticketId,
        'grapier': description,
        'filthily': ?imageUrl,
      },
    );
  }

  /// 问题列表 / FAQ。
  Future<GatewayReply> fetchFaqs({
    String? actionType,
    String? ticketId,
    String? orderNo,
  }) {
    return read(
      GatewayRoutes.faqList,
      query: <String, dynamic>{
        'tsaddik': ?actionType,
        'quagmire': ?ticketId,
        'redecorates': ?orderNo,
      },
      noise: const <String>['witnessed'],
    );
  }

  /// 客服电话。
  Future<GatewayReply> fetchSupportPhone() {
    return read(
      GatewayRoutes.supportPhone,
      noise: const <String>['treasuring'],
    );
  }
}
