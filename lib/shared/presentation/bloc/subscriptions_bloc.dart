import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hive/hive.dart';
import 'package:hashtagg/core/network/subscription_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';

// ============================================================
// EVENTS
// ============================================================
abstract class SubscriptionsEvent {}

class AddSubscription extends SubscriptionsEvent {
  final int userId; // 👈 ID владельца магазина
  final int shopId; // 👈 ID магазина
  final User user;

  AddSubscription({
    required this.userId,
    required this.shopId,
    required this.user,
  });
}

class RemoveSubscription extends SubscriptionsEvent {
  final int id;
  RemoveSubscription(this.id);
}

class LoadSubscriptions extends SubscriptionsEvent {}

class SyncSubscriptions extends SubscriptionsEvent {} // ✅ НОВОЕ СОБЫТИЕ

// ============================================================
// STATE
// ============================================================
class SubscriptionsState {
  final Set<int> ids;
  final Map<int, User> users;
  final bool isLoading;

  SubscriptionsState(this.ids, this.users, {this.isLoading = false});

  List<User> get subscribedUsers =>
      ids.map((id) => users[id]).whereType<User>().toList();

  SubscriptionsState copyWith({
    Set<int>? ids,
    Map<int, User>? users,
    bool? isLoading,
  }) {
    return SubscriptionsState(
      ids ?? this.ids,
      users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// ============================================================
// BLOC
// ============================================================
class SubscriptionsBloc extends Bloc<SubscriptionsEvent, SubscriptionsState> {
  late Box _subscriptionsBox;
  final SubscriptionApiRepository _apiRepository;

  SubscriptionsBloc()
    : _apiRepository = SubscriptionApiRepository(),
      super(SubscriptionsState({}, {})) {
    on<LoadSubscriptions>(_onLoadSubscriptions);
    on<AddSubscription>(_onAddSubscription);
    on<RemoveSubscription>(_onRemoveSubscription);
    on<SyncSubscriptions>(_onSyncSubscriptions);

    add(LoadSubscriptions());
  }

  // ============================================================
  // HELPERS: Сериализация
  // ============================================================
  Map<String, dynamic> _userToMap(User user) {
    return {
      'id': user.id,
      'name': user.name,
      'surname': user.surname,
      'last_name': user.last_name,
      'shortname': user.shortname,
      'email': user.email,
      'phone': user.phone,
      'avatar': user.avatar,
      'status': user.status,
      'isCompany': user.isCompany,
      'companyName': user.companyName,
      'safeDealEnabled': user.safeDealEnabled,
      'ymoneyAccount': user.ymoneyAccount,
      'bookingEnabled': user.bookingEnabled,
      'cardNumber': user.cardNumber,
      'showPhoneInListings': user.showPhoneInListings,
    };
  }

  User _mapToUser(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    return User(
      id: map['id'] as int,
      name: (map['name'] as String?) ?? '',
      surname: map['surname'] as String?,
      last_name: map['last_name'] as String?,
      shortname: map['shortname'] as String?,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
      avatar: map['avatar'] as String?,
      status: map['status'] as String?,
      isCompany: map['isCompany'] as bool?,
      companyName: map['companyName'] as String?,
      safeDealEnabled: map['safeDealEnabled'] as bool?,
      ymoneyAccount: map['ymoneyAccount'] as String?,
      bookingEnabled: map['bookingEnabled'] as bool?,
      cardNumber: map['cardNumber'] as String?,
      showPhoneInListings: map['showPhoneInListings'] as bool?,
    );
  }

  // ============================================================
  // HANDLERS
  // ============================================================

  /// 1. Загрузка подписок (Hive + сервер)
  Future<void> _onLoadSubscriptions(
    LoadSubscriptions event,
    Emitter<SubscriptionsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      _subscriptionsBox = await Hive.openBox('subscriptions');

      // 📥 ЧИТАЕМ ИЗ HIVE
      final List<int>? storedIds = (_subscriptionsBox.get('items') as List?)
          ?.cast<int>();

      final dynamic rawUsers = _subscriptionsBox.get('users');
      final Map<int, User> usersMap = {};

      if (rawUsers != null) {
        final map = Map<dynamic, dynamic>.from(rawUsers as Map);
        for (final entry in map.entries) {
          final id = entry.key as int;
          usersMap[id] = _mapToUser(entry.value);
        }
      }

      // 🌐 ЗАГРУЖАЕМ С СЕРВЕРА
      final box = Hive.box('user');
      final userData = box.get('user');
      final userId = userData?['id'] as int? ?? 0;

      List<int> serverIds = [];
      if (userId > 0) {
        serverIds = await _apiRepository.getUserSubscriptions(userId);
        print('✅ [SubscriptionsBloc] Server subscriptions: $serverIds');
      }

      // ➕ ОБЪЕДИНЯЕМ (серверные + локальные)
      final allIds = <int>{};
      if (storedIds != null) {
        allIds.addAll(storedIds);
      }
      allIds.addAll(serverIds);

      // 🔄 ДОБАВЛЯЕМ НЕДОСТАЮЩИХ ПОЛЬЗОВАТЕЛЕЙ ИЗ HIVE
      if (storedIds != null) {
        for (final id in storedIds) {
          if (!usersMap.containsKey(id) && rawUsers != null) {
            final map = Map<dynamic, dynamic>.from(rawUsers as Map);
            if (map.containsKey(id)) {
              usersMap[id] = _mapToUser(map[id]);
            }
          }
        }
      }

      emit(SubscriptionsState(allIds, usersMap, isLoading: false));
    } catch (e) {
      print('❌ [SubscriptionsBloc] Load error: $e');
      emit(state.copyWith(isLoading: false));
    }
  }

  /// 2. Добавление подписки
  Future<void> _onAddSubscription(
    AddSubscription event,
    Emitter<SubscriptionsState> emit,
  ) async {
    print('📥 [SubscriptionsBloc] _onAddSubscription START');
    print('   userId: ${event.userId}'); // ✅ event.userId
    print('   shopId: ${event.shopId}'); // ✅ event.shopId
    print('   user: ${event.user.name}');

    try {
      final box = Hive.box('user');
      final userData = box.get('user');
      final currentUserId = userData?['id'] as int? ?? 0;
      final token = box.get('auth_token');

      print('📤 [SubscriptionsBloc] currentUserId: $currentUserId');

      if (currentUserId > 0 && token != null) {
        print('📤 [SubscriptionsBloc] Calling API: subscribeShop');
        final success = await _apiRepository.subscribeShop(
          userId: event.userId, // ✅ ВЛАДЕЛЕЦ МАГАЗИНА
          shopId: event.shopId, // ✅ ID МАГАЗИНА
        );
        print('📤 [SubscriptionsBloc] API response: $success');

        if (!success) {
          print('❌ [SubscriptionsBloc] Failed to subscribe on server');
          return;
        }
      } else {
        print('❌ [SubscriptionsBloc] No userId or token');
        return;
      }

      // 💾 СОХРАНЯЕМ В HIVE
      print('💾 [SubscriptionsBloc] Saving to Hive...');
      final newIds = Set<int>.from(state.ids)
        ..add(event.userId); // ✅ event.userId
      final newUsers = Map<int, User>.from(state.users)
        ..[event.userId] = event.user; // ✅ event.userId

      final serialized = {
        for (final entry in newUsers.entries)
          entry.key: _userToMap(entry.value),
      };

      await _subscriptionsBox.put('items', newIds.toList());
      await _subscriptionsBox.put('users', serialized);

      emit(SubscriptionsState(newIds, newUsers));
    } catch (e) {
      print('❌ [SubscriptionsBloc] Add error: $e');
    }
  }

  /// 3. Удаление подписки
  Future<void> _onRemoveSubscription(
    RemoveSubscription event,
    Emitter<SubscriptionsState> emit,
  ) async {
    try {
      // 📤 ОТПРАВЛЯЕМ НА СЕРВЕР
      final box = Hive.box('user');
      final userData = box.get('user');
      final userId = userData?['id'] as int? ?? 0;
      final token = box.get('auth_token');

      if (userId > 0 && token != null) {
        final success = await _apiRepository.unsubscribeShop(
          userId: userId,
          shopId: event.id,
        );

        if (!success) {
          print('❌ [SubscriptionsBloc] Failed to unsubscribe on server');
          // ❌ НЕ УДАЛЯЕМ ИЗ HIVE, ЕСЛИ СЕРВЕР ОТВЕТИЛ ОШИБКОЙ
          return;
        }
      }

      // 💾 УДАЛЯЕМ ИЗ HIVE
      final newIds = Set<int>.from(state.ids)..remove(event.id);
      final newUsers = Map<int, User>.from(state.users)..remove(event.id);

      final serialized = {
        for (final entry in newUsers.entries)
          entry.key: _userToMap(entry.value),
      };

      await _subscriptionsBox.put('items', newIds.toList());
      await _subscriptionsBox.put('users', serialized);

      emit(SubscriptionsState(newIds, newUsers));
    } catch (e) {
      print('❌ [SubscriptionsBloc] Remove error: $e');
    }
  }

  /// 4. Синхронизация с сервером
  Future<void> _onSyncSubscriptions(
    SyncSubscriptions event,
    Emitter<SubscriptionsState> emit,
  ) async {
    print('🔄 [SubscriptionsBloc] Syncing with server...');
    add(LoadSubscriptions());
  }
}
