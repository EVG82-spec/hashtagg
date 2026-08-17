import 'package:flutter/material.dart';

/// Вспомогательный класс для получения цветов в зависимости от темы
class ThemeColors {
  /// Получить цвет фона для карточек категорий
  static Color getCategoryCardColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xff233040) : Colors.white;
  }
  
  /// Получить цвет фона для поиска в AppBar
  static Color getSearchBarColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xff213140) : const Color(0xFFF5F7FA);
  }
  
  /// Получить цвет текста
  static Color getTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : Colors.black;
  }
  
  /// Получить цвет второстепенного текста
  static Color getSecondaryTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white70 : Colors.black87;
  }
  
  /// Получить цвет фона модальных окон
  static Color getModalBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xff233040) : Colors.white;
  }
  
  /// Получить цвет фона инпутов
  static Color getInputBackgroundColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xff233040) : const Color(0xFFF5F7FA);
  }
}
