import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ProfileService {
  final String baseUrl = dotenv.env['BASE_URL'] ?? 'http://localhost:8000';
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

  Future<void> updateUserName(String name) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final response = await _dio.put(
      '/users/me',
      data: {'name': name},
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to update name');
    }
  }

  Future<String> uploadProfileImage(String filePath) async {
    final token = await _storage.read(key: 'token');
    if (token == null) throw Exception('Not authenticated');

    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
    });

    final response = await _dio.post(
      '/users/me/avatar',
      data: formData,
      options: Options(
        headers: {
          'Authorization': 'Bearer $token',
        },
      ),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to upload image');
    }

    return response.data['profile_image_url'] as String;
  }
}
