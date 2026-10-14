/// Handa Peso 网关的混淆路由表。
///
/// 后端对外只暴露无意义的路径片段（见接口文档），这样协议细节不会散落在业务
/// 代码里，每个发布包也各自拥有一套路由词表。
abstract final class GatewayRoutes {
  // 鉴权与账号
  static const sendSmsCode = '/dropcloth/fishtailed';
  static const smsChannels = '/dropcloth/hastened';
  static const smsCodeLogin = '/dropcloth/checkreins';
  static const logout = '/dropcloth/unaccepted';
  static const deleteAccount = '/dropcloth/unstably';

  // 应用外壳与首页
  static const homePage = '/dropcloth/indulgences';
  static const personalCenter = '/dropcloth/affluents';
  static const appReport = '/dropcloth/chaffers';
  static const reCredit = '/dropcloth/stressor';
  static const dialog = '/dropcloth/counterchecked';
  static const bannerClickRecord = '/dropcloth/fluorochromes';
  static const getDeviceName = '/dropcloth/criminology';

  // 产品
  static const productApply = '/dropcloth/legongs';
  static const productDetail = '/dropcloth/shinning';
  static const productPush = '/dropcloth/outeating';

  // 认证 —— 身份、人脸、个人信息、职业、通讯录、银行卡
  static const basicPersonInfo = '/dropcloth/blockader';
  static const uploadImage = '/dropcloth/sikes';
  static const saveBasicInfo = '/dropcloth/polybutadiene';
  static const checkBasicPass = '/dropcloth/phellem';
  static const getFaceIdToken = '/dropcloth/postforming';
  static const advanceLog = '/dropcloth/commuters';
  static const faceIdTokenUpload = '/dropcloth/riposted';
  static const faceIdResultUpload = '/dropcloth/wresting';
  static const personalInfo = '/dropcloth/endoscopes';
  static const savePersonalInfo = '/dropcloth/walleyed';
  static const jobInfo = '/dropcloth/counteract';
  static const saveJobInfo = '/dropcloth/latchstrings';
  static const extInfoV2 = '/dropcloth/trollopy';
  static const saveExtInfoV2 = '/dropcloth/ranulas';
  static const cardInit = '/dropcloth/dependable';
  static const bindCard = '/dropcloth/tidewaters';
  static const cityInit = '/dropcloth/originator';
  static const userCardList = '/dropcloth/dullard';
  static const changeOrderAccount = '/dropcloth/circularise';
  static const retentionDialog = '/dropcloth/unchivalrous';
  static const trustDecisionReport = '/dropcloth/flaunter';

  // 订单
  static const orderList = '/dropcloth/pyranoside';
  static const userReloan = '/dropcloth/cotype';

  // 风控与埋点上报
  static const uploadLocation = '/dropcloth/farle';
  static const googleMarket = '/dropcloth/phalarope';
  static const buriedPoint = '/dropcloth/disgruntle';
  static const uploadDeviceInfo = '/dropcloth/unglove';
  static const uploadContacts = '/dropcloth/bioregional';
  static const uploadAppleToken = '/dropcloth/calipash';

  // 客服中心
  static const supportTicket = '/dropcloth/compacts';
  static const supportSupplement = '/dropcloth/whinger';
  static const supportTicketList = '/dropcloth/scurvier';
  static const faqList = '/dropcloth/crossbucks';
  static const supportPhone = '/dropcloth/predicating';
}
