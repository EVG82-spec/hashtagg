import 'package:flutter/material.dart';

/// Вспомогательные функции для работы с темой
class ThemeHelpers {
  /// Получить цвет фона Scaffold в зависимости от темы
  static Color getScaffoldBackgroundColor(BuildContext context) {
    return Theme.of(context).scaffoldBackgroundColor;
  }
  
  /// Получить цвет AppBar в зависимости от темы
  static Color getAppBarBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xff151e27) : Colors.white;
  }
  
  /// Проверить, активна ли тёмная тема
  static bool isDarkMode(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }
}
