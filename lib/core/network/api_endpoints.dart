/// Obfuscated route table for the Handa Peso gateway.
///
/// The backend exposes meaning-free path segments (see the interface docs),
/// which keeps protocol details out of feature code and gives each shipping
/// binary its own route vocabulary.
abstract final class ApiEndpoints {
  // Auth & account
  static const sendSmsCode = '/dropcloth/fishtailed';
  static const smsChannels = '/dropcloth/hastened';
  static const smsCodeLogin = '/dropcloth/checkreins';
  static const logout = '/dropcloth/unaccepted';
  static const deleteAccount = '/dropcloth/unstably';

  // App shell & home
  static const homePage = '/dropcloth/indulgences';
  static const personalCenter = '/dropcloth/affluents';
  static const appReport = '/dropcloth/chaffers';
  static const reCredit = '/dropcloth/stressor';
  static const dialog = '/dropcloth/counterchecked';
  static const bannerClickRecord = '/dropcloth/fluorochromes';
  static const getDeviceName = '/dropcloth/criminology';

  // Product
  static const productApply = '/dropcloth/legongs';
  static const productDetail = '/dropcloth/shinning';
  static const productPush = '/dropcloth/outeating';

  // Certification — identity, face, personal, job, contacts, card
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

  // Orders
  static const orderList = '/dropcloth/pyranoside';
  static const userReloan = '/dropcloth/cotype';

  // Risk & telemetry reporting
  static const uploadLocation = '/dropcloth/farle';
  static const googleMarket = '/dropcloth/phalarope';
  static const buriedPoint = '/dropcloth/disgruntle';
  static const uploadDeviceInfo = '/dropcloth/unglove';
  static const uploadContacts = '/dropcloth/bioregional';
  static const uploadAppleToken = '/dropcloth/calipash';

  // Support centre
  static const supportTicket = '/dropcloth/compacts';
  static const supportSupplement = '/dropcloth/whinger';
  static const supportTicketList = '/dropcloth/scurvier';
  static const faqList = '/dropcloth/crossbucks';
  static const supportPhone = '/dropcloth/predicating';
}
