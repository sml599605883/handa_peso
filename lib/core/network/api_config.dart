import 'package:shared_preferences/shared_preferences.dart';

import '../session/session_store.dart';

/// Runtime configuration for the API client.
///
/// Hosts and secrets are injected at build time via `--dart-define` so that no
/// environment URL or signing key is ever committed to the repository.
class ApiConfig {
  ApiConfig({
    String? apiBaseUrl,
    String? webBaseUrl,
    SessionStore? sessionStore,
    this.signatureSecret,
    this.timestampProvider,
  })  : apiBaseUrl = apiBaseUrl ?? _defaultApiBaseUrl,
        webBaseUrl = webBaseUrl ?? _defaultWebBaseUrl,
        sessionStore = sessionStore ?? SessionStore(SharedPreferencesAsync());

  static const _defaultApiBaseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.handapeso.example');
  static const _defaultWebBaseUrl =
      String.fromEnvironment('WEB_BASE_URL', defaultValue: 'https://www.handapeso.example');

  final String apiBaseUrl;
  final String webBaseUrl;
  final String? signatureSecret;
  final int Function()? timestampProvider;
  final SessionStore sessionStore;

  int timestamp() => (timestampProvider ?? _nowMillis)();

  static int _nowMillis() => DateTime.now().millisecondsSinceEpoch;
}
