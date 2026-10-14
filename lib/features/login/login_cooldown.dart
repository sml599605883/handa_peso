import 'dart:async';

import 'package:get/get.dart';

/// 短信验证码的重发倒计时。
///
/// 按秒递减而不是按到期时间回算：应用切到后台时计时器本来就停了，回到前台
/// 让用户重新获取验证码即可，比「按时间戳追赶」更不容易出现负数或瞬间跳完。
class LoginCooldown {
  LoginCooldown({this.seconds = 60, this.tick = const Duration(seconds: 1)});

  /// 一轮倒计时的长度（秒）。
  final int seconds;

  /// 递减间隔，测试里可以调快。
  final Duration tick;

  /// 剩余秒数；0 表示可以重新获取验证码。
  final remaining = 0.obs;

  Timer? _ticker;

  bool get isRunning => remaining.value > 0;

  /// 重新开始一轮倒计时。
  void restart() {
    _ticker?.cancel();
    remaining.value = seconds;
    _ticker = Timer.periodic(tick, _onTick);
  }

  /// 停表（页面关闭时调用，避免留下未完成的 Timer）。
  void stop() {
    _ticker?.cancel();
    _ticker = null;
  }

  void _onTick(Timer timer) {
    if (remaining.value > 1) {
      remaining.value -= 1;
      return;
    }
    remaining.value = 0;
    timer.cancel();
    _ticker = null;
  }
}
