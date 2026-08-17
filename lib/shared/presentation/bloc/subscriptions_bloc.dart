import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hive/hive.dart';

abstract class SubscriptionsEvent {}

class AddSubscription extends SubscriptionsEvent {
  final int id;
  final User user;
  AddSubscription(this.id, this.user);
}

class RemoveSubscription extends SubscriptionsEvent {
  final int id;
  RemoveSubscription(this.id);
}

class LoadSubscriptions extends SubscriptionsEvent {}

class SubscriptionsState {
  final Set<int> ids;
  final Map<int, User> users;

  SubscriptionsState(this.ids, this.users);

  List<User> get subscribedUsers =>
      ids.map((id) => users[id]).whereType<User>().toList();
}

class SubscriptionsBloc extends Bloc<SubscriptionsEvent, SubscriptionsState> {
  late Box _subscriptionsBox;

  SubscriptionsBloc() : super(SubscriptionsState({}, {})) {
    on<LoadSubscriptions>(_onLoadSubscriptions);
    on<AddSubscription>(_onAddSubscription);
    on<RemoveSubscription>(_onRemoveSubscription);

    add(LoadSubscriptions());
  }

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

  Future<void> _onLoadSubscriptions(
    LoadSubscriptions event,
    Emitter<SubscriptionsState> emit,
  ) async {
    _subscriptionsBox = await Hive.openBox('subscriptions');

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

    emit(SubscriptionsState(storedIds?.toSet() ?? {}, usersMap));
  }

  Future<void> _onAddSubscription(
    AddSubscription event,
    Emitter<SubscriptionsState> emit,
  ) async {
    final newIds = Set<int>.from(state.ids)..add(event.id);
    final newUsers = Map<int, User>.from(state.users)..[event.id] = event.user;

    final serialized = {
      for (final entry in newUsers.entries) entry.key: _userToMap(entry.value),
    };

    await _subscriptionsBox.put('items', newIds.toList());
    await _subscriptionsBox.put('users', serialized);

    emit(SubscriptionsState(newIds, newUsers));
  }

  Future<void> _onRemoveSubscription(
    RemoveSubscription event,
    Emitter<SubscriptionsState> emit,
  ) async {
    final newIds = Set<int>.from(state.ids)..remove(event.id);
    final newUsers = Map<int, User>.from(state.users)..remove(event.id);

    final serialized = {
      for (final entry in newUsers.entries) entry.key: _userToMap(entry.value),
    };

    await _subscriptionsBox.put('items', newIds.toList());
    await _subscriptionsBox.put('users', serialized);

    emit(SubscriptionsState(newIds, newUsers));
  }
}
