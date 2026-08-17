import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/network/profile_api_repository.dart';
import 'package:hive/hive.dart';
import 'package:equatable/equatable.dart';

// Events
abstract class ProfileEvent {}

class LoadMyProfile extends ProfileEvent {}

class LoadPublicProfile extends ProfileEvent {
  final int userId;
  LoadPublicProfile(this.userId);
}

class LoadUserAds extends ProfileEvent {
  final int userId;
  final String status;
  LoadUserAds(this.userId, {this.status = 'active'});
}

class LoadMyAds extends ProfileEvent {
  final int page;
  final String sorting;
  LoadMyAds({this.page = 1, this.sorting = 'active'});
}

class UpdateMyProfile extends ProfileEvent {
  final String? name;
  final String? surname;
  final String? middleName;
  final String? nicname;
  final String? typePerson;
  final String? nameCompany;
  final bool? viewPhone;
  final bool? secureStatus;
  final bool? deliveryStatus;
  final String? deliveryIdPointSend;

  UpdateMyProfile({
    this.name,
    this.surname,
    this.middleName,
    this.nicname,
    this.typePerson,
    this.nameCompany,
    this.viewPhone,
    this.secureStatus,
    this.deliveryStatus,
    this.deliveryIdPointSend,
  });
}

class ToggleSubscribe extends ProfileEvent {
  final int userIdTo;
  ToggleSubscribe(this.userIdTo);
}

class LoadSubscriptions extends ProfileEvent {}

class DeleteSubscription extends ProfileEvent {
  final int subscriptionId;
  DeleteSubscription(this.subscriptionId);
}

class LoadBlacklist extends ProfileEvent {}

class UnblockUser extends ProfileEvent {
  final int blacklistId;
  UnblockUser(this.blacklistId);
}

class ChangePassword extends ProfileEvent {
  final String currentPassword;
  final String newPassword;
  ChangePassword({required this.currentPassword, required this.newPassword});
}

class ProfileState {
  final Map<String, dynamic>? myProfileData;
  final Map<String, dynamic>? publicProfileData;
  final List<dynamic>? userAds;
  final List<dynamic>? myAds;
  final int? myAdsTotalCount;
  final int? myAdsPages;
  final bool isLoading;
  final bool isMyAdsLoading;
  final String? error;
  final bool updateSuccess;

  ProfileState({
    this.myProfileData,
    this.publicProfileData,
    this.userAds,
    this.myAds,
    this.myAdsTotalCount,
    this.myAdsPages,
    this.isLoading = false,
    this.isMyAdsLoading = false,
    this.error,
    this.updateSuccess = false,
  });

  factory ProfileState.initial() {
    return ProfileState();
  }

  ProfileState copyWith({
    Map<String, dynamic>? myProfileData,
    Map<String, dynamic>? publicProfileData,
    List<dynamic>? userAds,
    List<dynamic>? myAds,
    int? myAdsTotalCount,
    int? myAdsPages,
    bool? isLoading,
    bool? isMyAdsLoading,
    String? error,
    bool? updateSuccess,
    bool clearError = false,
  }) {
    return ProfileState(
      myProfileData: myProfileData ?? this.myProfileData,
      publicProfileData: publicProfileData ?? this.publicProfileData,
      userAds: userAds ?? this.userAds,
      myAds: myAds ?? this.myAds,
      myAdsTotalCount: myAdsTotalCount ?? this.myAdsTotalCount,
      myAdsPages: myAdsPages ?? this.myAdsPages,
      isLoading: isLoading ?? this.isLoading,
      isMyAdsLoading: isMyAdsLoading ?? this.isMyAdsLoading,
      error: clearError ? null : (error ?? this.error),
      updateSuccess: updateSuccess ?? this.updateSuccess,
    );
  }
}

// Старые классы состояний для обратной совместимости
abstract class ProfileStateOld extends Equatable {
  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileStateOld {}

class ProfileLoading extends ProfileStateOld {}

class MyProfileLoaded extends ProfileStateOld {
  final Map<String, dynamic> profileData;
  MyProfileLoaded(this.profileData);
}

class PublicProfileLoaded extends ProfileStateOld {
  final Map<String, dynamic> profileData;
  PublicProfileLoaded(this.profileData);
}

class UserAdsLoaded extends ProfileStateOld {
  final List<dynamic> ads;
  UserAdsLoaded(this.ads);
}

class MyAdsLoaded extends ProfileStateOld {
  final List<dynamic> ads;
  final int totalCount;
  final int pages;
  MyAdsLoaded({
    required this.ads,
    required this.totalCount,
    required this.pages,
  });

  @override
  List<Object?> get props => [ads, totalCount, pages];
}

class ProfileError extends ProfileStateOld {
  final String message;
  ProfileError(this.message);
}

class ProfileUpdateSuccess extends ProfileStateOld {}

class SubscriptionsLoaded extends ProfileStateOld {
  final List<dynamic> subscriptions;
  SubscriptionsLoaded(this.subscriptions);
}

class BlacklistLoaded extends ProfileStateOld {
  final List<dynamic> blacklist;
  BlacklistLoaded(this.blacklist);
}

class PasswordChanged extends ProfileStateOld {}

class SubscribeToggled extends ProfileStateOld {
  final String status; // 'added' or 'delete'
  final int count;
  SubscribeToggled({required this.status, required this.count});
}

// BLoC
class ProfileBloc extends Bloc<ProfileEvent, ProfileStateOld> {
  final ProfileApiRepository _apiRepository;

  // Публичный доступ к repository
  ProfileApiRepository get repository => _apiRepository;

  ProfileBloc({ProfileApiRepository? apiRepository})
      : _apiRepository = apiRepository ?? ProfileApiRepository(),
        super(ProfileInitial()) {
    on<LoadMyProfile>(_onLoadMyProfile);
    on<LoadPublicProfile>(_onLoadPublicProfile);
    on<LoadUserAds>(_onLoadUserAds);
    on<LoadMyAds>(_onLoadMyAds);
    on<UpdateMyProfile>(_onUpdateMyProfile);
    on<ToggleSubscribe>(_onToggleSubscribe);
    on<LoadSubscriptions>(_onLoadSubscriptions);
    on<DeleteSubscription>(_onDeleteSubscription);
    on<LoadBlacklist>(_onLoadBlacklist);
    on<UnblockUser>(_onUnblockUser);
    on<ChangePassword>(_onChangePassword);
  }

  Future<void> _onLoadMyProfile(
    LoadMyProfile event,
    Emitter<ProfileStateOld> emit,
  ) async {
    emit(ProfileLoading());
    
    try {
      final box = Hive.box('user');
      final token = box.get('auth_token');
      final userData = box.get('user');
      
      if (token == null || userData == null) {
        emit(ProfileError('Not authenticated'));
        return;
      }
      
      final userId = userData['id'];
      
      print('🔵 [ProfileBloc] Loading my profile for user: $userId');
      
      final response = await _apiRepository.getProfile(
        token: token,
        userId: userId,
      );
      
      if (response['status'] == false) {
        emit(ProfileError(response['error'] ?? 'Failed to load profile'));
        return;
      }
      
      print('🟢 [ProfileBloc] My profile loaded successfully');
      emit(MyProfileLoaded(response));
    } catch (e) {
      print('🔴 [ProfileBloc] Error loading my profile: $e');
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onLoadPublicProfile(
    LoadPublicProfile event,
    Emitter<ProfileStateOld> emit,
  ) async {
    emit(ProfileLoading());
    
    try {
      print('🔵 [ProfileBloc] Loading public profile for user: ${event.userId}');
      
      // Пытаемся получить токен авторизованного пользователя (опционально)
      final box = Hive.box('user');
      final token = box.get('auth_token');
      final userData = box.get('user');
      final authUserId = userData?['id'];
      
      final response = await _apiRepository.getPublicProfile(
        userId: event.userId,
        authUserId: authUserId,
        token: token,
      );
      
      print('🔵 [ProfileBloc] Response data check: ${response['data']}');
      
      // Проверяем что data существует и не пустой
      if (response['data'] == null || 
          (response['data'] is Map && (response['data'] as Map).isEmpty)) {
        print('🔴 [ProfileBloc] Profile data is null or empty');
        emit(ProfileError('Failed to load profile'));
        return;
      }
      
      print('🟢 [ProfileBloc] Public profile loaded successfully');
      emit(PublicProfileLoaded(response));
    } catch (e) {
      print('🔴 [ProfileBloc] Error loading public profile: $e');
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onLoadUserAds(
    LoadUserAds event,
    Emitter<ProfileStateOld> emit,
  ) async {
    // Не показываем loading для объявлений, чтобы не скрывать профиль
    try {
      print('🔵 [ProfileBloc] Loading user ads for user: ${event.userId}');
      
      final response = await _apiRepository.getUserAds(
        userId: event.userId,
        status: event.status,
      );
      
      final ads = response['data'] as List? ?? [];
      
      print('🟢 [ProfileBloc] User ads loaded: ${ads.length} items');
      emit(UserAdsLoaded(ads));
    } catch (e) {
      print('🔴 [ProfileBloc] Error loading user ads: $e');
      // Не показываем ошибку, просто пустой список
      emit(UserAdsLoaded([]));
    }
  }

  Future<void> _onUpdateMyProfile(
    UpdateMyProfile event,
    Emitter<ProfileStateOld> emit,
  ) async {
    emit(ProfileLoading());
    
    try {
      final box = Hive.box('user');
      final token = box.get('auth_token');
      final userData = box.get('user');
      
      if (token == null || userData == null) {
        emit(ProfileError('Not authenticated'));
        return;
      }
      
      final userId = userData['id'];
      
      print('🔵 [ProfileBloc] Updating profile for user: $userId');
      
      final response = await _apiRepository.updateProfile(
        token: token,
        userId: userId,
        name: event.name,
        surname: event.surname,
        middleName: event.middleName,
        nicname: event.nicname,
        typePerson: event.typePerson,
        nameCompany: event.nameCompany,
        viewPhone: event.viewPhone == true ? 1 : (event.viewPhone == false ? 0 : null),
        secureStatus: event.secureStatus == true ? 1 : (event.secureStatus == false ? 0 : null),
        deliveryStatus: event.deliveryStatus == true ? 1 : (event.deliveryStatus == false ? 0 : null),
        deliveryIdPointSend: event.deliveryIdPointSend,
      );
      
      if (response['status'] == false) {
        emit(ProfileError(response['errors'] ?? response['error'] ?? 'Failed to update profile'));
        return;
      }
      
      print('🟢 [ProfileBloc] Profile updated successfully');
      emit(ProfileUpdateSuccess());
      
      // Перезагружаем профиль после обновления
      add(LoadMyProfile());
    } catch (e) {
      print('🔴 [ProfileBloc] Error updating profile: $e');
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onLoadMyAds(
    LoadMyAds event,
    Emitter<ProfileStateOld> emit,
  ) async {
    // НЕ эмитим ProfileLoading, чтобы не скрывать данные профиля
    try {
      print('🔵 [ProfileBloc] Loading my ads - page: ${event.page}, sorting: ${event.sorting}');
      
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user');
      
      // userId может быть String или int, преобразуем в int
      int? userId;
      if (userData != null && userData['id'] != null) {
        userId = int.tryParse(userData['id'].toString());
      }

      print('🔵 [ProfileBloc] Token: ${token?.substring(0, 10)}..., UserId: $userId');

      if (token == null || userId == null) {
        print('🔴 [ProfileBloc] No auth data for loading ads');
        emit(MyAdsLoaded(ads: [], totalCount: 0, pages: 0));
        return;
      }

      print('🔵 [ProfileBloc] Calling API getMyAds...');
      final result = await _apiRepository.getMyAds(
        token: token,
        userId: userId,
        page: event.page,
        sorting: event.sorting,
      );

      print('🔵 [ProfileBloc] API result: ${result['status']}, count: ${result['count']}');
      print('🔵 [ProfileBloc] Ads data length: ${(result['data'] as List?)?.length ?? 0}');

      if (result['status'] == true) {
        final ads = List.from(result['data'] ?? []); // Создаем новый список
        print('✅ [ProfileBloc] Emitting MyAdsLoaded with ${ads.length} ads');
        
        // Логируем первое объявление для проверки
        if (ads.isNotEmpty) {
          print('🔵 [ProfileBloc] First ad: ${ads[0]}');
        }
        
        emit(MyAdsLoaded(
          ads: ads,
          totalCount: result['count'] ?? 0,
          pages: result['pages'] ?? 0,
        ));
      } else {
        print('🔴 [ProfileBloc] Failed to load ads: ${result['error']}');
        emit(MyAdsLoaded(ads: [], totalCount: 0, pages: 0));
      }
    } catch (e, stackTrace) {
      print('🔴 [ProfileBloc] Error loading my ads: $e');
      print('🔴 [ProfileBloc] Stack trace: $stackTrace');
      emit(MyAdsLoaded(ads: [], totalCount: 0, pages: 0));
    }
  }

  Future<void> _onToggleSubscribe(
    ToggleSubscribe event,
    Emitter<ProfileStateOld> emit,
  ) async {
    try {
      print('🔵 [ProfileBloc] Toggling subscribe to user: ${event.userIdTo}');
      
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user');
      
      int? userId;
      if (userData != null && userData['id'] != null) {
        userId = int.tryParse(userData['id'].toString());
      }

      if (token == null || userId == null) {
        print('🔴 [ProfileBloc] No auth data for subscribe');
        emit(ProfileError('Необходима авторизация'));
        return;
      }

      final result = await _apiRepository.toggleSubscribe(
        token: token,
        userIdFrom: userId,
        userIdTo: event.userIdTo,
      );

      // API возвращает {'success': true, 'status': 'added'/'deleted', 'count': 2}
      if (result['success'] == true) {
        final subscribeStatus = result['status'] as String? ?? 'added';
        final count = result['count'] as int? ?? 0;
        print('✅ [ProfileBloc] Subscribe toggled: $subscribeStatus, count: $count');
        emit(SubscribeToggled(status: subscribeStatus, count: count));
      } else {
        print('🔴 [ProfileBloc] Failed to toggle subscribe');
        emit(ProfileError(result['error'] ?? 'Ошибка подписки'));
      }
    } catch (e, stackTrace) {
      print('🔴 [ProfileBloc] Error toggling subscribe: $e');
      print('🔴 [ProfileBloc] Stack trace: $stackTrace');
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onLoadSubscriptions(
    LoadSubscriptions event,
    Emitter<ProfileStateOld> emit,
  ) async {
    emit(ProfileLoading());
    
    try {
      print('🔵 [ProfileBloc] Loading subscriptions');
      
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user');
      
      int? userId;
      if (userData != null && userData['id'] != null) {
        userId = int.tryParse(userData['id'].toString());
      }

      if (token == null || userId == null) {
        print('🔴 [ProfileBloc] No auth data for subscriptions');
        emit(ProfileError('Необходима авторизация'));
        return;
      }

      final result = await _apiRepository.getSubscriptions(
        token: token,
        userId: userId,
      );

      if (result['status'] == true) {
        final subscriptions = result['data'] as List? ?? [];
        print('✅ [ProfileBloc] Loaded ${subscriptions.length} subscriptions');
        emit(SubscriptionsLoaded(subscriptions));
      } else {
        print('🔴 [ProfileBloc] Failed to load subscriptions');
        emit(ProfileError(result['error'] ?? 'Ошибка загрузки подписок'));
      }
    } catch (e, stackTrace) {
      print('🔴 [ProfileBloc] Error loading subscriptions: $e');
      print('🔴 [ProfileBloc] Stack trace: $stackTrace');
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onDeleteSubscription(
    DeleteSubscription event,
    Emitter<ProfileStateOld> emit,
  ) async {
    try {
      print('🔵 [ProfileBloc] Deleting subscription: ${event.subscriptionId}');
      
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user');
      
      int? userId;
      if (userData != null && userData['id'] != null) {
        userId = int.tryParse(userData['id'].toString());
      }

      if (token == null || userId == null) {
        print('🔴 [ProfileBloc] No auth data for delete subscription');
        emit(ProfileError('Необходима авторизация'));
        return;
      }

      final result = await _apiRepository.deleteSubscription(
        token: token,
        userId: userId,
        subscriptionId: event.subscriptionId,
      );

      if (result['status'] == true) {
        print('✅ [ProfileBloc] Subscription deleted');
        // Перезагружаем список подписок
        add(LoadSubscriptions());
      } else {
        print('🔴 [ProfileBloc] Failed to delete subscription');
        emit(ProfileError(result['error'] ?? 'Ошибка удаления подписки'));
      }
    } catch (e, stackTrace) {
      print('🔴 [ProfileBloc] Error deleting subscription: $e');
      print('🔴 [ProfileBloc] Stack trace: $stackTrace');
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onLoadBlacklist(
    LoadBlacklist event,
    Emitter<ProfileStateOld> emit,
  ) async {
    emit(ProfileLoading());
    
    try {
      print('🔵 [ProfileBloc] Loading blacklist');
      
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user');
      
      print('🔵 [ProfileBloc] Token exists: ${token != null}');
      print('🔵 [ProfileBloc] User data exists: ${userData != null}');
      
      int? userId;
      if (userData != null && userData['id'] != null) {
        userId = int.tryParse(userData['id'].toString());
        print('🔵 [ProfileBloc] Parsed userId: $userId');
      }

      if (token == null || userId == null) {
        print('🔴 [ProfileBloc] No auth data for blacklist - token: $token, userId: $userId');
        emit(ProfileError('Необходима авторизация'));
        return;
      }

      print('🔵 [ProfileBloc] Calling API with userId: $userId, token: ${token.substring(0, 10)}...');
      
      final result = await _apiRepository.getBlacklist(
        token: token,
        userId: userId,
      );

      print('🔵 [ProfileBloc] API result: ${result['status']}');
      print('🔵 [ProfileBloc] API data: ${result['data']}');
      print('🔵 [ProfileBloc] API error: ${result['error']}');

      if (result['status'] == true) {
        final blacklist = result['data'] as List? ?? [];
        print('✅ [ProfileBloc] Loaded ${blacklist.length} blocked users');
        emit(BlacklistLoaded(blacklist));
      } else {
        print('🔴 [ProfileBloc] Failed to load blacklist: ${result['error']}');
        emit(ProfileError(result['error'] ?? 'Ошибка загрузки черного списка'));
      }
    } catch (e, stackTrace) {
      print('🔴 [ProfileBloc] Error loading blacklist: $e');
      print('🔴 [ProfileBloc] Stack trace: $stackTrace');
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onUnblockUser(
    UnblockUser event,
    Emitter<ProfileStateOld> emit,
  ) async {
    try {
      print('🔵 [ProfileBloc] Unblocking user: ${event.blacklistId}');
      
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user');
      
      int? userId;
      if (userData != null && userData['id'] != null) {
        userId = int.tryParse(userData['id'].toString());
      }

      if (token == null || userId == null) {
        print('🔴 [ProfileBloc] No auth data for unblock');
        emit(ProfileError('Необходима авторизация'));
        return;
      }

      final result = await _apiRepository.unblockUser(
        token: token,
        userId: userId,
        blacklistId: event.blacklistId,
      );

      if (result['status'] == true) {
        print('✅ [ProfileBloc] User unblocked');
        // Перезагружаем список черного списка
        add(LoadBlacklist());
      } else {
        print('🔴 [ProfileBloc] Failed to unblock user');
        emit(ProfileError(result['error'] ?? 'Ошибка разблокировки'));
      }
    } catch (e, stackTrace) {
      print('🔴 [ProfileBloc] Error unblocking user: $e');
      print('🔴 [ProfileBloc] Stack trace: $stackTrace');
      emit(ProfileError(e.toString()));
    }
  }

  Future<void> _onChangePassword(
    ChangePassword event,
    Emitter<ProfileStateOld> emit,
  ) async {
    try {
      print('🔵 [ProfileBloc] Changing password');
      
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user');
      
      int? userId;
      if (userData != null && userData['id'] != null) {
        userId = int.tryParse(userData['id'].toString());
      }

      if (token == null || userId == null) {
        print('🔴 [ProfileBloc] No auth data for password change');
        emit(ProfileError('Необходима авторизация'));
        return;
      }

      emit(ProfileLoading());

      final result = await _apiRepository.changePassword(
        token: token,
        userId: userId,
        currentPassword: event.currentPassword,
        newPassword: event.newPassword,
      );

      if (result['status'] == true) {
        print('✅ [ProfileBloc] Password changed successfully');
        emit(PasswordChanged());
      } else {
        print('🔴 [ProfileBloc] Failed to change password');
        emit(ProfileError(result['error'] ?? 'Ошибка смены пароля'));
      }
    } catch (e, stackTrace) {
      print('🔴 [ProfileBloc] Error changing password: $e');
      print('🔴 [ProfileBloc] Stack trace: $stackTrace');
      emit(ProfileError(e.toString()));
    }
  }
}
