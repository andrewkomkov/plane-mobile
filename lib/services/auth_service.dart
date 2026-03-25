import '../config/api_client.dart';
import '../models/user.dart';

class AuthService {
  static Future<User> getCurrentUser() async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/users/me/');
    return User.fromJson(response.data);
  }

  static Future<User> updateProfile(Map<String, dynamic> data) async {
    final dio = await ApiClient.getInstance();
    final response = await dio.patch('/users/me/', data: data);
    return User.fromJson(response.data);
  }

  static Future<bool> testConnection(String baseUrl, String apiKey) async {
    try {
      final dio = await ApiClient.createTemporary(baseUrl, apiKey);
      final response = await dio.get('/users/me/');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Test connection using a session cookie against the internal API.
  static Future<bool> testSessionConnection(
      String baseUrl, String sessionId) async {
    try {
      final dio = ApiClient.createWithSession(baseUrl, sessionId);
      final response = await dio.get('/users/me/');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Create an API token using a session cookie.
  /// Returns the token string on success, null on failure.
  static Future<String?> createApiToken(
      String baseUrl, String sessionId) async {
    try {
      final dio = ApiClient.createWithSession(baseUrl, sessionId);
      final response = await dio.post('/users/api-tokens/', data: {
        'label': 'Plane Mobile App',
        'description': 'Auto-created by Plane mobile app',
      });
      if (response.statusCode == 201 || response.statusCode == 200) {
        return response.data['token'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Fetch workspaces using a session cookie.
  static Future<List<Map<String, dynamic>>> fetchWorkspaces(
      String baseUrl, String sessionId) async {
    try {
      final dio = ApiClient.createWithSession(baseUrl, sessionId);
      final response = await dio.get('/users/me/workspaces/');
      if (response.statusCode == 200) {
        final data = response.data;
        if (data is List) {
          return data.cast<Map<String, dynamic>>();
        }
        if (data is Map && data.containsKey('results')) {
          return (data['results'] as List).cast<Map<String, dynamic>>();
        }
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
