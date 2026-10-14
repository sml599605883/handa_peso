import 'package:flutter/widgets.dart';

/// 本项目的命名路由都来自 Get 的 `GetPageRoute`，它是 `ModalRoute` 的子类，
/// 因此这里把观察者的泛型参数固定为 `ModalRoute<dynamic>`。
typedef AppRouteObserver = RouteObserver<ModalRoute<dynamic>>;

/// 全应用共用的路由观察者。
///
/// 页面混入 `RouteAware` 后订阅它，就能在被上层路由覆盖、之后重新露出时
/// 收到回调并刷新自己的数据。
final AppRouteObserver appRouteObserver = AppRouteObserver();
