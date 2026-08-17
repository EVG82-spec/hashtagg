import 'package:flutter/material.dart';

/// Класс для определения цветовых схем приложения
class AppTheme {
  // Светлая тема (текущие цвета без изменений)
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.black),
      titleTextStyle: TextStyle(
        color: Colors.black,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Color.fromRGBO(0, 0, 0, 0.5),
      selectedItemColor: Color(0xff917dfa),
      unselectedItemColor: Color(0xff666666),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xff917dfa).withValues(alpha: 0.325),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
    cardColor: const Color(0xFFF5F7FA),
    dividerColor: const Color(0xFFEEEEEE),
  );

  // Тёмная тема
  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkBackground, // Бэкграунд экранов
    appBarTheme: const AppBarTheme(
      backgroundColor: darkBackground, // Бэкграунд appbar
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: darkSecondary, // Второстепенный цвет для навигации
      selectedItemColor: Color(0xff917dfa),
      unselectedItemColor: Color(0xff666666),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSecondary, // Второстепенный цвет для инпутов
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide.none,
      ),
    ),
    cardColor: darkSecondary, // Второстепенный цвет для карточек
    dividerColor: darkSecondary,
  );

  // Дополнительные цвета для тёмной темы
  static const Color darkBackground = Color(0xff151e27); // Основной бэкграунд (appbar, экраны)
  static const Color darkSecondary = Color(0xff233040); // Второстепенный (модалки, навигация, карточки категорий)
  static const Color darkTertiary = Color(0xff213140); // Третьестепенный (appbar поиск, loading)
}
