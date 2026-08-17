import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

/// Провайдер для управления темой приложения
class ThemeProvider extends ChangeNotifier {
  static const String _themeBoxName = 'theme_settings';
  static const String _themeModeKey = 'theme_mode';
  
  ThemeMode _themeMode = ThemeMode.light;
  
  ThemeProvider() {
    _loadThemeMode();
  }
  
  ThemeMode get themeMode => _themeMode;
  
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  
  /// Загрузка сохранённой темы из Hive
  Future<void> _loadThemeMode() async {
    try {
      final box = await Hive.openBox(_themeBoxName);
      final savedMode = box.get(_themeModeKey, defaultValue: 'light') as String;
      _themeMode = savedMode == 'dark' ? ThemeMode.dark : ThemeMode.light;
      notifyListeners();
    } catch (e) {
      print('🔴 [ThemeProvider] Error loading theme: $e');
    }
  }
  
  /// Переключение темы
  Future<void> toggleTheme() async {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await _saveThemeMode();
    notifyListeners();
  }
  
  /// Установка конкретной темы
  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode != mode) {
      _themeMode = mode;
      await _saveThemeMode();
      notifyListeners();
    }
  }
  
  /// Сохранение темы в Hive
  Future<void> _saveThemeMode() async {
    try {
      final box = await Hive.openBox(_themeBoxName);
      await box.put(_themeModeKey, _themeMode == ThemeMode.dark ? 'dark' : 'light');
    } catch (e) {
      print('🔴 [ThemeProvider] Error saving theme: $e');
    }
  }
}
