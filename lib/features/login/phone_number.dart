final RegExp _nonDigits = RegExp(r'\D');

/// 菲律宾手机号（`+63` 前缀由界面固定展示，这里只管号码本体）。
///
/// 用户可能只填 10 位 `9xxxxxxxxx`，也可能整段粘贴带国家码或长途前缀的
/// `09xxxxxxxxx` / `639xxxxxxxxx`；三种写法指的是同一个号码，所以先统一成
/// 本国号码再判断，避免把同一串数字按三种长度各写一条规则。
class PhoneNumber {
  const PhoneNumber._(this.digits, this.national);

  /// 解析输入：空格、连字符、`+` 之类的非数字字符会被忽略。
  factory PhoneNumber.parse(String input) {
    final digits = input.replaceAll(_nonDigits, '');
    var national = digits;
    if (national.startsWith('63')) {
      national = national.substring(2);
    }
    if (national.startsWith('0')) {
      national = national.substring(1);
    }
    return PhoneNumber._(digits, national);
  }

  /// 输入里的纯数字，也就是提交给服务端的形态。
  final String digits;

  /// 去掉国家码与长途前缀后的本国号码。
  final String national;

  /// 是否是合法的菲律宾手机号：本国号码为 10 位且以 `9` 开头。
  bool get isMobile => national.length == 10 && national.startsWith('9');
}
