import 'dart:io';
import 'dart:convert';
import 'package:hive/hive.dart';
import 'package:hashtagg/core/network/stories_api_repository.dart';

class StoryPublisher {
  final StoriesApiRepository _storiesApi = StoriesApiRepository();

  Future<Map<String, dynamic>> publishStory({
    required String filePath,
    required bool isPhoto,
    required int cityId,
    required int regionId,
    required int countryId,
    required int catId,
    String link = 'profile',
    int adId = 0,
  }) async {
    try {
      // Получаем данные авторизации
      final box = await Hive.openBox('user');
      final token = box.get('auth_token') as String?;
      
      // ВСЕГДА берем userId только из user['id'], игнорируем user_id
      final userData = box.get('user');
      int? userId;
      if (userData is Map) {
        userId = userData['id'];
      }

      print('🔵 [StoryPublisher] Token: $token');
      print('🔵 [StoryPublisher] UserId: $userId');
      print('🔵 [StoryPublisher] Box keys: ${box.keys.toList()}');

      if (token == null || userId == null) {
        print('🔴 [StoryPublisher] Auth data missing - token: $token, userId: $userId');
        return {'status': false, 'error': 'Не авторизован'};
      }

      print('🔵 [StoryPublisher] Publishing story - isPhoto: $isPhoto');
      print('🔵 [StoryPublisher] File path: $filePath');

      // Читаем файл и конвертируем в base64
      final file = File(filePath);
      if (!await file.exists()) {
        print('🔴 [StoryPublisher] File does not exist: $filePath');
        return {'status': false, 'error': 'Файл не найден'};
      }

      final fileSize = await file.length();
      print('🔵 [StoryPublisher] File size: ${fileSize} bytes (${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB)');

      final bytes = await file.readAsBytes();
      print('🔵 [StoryPublisher] Read ${bytes.length} bytes from file');

      final base64String = base64Encode(bytes);
      print('🔵 [StoryPublisher] Base64 length: ${base64String.length} chars');
      print('🔵 [StoryPublisher] Base64 preview: ${base64String.substring(0, base64String.length > 100 ? 100 : base64String.length)}...');

      // Загружаем файл в temp
      print('🔵 [StoryPublisher] Uploading to temp - userId: $userId, token length: ${token.length}');
      final uploadResult = await _storiesApi.uploadToTemp(
        userId: userId,
        token: token,
        fileBase64: base64String,
      );

      if (uploadResult['status'] != true) {
        return uploadResult;
      }

      final fileName = uploadResult['data']['name'];
      print('✅ [StoryPublisher] File uploaded to temp: $fileName');

      // Публикуем сторис
      if (isPhoto) {
        final result = await _storiesApi.uploadImage(
          userId: userId,
          token: token,
          filePath: filePath,
          fileName: fileName,
          cityId: cityId,
          regionId: regionId,
          countryId: countryId,
          catId: catId,
          link: link,
          id: adId,
        );

        return result;
      } else {
        // Для видео нужна длительность
        final result = await _storiesApi.uploadVideo(
          userId: userId,
          token: token,
          fileBase64: base64String,
          fileName: fileName.replaceAll('.webp', ''),
          videoDuration: 5000, // TODO: получить реальную длительность
          cityId: cityId,
          regionId: regionId,
          countryId: countryId,
          catId: catId,
          link: link,
          id: adId,
        );

        return result;
      }
    } catch (e) {
      print('🔴 [StoryPublisher] Error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }
}
