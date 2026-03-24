import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ProfileService {
  final String baseUrl = 'http://10.0.2.2:8000';
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  ProfileService() {
    _dio.options.baseUrl = baseUrl;
  }

  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final token = await _storage.read(key: 'token');
      if (token == null) return null;

      final response = await _dio.get(
        '/users/me',
        options: Options(
          headers: {
            'Authorization': 'Bearer $token',
          },
        ),
      );
      return response.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await _storage.delete(key: 'token');
      }
      return null;
    }
  }
}
