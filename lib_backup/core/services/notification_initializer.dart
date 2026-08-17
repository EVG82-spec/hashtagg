import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'package:hashtagg/core/services/notification_bloc.dart';
import 'package:hashtagg/core/services/unread_messages_bloc.dart' as unread;
import 'package:hashtagg/features/chats/bloc/chat_bloc.dart';
import 'package:hashtagg/features/chats/screens/chat_screen.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hashtagg/core/routes.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';

/// Виджет для инициализации навигации из уведомлений
/// Должен быть обернут вокруг MaterialApp.router
class NotificationInitializer extends StatefulWidget {
  final Widget child;

  const NotificationInitializer({
    super.key,
    required this.child,
  });

  @override
  State<NotificationInitializer> createState() => _NotificationInitializerState();
}

class _NotificationInitializerState extends State<NotificationInitializer> {
  Timer? _periodicCheckTimer;

  @override
  void initState() {
    super.initState();
    
    // Настраиваем навигацию после первого фрейма
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotificationNavigation();
      _startPeriodicCheck();
    });
  }

  @override
  void dispose() {
    _periodicCheckTimer?.cancel();
    super.dispose();
  }

  /// Запустить периодическую проверку счетчика (каждые 30 секунд)
  void _startPeriodicCheck() {
    _periodicCheckTimer?.cancel();
    _periodicCheckTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      final authBloc = context.read<AuthBloc>();
      if (authBloc.state is Authenticated || 
          (authBloc.state is AuthInitial && (authBloc.state as AuthInitial).user != null)) {
        print('🔄 [NotificationInitializer] Periodic check: reloading unread count');
        context.read<unread.UnreadMessagesBloc>().add(unread.LoadUnreadCount());
      }
    });
    print('✅ [NotificationInitializer] Periodic check started (every 30 seconds)');
  }

  void _setupNotificationNavigation() {
    final notificationBloc = context.read<NotificationBloc>();
    final unreadMessagesBloc = context.read<unread.UnreadMessagesBloc>();
    final authBloc = context.read<AuthBloc>();
    final notificationService = notificationBloc.notificationService;

    // Загружаем счетчик при инициализации (если пользователь авторизован)
    if (authBloc.state is Authenticated || 
        (authBloc.state is AuthInitial && (authBloc.state as AuthInitial).user != null)) {
      print('🔔 [NotificationInitializer] Loading initial unread count');
      unreadMessagesBloc.add(unread.LoadUnreadCount());
    }

    // Устанавливаем callback для обновления счетчика при получении сообщения

    // Слушаем изменения авторизации для загрузки счетчика
    authBloc.stream.listen((authState) {
      if (authState is Authenticated) {
        print('🔔 [NotificationInitializer] User authenticated, loading unread count');
        unreadMessagesBloc.add(unread.LoadUnreadCount());
      } else if (authState is Unauthenticated) {
        print('🔔 [NotificationInitializer] User logged out, resetting unread count');
        unreadMessagesBloc.add(unread.ResetUnreadCount());
      }
    });

    // Слушаем события NotificationBloc для обновления счетчика
    notificationBloc.stream.listen((notificationState) {
      if (notificationState is NotificationConnected) {
        // При подключении загружаем счетчик
        print('🔔 [NotificationInitializer] Notifications connected, loading unread count');
        unreadMessagesBloc.add(unread.LoadUnreadCount());
      }
    });

    // Настраиваем обработчик нажатия на уведомление
    notificationService.onNotificationTap = (dialogId, isSupport) {
      print('🔔 [NotificationInitializer] Notification tapped: dialogId=$dialogId, isSupport=$isSupport');
      
      _openChatDialog(dialogId, isSupport);
    };

    print('✅ [NotificationInitializer] Notification navigation configured');
  }

  Future<void> _openChatDialog(String dialogId, bool isSupport) async {
    try {
      print('🔔 [NotificationInitializer] Opening chat dialog: $dialogId');
      
      // Получаем navigator context из rootNavigatorKey
      final navigatorContext = rootNavigatorKey.currentContext;
      if (navigatorContext == null) {
        print('❌ [NotificationInitializer] Navigator context is null');
        return;
      }
      
      // Получаем ChatBloc
      final chatBloc = navigatorContext.read<ChatBloc>();
      
      // Загружаем диалог
      chatBloc.add(LoadDialog(dialogId: dialogId, isSupport: isSupport));
      
      // Ждем загрузки диалога через stream
      print('🔔 [NotificationInitializer] Waiting for dialog to load...');
      
      await for (final state in chatBloc.stream) {
        if (state.currentDialog != null && state.currentDialog!.idHash == dialogId) {
          print('✅ [NotificationInitializer] Dialog loaded with ${state.currentDialog!.messages.length} messages');
          break;
        }
        
        // Таймаут на случай если диалог не загрузится
        await Future.delayed(const Duration(milliseconds: 100));
      }
      
      // Дополнительная небольшая задержка для гарантии
      await Future.delayed(const Duration(milliseconds: 200));
      
      final state = chatBloc.state;
      
      if (state.currentDialog == null) {
        print('❌ [NotificationInitializer] Dialog not loaded after waiting');
        // Просто открываем список чатов
        GoRouter.of(navigatorContext).go('/chats');
        return;
      }
      
      print('✅ [NotificationInitializer] Opening chat screen');
      
      // Получаем navigator
      final navigator = rootNavigatorKey.currentState;
      if (navigator == null) {
        print('❌ [NotificationInitializer] Navigator state is null');
        return;
      }
      
      if (isSupport) {
        // Открываем чат с поддержкой
        await navigator.push(
          createSwipeableRoute(
            builder: (_) => ChatScreen(
              userName: 'Поддержка',
              lastSeen: 'Будем рады помочь',
              avatarUrl: '${ApiConfig.mediaUrl}/templates/images/supportChat.png',
              dialogId: dialogId,
              listing: const ChatListing(
                title: '',
                price: '',
                status: '',
              ),
              userId: 0,
              isSupport: true,
              shouldScrollToBottom: true, // Прокручиваем к последнему сообщению
            ),
          ),
        );
      } else {
        // Открываем обычный чат
        final dialog = state.currentDialog!;
        
        await navigator.push(
          createSwipeableRoute(
            builder: (_) => ChatScreen(
              userName: dialog.user?.name ?? 'Пользователь',
              lastSeen: dialog.user?.statusOnline ?? '',
              avatarUrl: dialog.user?.avatar,
              listing: ChatListing(
                title: dialog.ad?.title ?? '',
                price: dialog.ad?.price ?? '',
                status: dialog.ad?.statusName ?? '',
                imageUrl: dialog.ad?.image,
                listingId: dialog.ad?.id.toString(),
              ),
              dialogId: dialogId,
              userId: dialog.user?.id ?? 0,
              isShop: dialog.user?.isShop ?? false,
              shouldScrollToBottom: true, // Прокручиваем к последнему сообщению
            ),
          ),
        );
      }
      
      print('✅ [NotificationInitializer] Chat screen closed, refreshing dialogs');
      
      // Обновляем список диалогов после возврата
      chatBloc.add(LoadDialogs());
      
      // Перезагружаем счетчик непрочитанных сообщений
      final navContext = rootNavigatorKey.currentContext;
      if (navContext != null) {
        navContext.read<unread.UnreadMessagesBloc>().add(unread.LoadUnreadCount());
      }
      
    } catch (e, stackTrace) {
      print('❌ [NotificationInitializer] Error opening chat: $e');
      print('Stack trace: $stackTrace');
      
      // В случае ошибки просто открываем список чатов
      final navigatorContext = rootNavigatorKey.currentContext;
      if (navigatorContext != null) {
        GoRouter.of(navigatorContext).go('/chats');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
