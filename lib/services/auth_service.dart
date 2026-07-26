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

  /// Check that a base URL and token the user just typed in actually work.
  ///
  /// Runs before anything is stored, so it goes at the external `/api/v1`
  /// surface via [ApiClient.createTemporary] rather than the proxy — see the
  /// note there for why that is the one legitimate v1 call left in the app.
  static Future<bool> testConnection(String baseUrl, String apiKey) async {
    try {
      final dio = await ApiClient.createTemporary(baseUrl, apiKey);
      final response = await dio.get('/users/me/');
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
