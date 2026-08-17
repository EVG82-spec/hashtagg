import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/services/notification_service.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:flutter/material.dart';

// События
abstract class NotificationEvent {}

class InitializeNotifications extends NotificationEvent {
  final String userId;
  final String authToken;
  final BuildContext? context; // Для навигации

  InitializeNotifications({
    required this.userId,
    required this.authToken,
    this.context,
  });
}

class DisconnectNotifications extends NotificationEvent {}

class ReconnectNotifications extends NotificationEvent {}

class NotificationReceived extends NotificationEvent {
  final Map<String, dynamic> data;

  NotificationReceived(this.data);
}

// Состояния
abstract class NotificationState {}

class NotificationInitial extends NotificationState {}

class NotificationConnecting extends NotificationState {}

class NotificationConnected extends NotificationState {
  final String userId;

  NotificationConnected(this.userId);
}

class NotificationDisconnected extends NotificationState {}

class NotificationError extends NotificationState {
  final String message;

  NotificationError(this.message);
}

// Bloc
class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  final NotificationService _notificationService = NotificationService();
  final AuthBloc authBloc;
  String? _lastUserId;
  String? _lastAuthToken;
  
  // Callback для обновления счетчика непрочитанных
  Function()? onMessageReceivedCallback;

  NotificationBloc({required this.authBloc}) : super(NotificationInitial()) {
    on<InitializeNotifications>(_onInitialize);
    on<DisconnectNotifications>(_onDisconnect);
    on<ReconnectNotifications>(_onReconnect);
    on<NotificationReceived>(_onNotificationReceived);

    // Слушаем изменения AuthBloc
    authBloc.stream.listen((authState) {
      if (authState is Authenticated) {
        // Пользователь авторизовался - инициализируем уведомления
        print('🔔 [NotificationBloc] User authenticated, initializing notifications');
        _initializeForUser(authState.user.id.toString(), authState.user.token ?? '');
      } else if (authState is Unauthenticated) {
        // Пользователь вышел - отключаем уведомления
        print('🔔 [NotificationBloc] User logged out, disconnecting notifications');
        _lastUserId = null;
        _lastAuthToken = null;
        add(DisconnectNotifications());
      }
    });

    // Проверяем текущее состояние авторизации при создании bloc
    final currentAuthState = authBloc.state;
    if (currentAuthState is Authenticated) {
      final user = currentAuthState.user;
      print('🔔 [NotificationBloc] User already authenticated on app start, initializing notifications');
      _initializeForUser(user.id.toString(), user.token ?? '');
    } else if (currentAuthState is AuthInitial && currentAuthState.user != null) {
      // Пользователь был авторизован ранее (данные из Hive)
      final user = currentAuthState.user!;
      print('🔔 [NotificationBloc] User loaded from storage, initializing notifications');
      _initializeForUser(user.id.toString(), user.token ?? '');
    }
  }

  /// Вспомогательный метод для инициализации уведомлений
  void _initializeForUser(String userId, String authToken) {
    // Сохраняем данные для переподключения
    _lastUserId = userId;
    _lastAuthToken = authToken;
    
    // Проверяем, не инициализированы ли уже уведомления для этого пользователя
    if (state is NotificationConnected) {
      final connectedState = state as NotificationConnected;
      if (connectedState.userId == userId && _notificationService.isConnected) {
        print('🔔 [NotificationBloc] Notifications already initialized for user $userId');
        return;
      }
    }
    
    add(InitializeNotifications(
      userId: userId,
      authToken: authToken,
    ));
  }

  Future<void> _onInitialize(
    InitializeNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      print('🔔 [NotificationBloc] Initializing notifications for user ${event.userId}');
      emit(NotificationConnecting());

      await _notificationService.initialize(
        userId: event.userId,
        authToken: event.authToken,
      );

      // Настраиваем обработчики
      _notificationService.onMessageReceived = (data) {
        print('📨 [NotificationBloc] Message received in _onInitialize: $data');
        add(NotificationReceived(data));
        
        // Вызываем callback для обновления счетчика
        onMessageReceivedCallback?.call();
      };

      // Обработчик нажатия на уведомление настраивается в routes.dart
      // через NavigationNotifier

      emit(NotificationConnected(event.userId));
      print('✅ [NotificationBloc] Notifications initialized successfully');
    } catch (e) {
      print('❌ [NotificationBloc] Failed to initialize notifications: $e');
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> _onDisconnect(
    DisconnectNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      print('🔔 [NotificationBloc] Disconnecting notifications');
      await _notificationService.disconnect();
      emit(NotificationDisconnected());
      print('✅ [NotificationBloc] Notifications disconnected');
    } catch (e) {
      print('❌ [NotificationBloc] Failed to disconnect notifications: $e');
      emit(NotificationError(e.toString()));
    }
  }

  Future<void> _onReconnect(
    ReconnectNotifications event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      if (_lastUserId == null || _lastAuthToken == null) {
        print('❌ [NotificationBloc] Cannot reconnect: no saved credentials');
        return;
      }

      print('🔄 [NotificationBloc] Reconnecting notifications for user $_lastUserId');
      emit(NotificationConnecting());

      await _notificationService.initialize(
        userId: _lastUserId!,
        authToken: _lastAuthToken!,
      );

      // Настраиваем обработчики
      _notificationService.onMessageReceived = (data) {
        print('📨 [NotificationBloc] Message received in _onReconnect: $data');
        add(NotificationReceived(data));
        
        // Вызываем callback для обновления счетчика
        onMessageReceivedCallback?.call();
      };

      emit(NotificationConnected(_lastUserId!));
      print('✅ [NotificationBloc] Notifications reconnected successfully');
    } catch (e) {
      print('❌ [NotificationBloc] Failed to reconnect notifications: $e');
      emit(NotificationError(e.toString()));
    }
  }

  void _onNotificationReceived(
    NotificationReceived event,
    Emitter<NotificationState> emit,
  ) {
    // Здесь можно обработать полученное уведомление
    // Например, обновить счетчик непрочитанных сообщений
    print('📬 [NotificationBloc] Processing notification: ${event.data}');
    
    // Инкрементируем счетчик непрочитанных сообщений
    // Это будет обработано в NotificationInitializer через context
  }

  NotificationService get notificationService => _notificationService;

  @override
  Future<void> close() {
    _notificationService.disconnect();
    return super.close();
  }
}
