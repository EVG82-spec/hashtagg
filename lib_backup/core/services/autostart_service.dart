import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AutostartService {
  static const platform = MethodChannel('ru.hashtagg.androidapplication/autostart');
  
  static const _dontShowAgainKey = 'autostart_dont_show_again';

  static const _hasShownKey = 'autostart_has_shown';

  static Future<bool> hasShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_hasShownKey) ?? false;
  }

  /// Пометить диалог как показанный
  static Future<void> markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_hasShownKey, true);
  }

  
  /// Список производителей, требующих настройки автозапуска
  static const problematicManufacturers = [
    'xiaomi',
    'oppo',
    'vivo',
    'letv',
    'honor',
    'huawei',
  ];
  
  /// Получить производителя устройства
  static Future<String> getManufacturer() async {
    try {
      final String manufacturer = await platform.invokeMethod('getManufacturer');
      return manufacturer.toLowerCase();
    } catch (e) {
      print('❌ [AutostartService] Error getting manufacturer: $e');
      return '';
    }
  }
  
  /// Проверить, нужно ли показывать попап
  static Future<bool> shouldShowPopup() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Если пользователь явно отказался – не показываем
      if (prefs.getBool(_dontShowAgainKey) ?? false) return false;
      // Если диалог уже был показан – не показываем снова
      if (prefs.getBool(_hasShownKey) ?? false) return false;

      final manufacturer = await getManufacturer();
      return problematicManufacturers.contains(manufacturer);
    } catch (e) {
      print('❌ [AutostartService] Error checking if should show popup: $e');
      return false;
    }
  }
  
  /// Открыть настройки автозапуска
  static Future<bool> openAutostartSettings() async {
    try {
      final bool result = await platform.invokeMethod('openAutostartSettings');
      return result;
    } catch (e) {
      print('❌ [AutostartService] Error opening autostart settings: $e');
      return false;
    }
  }
  
  /// Установить флаг "больше не показывать"
  static Future<void> setDontShowAgain() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_dontShowAgainKey, true);
      print('✅ [AutostartService] Dont show again flag set');
    } catch (e) {
      print('❌ [AutostartService] Error setting dont show again: $e');
    }
  }
  
  /// Получить инструкцию для текущего производителя
  static Future<String> getInstructions() async {
    final manufacturer = await getManufacturer();
    
    switch (manufacturer) {
      case 'xiaomi':
        return '''
1. Откройте "Безопасность" → "Разрешения"
2. Выберите "Автозапуск"
3. Найдите приложение "Хештег"
4. Включите автозапуск
''';
      
      case 'honor':
      case 'huawei':
        return '''
1. Откройте "Диспетчер телефона"
2. Нажмите "Оптимизация" или "Батарея"
3. Перейдите в "Запуск приложений" или "App launch" или "Автозапуск"
4. Найдите "Хештег" и отключите "Управлять автоматически"
5. Включите все три переключателя:
   • Автозапуск
   • Косвенный запуск
   • Фоновый запуск
6. Нажмите "ОК"
''';
      
      case 'oppo':
        return '''
1. Откройте "Настройки" → "Батарея"
2. Выберите "Управление запуском приложений"
3. Найдите "Хештег"
4. Включите автозапуск
''';
      
      case 'vivo':
        return '''
1. Откройте "Настройки" → "Батарея"
2. Выберите "Фоновые приложения"
3. Найдите "Хештег"
4. Разрешите фоновую работу
''';
      
      case 'letv':
        return '''
1. Откройте "Безопасность"
2. Выберите "Автозапуск"
3. Найдите "Хештег"
4. Включите автозапуск
''';
      
      default:
        return '''
Для корректной работы уведомлений необходимо разрешить автозапуск приложения в настройках вашего устройства.
''';
    }
  }
}
