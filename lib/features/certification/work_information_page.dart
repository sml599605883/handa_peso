import 'personal_information_models.dart';
import 'personal_information_page.dart';

/// 工作信息（设计稿 03-02）。
///
/// 复用个人信息页的动态字段、选择器、地址选择与提交状态，只把数据源、保存接口
/// 和场景切换为工作信息。独立入口便于路由和测试明确表达业务语义。
class WorkInformationPage extends PersonalInformationPage {
  const WorkInformationPage({
    super.key,
    super.apiClient,
    super.reporter,
    super.autoContinue,
  }) : super(formType: CertificationInformationKind.work);
}
