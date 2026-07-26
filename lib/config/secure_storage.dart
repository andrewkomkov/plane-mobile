import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  static const _keyApiKey = 'plane_api_key';
  static const _keyBaseUrl = 'plane_base_url';
  static const _keyWorkspaceSlug = 'plane_workspace_slug';
  static const _keyThemeMode = 'plane_theme_mode';

  // API key. The only credential the app stores: every sign-in path ends up
  // here, and the proxy turns it into a Plane session server-side. There were
  // also `plane_session_id` and `plane_auth_method` keys; the first was never
  // written by anything and the second was never read, so both are gone.
  // `clear()` still wipes them on old installs because it deletes everything.
  static Future<void> saveApiKey(String apiKey) =>
      _storage.write(key: _keyApiKey, value: apiKey);

  static Future<String?> getApiKey() => _storage.read(key: _keyApiKey);

  // Base URL
  static Future<void> saveBaseUrl(String url) =>
      _storage.write(key: _keyBaseUrl, value: url);

  static Future<String?> getBaseUrl() => _storage.read(key: _keyBaseUrl);

  // Workspace slug
  static Future<void> saveWorkspaceSlug(String slug) =>
      _storage.write(key: _keyWorkspaceSlug, value: slug);

  static Future<String?> getWorkspaceSlug() =>
      _storage.read(key: _keyWorkspaceSlug);

  // Theme
  static Future<void> saveThemeMode(String mode) =>
      _storage.write(key: _keyThemeMode, value: mode);

  static Future<String?> getThemeMode() => _storage.read(key: _keyThemeMode);

  static Future<void> clear() => _storage.deleteAll();

  /// Configured means a base URL and a token. The second arm of this used to
  /// accept a stored session id instead, which would have let the app past the
  /// setup screen with a credential no request could use.
  static Future<bool> isConfigured() async {
    final baseUrl = await getBaseUrl();
    if (baseUrl == null || baseUrl.isEmpty) return false;

    final apiKey = await getApiKey();
    return apiKey != null && apiKey.isNotEmpty;
  }
}
