import 'package:flutter/material.dart';

/// Расширения для удобной работы с темой
extension ThemeExtensions on BuildContext {
  /// Проверить, активна ли тёмная тема
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;
  
  /// Получить цвет фона Scaffold
  Color get scaffoldBackground => Theme.of(this).scaffoldBackgroundColor;
  
  /// Получить цвет AppBar
  Color get appBarBackground => 
      Theme.of(this).appBarTheme.backgroundColor ?? 
      (isDarkMode ? const Color(0xff151e27) : Colors.white);
  
  /// Получить цвет текста
  Color get textColor => isDarkMode ? Colors.white : Colors.black;
  
  /// Получить цвет второстепенного текста
  Color get secondaryTextColor => isDarkMode ? Colors.white70 : Colors.black87;
  
  /// Получить цвет карточек
  Color get cardBackground => Theme.of(this).cardColor;
  
  /// Получить цвет инпутов
  Color get inputBackground => 
      isDarkMode ? const Color(0xff233040) : const Color(0xFFF5F7FA);
  
  /// Получить цвет поиска в AppBar
  Color get searchBarBackground => 
      isDarkMode ? const Color(0xff213140) : const Color(0xFFF5F7FA);
  
  /// Получить цвет иконок
  Color get iconColor => isDarkMode ? Colors.white : Colors.black;
}
