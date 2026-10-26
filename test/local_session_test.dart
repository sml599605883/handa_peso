import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/session/local_session.dart';

void main() {
  test('退出会话清掉账号状态，但保留手机号供登录页预填', () async {
    final session = LocalSession.memory();
    await session.writeSessionId('session-123');
    await session.writePhone('9171234567');
    await session.writeCertified(true);
    await session.writeIdentityCardType('SSS ID');

    await session.resetSession();

    // 登录态与账号事实都要清掉，避免上一账号的数据串到下一次登录。
    expect(await session.readSessionId(), isEmpty);
    expect(await session.readCertified(), isFalse);
    expect(await session.readIdentityCardType(), isEmpty);
    // 手机号是「上次登录的号码」，与登录态无关；退出后再次打开登录页要能回填。
    expect(await session.readPhone(), '9171234567');
  });
}
