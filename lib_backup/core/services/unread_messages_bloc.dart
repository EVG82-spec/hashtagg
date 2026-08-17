import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:hive/hive.dart';
import 'dart:convert';

// Events
abstract class UnreadMessagesEvent {}

class LoadUnreadCount extends UnreadMessagesEvent {}

class UpdateUnreadCount extends UnreadMessagesEvent {
  final int count;
  UpdateUnreadCount(this.count);
}

class IncrementUnreadCount extends UnreadMessagesEvent {}

class DecrementUnreadCount extends UnreadMessagesEvent {
  final int amount;
  DecrementUnreadCount({this.amount = 1});
}

class ResetUnreadCount extends UnreadMessagesEvent {}

// State
class UnreadMessagesState {
  final int count;
  final bool isLoading;

  UnreadMessagesState({
    this.count = 0,
    this.isLoading = false,
  });

  UnreadMessagesState copyWith({
    int? count,
    bool? isLoading,
  }) {
    return UnreadMessagesState(
      count: count ?? this.count,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Bloc
class UnreadMessagesBloc extends Bloc<UnreadMessagesEvent, UnreadMessagesState> {
  UnreadMessagesBloc() : super(UnreadMessagesState()) {
    on<LoadUnreadCount>(_onLoadUnreadCount);
    on<UpdateUnreadCount>(_onUpdateUnreadCount);
    on<IncrementUnreadCount>(_onIncrementUnreadCount);
    on<DecrementUnreadCount>(_onDecrementUnreadCount);
    on<ResetUnreadCount>(_onResetUnreadCount);
  }

  Future<void> _onLoadUnreadCount(
    LoadUnreadCount event,
    Emitter<UnreadMessagesState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      final count = await _fetchUnreadCount();
      emit(state.copyWith(count: count, isLoading: false));
      print('✅ [UnreadMessagesBloc] Loaded unread count: $count');
    } catch (e) {
      print('❌ [UnreadMessagesBloc] Error loading unread count: $e');
      emit(state.copyWith(isLoading: false));
    }
  }

  void _onUpdateUnreadCount(
    UpdateUnreadCount event,
    Emitter<UnreadMessagesState> emit,
  ) {
    emit(state.copyWith(count: event.count));
    print('✅ [UnreadMessagesBloc] Updated unread count: ${event.count}');
  }

  void _onIncrementUnreadCount(
    IncrementUnreadCount event,
    Emitter<UnreadMessagesState> emit,
  ) {
    final newCount = state.count + 1;
    emit(state.copyWith(count: newCount));
    print('✅ [UnreadMessagesBloc] Incremented unread count: $newCount');
  }

  void _onDecrementUnreadCount(
    DecrementUnreadCount event,
    Emitter<UnreadMessagesState> emit,
  ) {
    final newCount = (state.count - event.amount).clamp(0, 999);
    emit(state.copyWith(count: newCount));
    print('✅ [UnreadMessagesBloc] Decremented unread count: $newCount');
  }

  void _onResetUnreadCount(
    ResetUnreadCount event,
    Emitter<UnreadMessagesState> emit,
  ) {
    emit(state.copyWith(count: 0));
    print('✅ [UnreadMessagesBloc] Reset unread count');
  }

  /// Получить количество непрочитанных сообщений с API
  Future<int> _fetchUnreadCount() async {
    try {
      // Получаем credentials из Hive
      final box = await Hive.openBox('user');
      final authToken = box.get('auth_token');
      var userId = box.get('user_id');
      
      if (userId == null) {
        final user = box.get('user');
        if (user is Map) {
          userId = user['id'];
        }
      }
      
      if (authToken == null || userId == null) {
        print('❌ [UnreadMessagesBloc] Missing credentials: token=$authToken, userId=$userId');
        return 0;
      }
      
      print('🔍 [UnreadMessagesBloc] Fetching unread count for user $userId');
      
      // Используем существующий endpoint для получения непрочитанных сообщений
      final url = '${ApiConfig.baseUrl}/systems/api/controller.php?key=${ApiConfig.apiKey}&route=profile/notifications/getUnread';
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': 'Bearer $authToken',
        },
        body: {
          'id_user': userId.toString(),
          'token': authToken,
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('🔍 [UnreadMessagesBloc] API response: ${data['status']}, notifications count: ${data['notifications']?.length ?? 0}');
        
        if (data['status'] == true && data['notifications'] != null) {
          final notifications = data['notifications'] as List;
          print('✅ [UnreadMessagesBloc] Found ${notifications.length} unread messages');
          return notifications.length;
        }
      } else {
        print('❌ [UnreadMessagesBloc] API error: ${response.statusCode}');
      }
      
      return 0;
    } catch (e) {
      print('❌ [UnreadMessagesBloc] Error fetching unread count: $e');
      return 0;
    }
  }
}
