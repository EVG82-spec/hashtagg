import 'package:hashtagg/shared/domain/entities/user.dart';

/// Утилита для проверки доступа к функциям магазина
class ShopAccessChecker {
  /// Проверяет, есть ли у пользователя доступ к магазину
  static bool hasShopAccess(User? user) {
    if (user == null) return false;
    
    // Проверяем наличие тарифа
    if (user.tariffId == null || user.tariffId == 0) return false;
    
    // Проверяем наличие активных сервисов
    if (user.activeServices == null || user.activeServices!.isEmpty) return false;
    
    // Проверяем наличие сервиса магазина
    return user.activeServices!.contains('shop');
  }
  
  /// Проверяет, есть ли у пользователя доступ к страницам магазина
  static bool hasShopPagesAccess(User? user) {
    if (user == null) return false;
    if (user.activeServices == null) return false;
    
    return user.activeServices!.contains('shop_page');
  }
  
  /// Проверяет, есть ли у пользователя доступ к уникальному адресу магазина
  static bool hasUniqueShopAddress(User? user) {
    if (user == null) return false;
    if (user.activeServices == null) return false;
    
    return user.activeServices!.contains('unique_shop_address');
  }
  
  /// Проверяет, есть ли у пользователя доступ к слайдерам магазина
  static bool hasShopSliders(User? user) {
    if (user == null) return false;
    if (user.activeServices == null) return false;
    
    // Слайдеры обычно идут вместе с базовым магазином
    return user.activeServices!.contains('shop');
  }
  
  /// Проверяет, есть ли у пользователя доступ к поиску в магазине
  static bool hasShopSearchAccess(User? user) {
    if (user == null) return false;
    if (user.activeServices == null) return false;
    
    return user.activeServices!.contains('search_shop');
  }
  
  /// Проверяет, есть ли у пользователя доступ к ссылкам магазина
  static bool hasShopLinksAccess(User? user) {
    if (user == null) return false;
    if (user.activeServices == null) return false;
    
    return user.activeServices!.contains('shop_links');
  }
  
  /// Возвращает сообщение об отсутствии доступа
  static String getAccessDeniedMessage() {
    return 'Для доступа к магазину необходимо приобрести тариф';
  }
  
  /// Возвращает сообщение о необходимости обновления тарифа для конкретной функции
  static String getFeatureAccessDeniedMessage(String feature) {
    switch (feature) {
      case 'shop_page':
        return 'Страницы магазина доступны в расширенном тарифе';
      case 'unique_shop_address':
        return 'Уникальный адрес магазина доступен в расширенном тарифе';
      case 'search_shop':
        return 'Поиск в магазине доступен в расширенном тарифе';
      case 'shop_links':
        return 'Ссылки магазина доступны в расширенном тарифе';
      default:
        return 'Эта функция доступна в расширенном тарифе';
    }
  }
}
