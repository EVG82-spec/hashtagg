// shared/infrastructure/services/auth_cleanup_service.dart
// Jb 05/09
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthCleanupService {
  static const String _tag = '🔴 [AuthCleanup]';

  /// Полная очистка всех данных авторизации
  static Future<void> clearAllAuthData({bool logDetails = true}) async {
    if (logDetails) {
      debugPrint(
        '$_tag ========== НАЧАЛО ОЧИСТКИ ДАННЫХ АВТОРИЗАЦИИ ==========',
      );
    }

    try {
      // 1. Очищаем Hive
      final box = Hive.box('user');

      // Сохраняем старые значения для логирования
      final oldToken = box.get('auth_token') as String?;
      final oldUser = box.get('user');
      final oldIsOAuth = box.get('is_oauth') as bool?;

      if (logDetails) {
        debugPrint('$_tag 📦 ДО очистки Hive:');
        debugPrint(
          '$_tag   - auth_token: ${oldToken != null ? _maskToken(oldToken) : 'NULL'}',
        );
        debugPrint(
          '$_tag   - user: ${oldUser != null ? 'Есть данные' : 'NULL'}',
        );
        debugPrint('$_tag   - is_oauth: $oldIsOAuth');
      }

      // Удаляем все ключи
      await box.delete('auth_token');
      await box.delete('user');
      await box.delete('is_oauth');
      await box.delete('user_id'); // на всякий случай

      // Проверяем, что удалилось
      final afterToken = box.get('auth_token');
      final afterUser = box.get('user');

      if (logDetails) {
        debugPrint('$_tag 📦 ПОСЛЕ очистки Hive:');
        debugPrint(
          '$_tag   - auth_token: ${afterToken != null ? '❌ НЕ УДАЛИЛСЯ!' : '✅ УДАЛЕН'}',
        );
        debugPrint(
          '$_tag   - user: ${afterUser != null ? '❌ НЕ УДАЛИЛСЯ!' : '✅ УДАЛЕН'}',
        );
      }

      // 2. Очищаем SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Сохраняем старые значения для логирования
      final oldPrefsToken = prefs.getString('auth_token');
      final oldPrefsUserId = prefs.getInt('user_id');
      final oldPrefsIsOAuth = prefs.getBool('is_oauth');

      if (logDetails) {
        debugPrint('$_tag 💾 ДО очистки SharedPreferences:');
        debugPrint(
          '$_tag   - auth_token: ${oldPrefsToken != null ? _maskToken(oldPrefsToken) : 'NULL'}',
        );
        debugPrint('$_tag   - user_id: $oldPrefsUserId');
        debugPrint('$_tag   - is_oauth: $oldPrefsIsOAuth');
      }

      // Удаляем все ключи
      await prefs.remove('auth_token');
      await prefs.remove('user_id');
      await prefs.remove('is_oauth');

      // Проверяем, что удалилось
      final afterPrefsToken = prefs.getString('auth_token');
      final afterPrefsUserId = prefs.getInt('user_id');

      if (logDetails) {
        debugPrint('$_tag 💾 ПОСЛЕ очистки SharedPreferences:');
        debugPrint(
          '$_tag   - auth_token: ${afterPrefsToken != null ? '❌ НЕ УДАЛИЛСЯ!' : '✅ УДАЛЕН'}',
        );
        debugPrint(
          '$_tag   - user_id: ${afterPrefsUserId != null ? '❌ НЕ УДАЛИЛСЯ!' : '✅ УДАЛЕН'}',
        );
      }

      if (logDetails) {
        debugPrint('$_tag ✅ ОЧИСТКА ЗАВЕРШЕНА УСПЕШНО');
        debugPrint('$_tag ========== КОНЕЦ ОЧИСТКИ ==========');
      }
    } catch (e, stackTrace) {
      debugPrint('$_tag ❌ ОШИБКА при очистке: $e');
      debugPrint('$_tag 📚 StackTrace: $stackTrace');
      rethrow;
    }
  }

  /// Проверка текущего состояния хранилищ
  static Future<void> checkAuthStorage() async {
    debugPrint('$_tag ========== ПРОВЕРКА ХРАНИЛИЩ ==========');

    try {
      // Проверяем Hive
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final user = box.get('user');
      final isOAuth = box.get('is_oauth') as bool?;

      debugPrint('$_tag 📦 Hive:');
      debugPrint(
        '$_tag   - auth_token: ${token != null ? _maskToken(token) : 'NULL'}',
      );
      debugPrint(
        '$_tag   - user: ${user != null ? 'Есть данные (${user.runtimeType})' : 'NULL'}',
      );
      if (user != null && user is Map) {
        debugPrint('$_tag   - user.id: ${user['id']}');
        debugPrint('$_tag   - user.name: ${user['name']}');
        debugPrint('$_tag   - user.email: ${user['email']}');
      }
      debugPrint('$_tag   - is_oauth: $isOAuth');

      // Проверяем SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefsToken = prefs.getString('auth_token');
      final prefsUserId = prefs.getInt('user_id');
      final prefsIsOAuth = prefs.getBool('is_oauth');

      debugPrint('$_tag 💾 SharedPreferences:');
      debugPrint(
        '$_tag   - auth_token: ${prefsToken != null ? _maskToken(prefsToken) : 'NULL'}',
      );
      debugPrint('$_tag   - user_id: $prefsUserId');
      debugPrint('$_tag   - is_oauth: $prefsIsOAuth');

      debugPrint('$_tag ========== КОНЕЦ ПРОВЕРКИ ==========');
    } catch (e) {
      debugPrint('$_tag ❌ Ошибка проверки: $e');
    }
  }

  static String _maskToken(String token) {
    if (token.length < 10) return '***';
    return '${token.substring(0, 10)}...${token.substring(token.length - 6)}';
  }
}
