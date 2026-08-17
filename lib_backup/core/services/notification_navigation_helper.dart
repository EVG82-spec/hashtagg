import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/core/services/notification_service.dart';

/// Хелпер для настройки навигации из уведомлений
class NotificationNavigationHelper {
  static void setupNotificationNavigation(
    BuildContext context,
    NotificationService notificationService,
  ) {
    // Настраиваем обработчик нажатия на уведомление
    notificationService.onNotificationTap = (dialogId, isSupport) {
      print('🔔 [NotificationNavigation] Notification tapped: dialogId=$dialogId, isSupport=$isSupport');
      
      // Навигация к чату
      // Используем context.go для навигации
      try {
        // Переходим на экран чатов
        context.go('/chats');
        
        // TODO: Открыть конкретный диалог
        // Для этого нужно будет добавить параметр в ChatScreen
        // или использовать другой подход
        
        print('✅ [NotificationNavigation] Navigated to chats');
      } catch (e) {
        print('❌ [NotificationNavigation] Navigation error: $e');
      }
    };
  }
}
