import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';
import '../network/api_config.dart';
import '../session/session_store.dart';

/// Container for the dependencies created before the first frame.
class AppDependencies {
  AppDependencies({required this.apiClient, required this.sessionStore});

  final ApiClient apiClient;
  final SessionStore sessionStore;
}

/// Composition root for the app.
///
/// Deliberately performs no network I/O: the first frame should never be gated
/// behind a slow or unreachable backend. Screens load their own data and render
/// loading/error/empty states.
abstract final class AppBootstrap {
  static Future<AppDependencies> initialize({
    SessionStore Function()? sessionStoreFactory,
    String? apiBaseUrl,
    String? webBaseUrl,
    String? signatureSecret,
  }) async {
    final sessionStore = sessionStoreFactory?.call() ??
        SessionStore(SharedPreferencesAsync());
    final config = ApiConfig(
      apiBaseUrl: apiBaseUrl,
      webBaseUrl: webBaseUrl,
      signatureSecret: signatureSecret,
      sessionStore: sessionStore,
    );
    return AppDependencies(
      apiClient: ApiClient(config),
      sessionStore: sessionStore,
    );
  }
}
