import 'package:dio/dio.dart';
import '../config/api_client.dart';
import '../models/user.dart';

class AuthService {
  static Future<User> getCurrentUser() async {
    final dio = await ApiClient.getInstance();
    final response = await dio.get('/users/me/');
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
}
