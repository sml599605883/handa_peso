/// Relative API paths.
///
/// Paths are grouped by feature so reviewers and analysts can trace a screen
/// back to its contract. No environment-specific host or secret belongs here.
abstract final class ApiEndpoints {
  // Authentication
  static const sendSmsCode = '/auth/sms/send';
  static const smsLogin = '/auth/sms/login';
  static const logout = '/auth/logout';
  static const deleteAccount = '/auth/account';

  // Account / profile
  static const profile = '/user/profile';
  static const updateProfile = '/user/profile/update';
  static const uploadContacts = '/user/contacts';
  static const uploadDevice = '/user/device';

  // Home & discovery
  static const homeFeed = '/home/feed';
  static const banners = '/home/banners';
  static const popup = '/home/popup';
  static const productDetail = '/product/detail';

  // Certification
  static const identityUpload = '/certification/identity';
  static const personalInfo = '/certification/personal';
  static const workInfo = '/certification/work';
  static const emergencyContacts = '/certification/contacts';
  static const bindAccount = '/certification/account';

  // Orders & repayment
  static const orderList = '/order/list';
  static const orderDetail = '/order/detail';
  static const loanConfirm = '/loan/confirm';
  static const loanSubmit = '/loan/submit';
  static const repaymentPlan = '/repayment/plan';

  // Support & content
  static const announcements = '/content/announcements';
  static const faq = '/content/faq';
  static const createTicket = '/support/ticket';

  // Telemetry
  static const event = '/telemetry/event';
}
