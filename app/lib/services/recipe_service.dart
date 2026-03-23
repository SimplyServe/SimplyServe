import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:simplyserve/recipe_page.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http_parser/http_parser.dart';

class RecipeService {
  final String baseUrl = 'http://10.0.2.2:8000';
  final Dio _dio = Dio();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  RecipeService() {
    _dio.options.baseUrl = baseUrl;
  }

  Future<Options> _getAuthOptions() async {
    final token = await _storage.read(key: 'token');
    return Options(headers: {
      'Authorization': 'Bearer $token',
    });
  }

  Future<List<RecipeModel>> getRecipes() async {
    try {
      final response = await _dio.get('/recipes', options: await _getAuthOptions());
      final List<dynamic> data = response.data;
      return data.map((json) => _fromJson(json)).toList();
    } catch (e) {
      print('Error fetching recipes: $e');
      return [];
    }
  }

  Future<RecipeModel?> createRecipe(RecipeModel recipe, XFile? imageFile) async {
    try {
      final token = await _storage.read(key: 'token');
      final Map<String, dynamic> dataMap = {
        'title': recipe.title,
        'summary': recipe.summary,
        'prep_time': recipe.prepTime,
        'cook_time': recipe.cookTime,
        'total_time': recipe.totalTime,
        'servings': recipe.servings,
        'difficulty': recipe.difficulty,
        'tags_json': jsonEncode(recipe.tags),
        'ingredients_json': jsonEncode(recipe.ingredients),
        'steps_json': jsonEncode(recipe.steps),
      };

      if (imageFile != null) {
        String fileName = imageFile.name;
        final bytes = await imageFile.readAsBytes();
        dataMap['image'] = MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType("image", fileName.split('.').last),
        );
      }

      final formData = FormData.fromMap(dataMap);

      final response = await _dio.post(
        '/recipes',
        data: formData,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      return _fromJson(response.data);
    } catch (e) {
      print('Error creating recipe: $e');
      return null;
    }
  }

  Future<bool> deleteRecipe(int id) async {
     try {
       await _dio.delete('/recipes/$id', options: await _getAuthOptions());
       return true;
     } catch (e) {
       print('Error deleting recipe: $e');
       return false;
     }
  }

  RecipeModel _fromJson(Map<String, dynamic> json) {
    return RecipeModel(
      title: json['title'] ?? '',
      summary: json['summary'] ?? '',
      imageUrl: json['image_url'] ?? 'https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=1200&q=80',
      prepTime: json['prep_time'] ?? '',
      cookTime: json['cook_time'] ?? '',
      totalTime: json['total_time'] ?? '',
      servings: json['servings'] ?? 1,
      difficulty: json['difficulty'] ?? 'Medium',
      tags: List<String>.from(json['tags'] ?? []),
      ingredients: List<String>.from(json['ingredients'] ?? []),
      steps: List<String>.from(json['steps'] ?? []),
      nutrition: json['nutrition'] != null
          ? NutritionInfo(
              calories: json['nutrition']['calories'] ?? 0,
              protein: json['nutrition']['protein'] ?? '0g',
              carbs: json['nutrition']['carbs'] ?? '0g',
              fats: json['nutrition']['fats'] ?? '0g',
            )
          : const NutritionInfo(calories: 0, protein: '0g', carbs: '0g', fats: '0g'),
      id: json['id'],
    );
  }
}
