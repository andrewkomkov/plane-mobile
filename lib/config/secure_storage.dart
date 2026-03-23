import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  static const _storage = FlutterSecureStorage();
  static const _keyApiKey = 'plane_api_key';
  static const _keyBaseUrl = 'plane_base_url';
  static const _keyWorkspaceSlug = 'plane_workspace_slug';

  static Future<void> saveApiKey(String apiKey) =>
      _storage.write(key: _keyApiKey, value: apiKey);

  static Future<String?> getApiKey() => _storage.read(key: _keyApiKey);

  static Future<void> saveBaseUrl(String url) =>
      _storage.write(key: _keyBaseUrl, value: url);

  static Future<String?> getBaseUrl() => _storage.read(key: _keyBaseUrl);

  static Future<void> saveWorkspaceSlug(String slug) =>
      _storage.write(key: _keyWorkspaceSlug, value: slug);

  static Future<String?> getWorkspaceSlug() =>
      _storage.read(key: _keyWorkspaceSlug);

  static Future<void> clear() => _storage.deleteAll();

  static Future<bool> isConfigured() async {
    final apiKey = await getApiKey();
    final baseUrl = await getBaseUrl();
    return apiKey != null &&
        apiKey.isNotEmpty &&
        baseUrl != null &&
        baseUrl.isNotEmpty;
  }
}
