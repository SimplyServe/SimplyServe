import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  final String baseUrl = 'http://localhost:8000';
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  AuthService() {
    _dio.options.baseUrl = baseUrl;
  }

  Future<String?> login(String email, String password) async {
    try {
      final response = await _dio.post(
        '/token',
        data: {
          'username': email,
          'password': password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );

      final token = response.data['access_token'];
      await _storage.write(key: 'token', value: token);
      return null;
    } on DioException catch (e) {
      if (e.response != null) {
        return e.response?.data['detail'] ?? 'Login failed';
      }
      return 'Connection error';
    }
  }

  Future<String?> register(String email, String password) async {
    try {
      await _dio.post(
        '/register',
        data: {
          'email': email,
          'password': password,
        },
      );
      return null;
    } on DioException catch (e) {
      if (e.response != null) {
        return e.response?.data['detail'] ?? 'Registration failed';
      }
      return 'Connection error';
    }
  }

  Future<void> logout() async {
    await _storage.delete(key: 'token');
  }

  Future<String?> getToken() async {
    return await _storage.read(key: 'token');
  }
}
