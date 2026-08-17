import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/shared/domain/entities/listing.dart';
import 'package:hive/hive.dart';
import 'package:hashtagg/core/network/favorites_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';

abstract class FavoritesEvent {}

class AddFavorite extends FavoritesEvent {
  final int id;
  final Listing listing;
  AddFavorite(this.id, this.listing);
}

class RemoveFavorite extends FavoritesEvent {
  final int id;
  RemoveFavorite(this.id);
}

class LoadFavorites extends FavoritesEvent {}

class LoadFavoritesFromServer extends FavoritesEvent {}

class ClearLocalFavorites extends FavoritesEvent {}

class FavoritesState {
  final Set<int> ids;
  final Map<int, Listing> listings;
  final bool isLoading;

  FavoritesState(this.ids, this.listings, {this.isLoading = false});

  List<Listing> get favoriteListings =>
      ids.map((id) => listings[id]).whereType<Listing>().toList();
}

class FavoritesBloc extends Bloc<FavoritesEvent, FavoritesState> {
  late Box _localFavoritesBox;  // Локальное хранилище (для неавторизованных)
  late Box _remoteFavoritesBox; // Удаленное хранилище (для авторизованных)
  late FavoritesApiRepository _apiRepository;
  final AuthBloc? _authBloc;

  FavoritesBloc({AuthBloc? authBloc}) : _authBloc = authBloc, super(FavoritesState({}, {}, isLoading: false)) {
    _updateRepository();
    
    on<LoadFavorites>(_onLoadFavorites);
    on<LoadFavoritesFromServer>(_onLoadFavoritesFromServer);
    on<AddFavorite>(_onAddFavorite);
    on<RemoveFavorite>(_onRemoveFavorite);
    on<ClearLocalFavorites>(_onClearLocalFavorites);

    add(LoadFavorites());
    
    // Слушаем изменения состояния авторизации
    _authBloc?.stream.listen((authState) {
      if (authState is Authenticated) {
        print('🔵 [FavoritesBloc] User authenticated - switching to remote favorites');
        add(LoadFavoritesFromServer());
      } else if (authState is Unauthenticated) {
        print('🔵 [FavoritesBloc] User logged out - switching to local favorites');
        add(LoadFavorites());
      }
    });
  }
  
  void _updateRepository() {
    final user = _authBloc?.state.user;
    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;
    _apiRepository = FavoritesApiRepository(
      DioClient.createDio(),
      userId: user?.id,
      token: token,
    );
  }

  Map<String, dynamic> _listingToMap(Listing listing) {
    return {
      'id': listing.id,
      'title': listing.title,
      'location': listing.location,
      'views': listing.views,
      'publishedAt': listing.publishedAt,
      'price': listing.price,
      'currency': listing.currency,
      'description': listing.description,
      'status': listing.status.index,
      'userId': listing.userId,
      'images': listing.images,
    };
  }

  Listing _mapToListing(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    return Listing(
      id: map['id'] as int?,
      title: (map['title'] as String?) ?? '',
      location: map['location'] as String?,
      views: map['views'] as int?,
      publishedAt: map['publishedAt'] as String?,
      price: map['price'] as int?,
      description: (map['description'] as String?) ?? '',
      status: map['status'] != null
          ? ListingStatus.values[map['status'] as int]
          : ListingStatus.active,
      userId: map['userId'] as int?,
      images: map['images'] != null ? List<String>.from(map['images']) : null,
    );
  }

  Future<void> _onLoadFavorites(
    LoadFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    // Открываем оба хранилища
    _localFavoritesBox = await Hive.openBox('favorites_local');
    _remoteFavoritesBox = await Hive.openBox('favorites_remote');

    // Проверяем авторизацию по наличию user и token
    final user = _authBloc?.state.user;
    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;
    final isAuthenticated = user != null && token != null && token.isNotEmpty;
    
    Box activeBox;
    String storageType;
    
    if (isAuthenticated) {
      // Используем удаленное хранилище
      activeBox = _remoteFavoritesBox;
      storageType = 'remote';
      print('🔵 [FavoritesBloc] Loading from remote storage (user: ${user!.id})');
    } else {
      // Используем локальное хранилище
      activeBox = _localFavoritesBox;
      storageType = 'local';
      print('🔵 [FavoritesBloc] Loading from local storage');
    }

    final List<int>? storedIds = (activeBox.get('items') as List?)?.cast<int>();
    final dynamic rawListings = activeBox.get('listings');
    final Map<int, Listing> listingsMap = {};

    if (rawListings != null) {
      final map = Map<dynamic, dynamic>.from(rawListings as Map);
      for (final entry in map.entries) {
        final id = entry.key as int;
        listingsMap[id] = _mapToListing(entry.value);
      }
    }

    print('🔵 [FavoritesBloc] Loaded ${storedIds?.length ?? 0} favorites from $storageType storage');
    emit(FavoritesState(storedIds?.toSet() ?? {}, listingsMap));
    
    // Автоматически загружаем с сервера только если пользователь авторизован
    if (isAuthenticated) {
      print('🔵 [FavoritesBloc] User is authenticated - loading from server');
      add(LoadFavoritesFromServer());
    }
  }

  Future<void> _onLoadFavoritesFromServer(
    LoadFavoritesFromServer event,
    Emitter<FavoritesState> emit,
  ) async {
    print('🔵 [FavoritesBloc] Loading favorites from server...');
    
    // Обновляем repository с актуальным токеном
    _updateRepository();
    
    emit(FavoritesState(state.ids, state.listings, isLoading: true));
    
    final apiResult = await _apiRepository.getFavoritesWithData();
    
    if (apiResult.success && apiResult.data != null) {
      final serverFavorites = apiResult.data!;
      final newIds = <int>{};
      final newListings = <int, Listing>{};
      
      for (final item in serverFavorites) {
        final id = _parseInt(item['ads_id']); // API возвращает ads_id, а не id
        if (id > 0) {
          newIds.add(id);
          
          // Парсим данные объявления
          final images = item['ads_images'] != null 
              ? (item['ads_images'] is List 
                  ? List<String>.from(item['ads_images']) 
                  : [item['ads_images'].toString()])
              : <String>[];
          
          newListings[id] = Listing(
            id: id,
            title: item['ads_title']?.toString() ?? '',
            price: _parseInt(item['ads_price']?['now']?.toString().replaceAll(RegExp(r'[^\d]'), '')),
            location: item['city_name']?.toString(),
            description: item['ads_text']?.toString() ?? '',
            views: _parseInt(item['count_view']),
            publishedAt: item['ads_datetime_add']?.toString(),
            status: ListingStatus.active,
            userId: _parseInt(item['clients_id']),
            images: images,
          );
        }
      }
      
      // Сохраняем в удаленное хранилище
      final serialized = {
        for (final entry in newListings.entries)
          entry.key: _listingToMap(entry.value),
      };

      await _remoteFavoritesBox.put('items', newIds.toList());
      await _remoteFavoritesBox.put('listings', serialized);
      
      print('✅ [FavoritesBloc] Loaded ${newIds.length} favorites from server');
      emit(FavoritesState(newIds, newListings, isLoading: false));
    } else {
      print('🔴 [FavoritesBloc] Failed to load from server: ${apiResult.error}');
      emit(FavoritesState(state.ids, state.listings, isLoading: false));
    }
  }

  Future<void> _onAddFavorite(
    AddFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    print('🔵 [FavoritesBloc] Adding favorite: ${event.id}');
    
    // Проверяем авторизацию по наличию user и token (как в listing_bloc)
    final user = _authBloc?.state.user;
    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;
    
    print('🔵 [FavoritesBloc] Auth check:');
    print('  - user: ${user?.id}');
    print('  - token present: ${token != null && token.isNotEmpty}');
    
    final isAuthenticated = user != null && token != null && token.isNotEmpty;
    
    // Определяем активное хранилище
    final activeBox = isAuthenticated ? _remoteFavoritesBox : _localFavoritesBox;
    final storageType = isAuthenticated ? 'remote' : 'local';
    
    if (isAuthenticated) {
      print('🔵 [FavoritesBloc] User authenticated (${user!.id}) - adding to server');
      // Обновляем repository с актуальным токеном
      _updateRepository();
      
      // Если авторизован - отправляем на API
      final apiResult = await _apiRepository.toggleFavorite(event.id);
      
      print('🔵 [FavoritesBloc] API result: success=${apiResult.success}, error=${apiResult.error}');
      
      if (!apiResult.success) {
        print('🔴 [FavoritesBloc] Failed to add favorite to API: ${apiResult.error}');
        // НЕ прерываем выполнение - продолжаем сохранять локально
      }
    } else {
      print('🔵 [FavoritesBloc] User not authenticated - saving to local storage only');
    }
    
    // Сохраняем в соответствующее хранилище
    final newIds = Set<int>.from(state.ids)..add(event.id);
    final newListings = Map<int, Listing>.from(state.listings)
      ..[event.id] = event.listing;

    final serialized = {
      for (final entry in newListings.entries)
        entry.key: _listingToMap(entry.value),
    };

    await activeBox.put('items', newIds.toList());
    await activeBox.put('listings', serialized);

    print('🔵 [FavoritesBloc] Favorite added to $storageType storage. Total: ${newIds.length}');
    emit(FavoritesState(newIds, newListings, isLoading: false));
  }

  Future<void> _onRemoveFavorite(
    RemoveFavorite event,
    Emitter<FavoritesState> emit,
  ) async {
    print('🔵 [FavoritesBloc] Removing favorite: ${event.id}');
    
    // Проверяем авторизацию по наличию user и token (как в listing_bloc)
    final user = _authBloc?.state.user;
    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;
    
    print('🔵 [FavoritesBloc] Auth check:');
    print('  - user: ${user?.id}');
    print('  - token present: ${token != null && token.isNotEmpty}');
    
    final isAuthenticated = user != null && token != null && token.isNotEmpty;
    
    // Определяем активное хранилище
    final activeBox = isAuthenticated ? _remoteFavoritesBox : _localFavoritesBox;
    final storageType = isAuthenticated ? 'remote' : 'local';
    
    if (isAuthenticated) {
      print('🔵 [FavoritesBloc] User authenticated (${user!.id}) - removing from server');
      // Обновляем repository с актуальным токеном
      _updateRepository();
      
      // Если авторизован - отправляем на API
      final apiResult = await _apiRepository.toggleFavorite(event.id);
      
      print('🔵 [FavoritesBloc] API result: success=${apiResult.success}, error=${apiResult.error}');
      
      if (!apiResult.success) {
        print('🔴 [FavoritesBloc] Failed to remove favorite from API: ${apiResult.error}');
        // НЕ прерываем выполнение - продолжаем удалять локально
      }
    } else {
      print('🔵 [FavoritesBloc] User not authenticated - removing from local storage only');
    }
    
    // Удаляем из соответствующего хранилища
    final newIds = Set<int>.from(state.ids)..remove(event.id);
    final newListings = Map<int, Listing>.from(state.listings)
      ..remove(event.id);

    final serialized = {
      for (final entry in newListings.entries)
        entry.key: _listingToMap(entry.value),
    };

    await activeBox.put('items', newIds.toList());
    await activeBox.put('listings', serialized);

    print('🔵 [FavoritesBloc] Favorite removed from $storageType storage. Total: ${newIds.length}');
    emit(FavoritesState(newIds, newListings, isLoading: false));
  }

  Future<void> _onClearLocalFavorites(
    ClearLocalFavorites event,
    Emitter<FavoritesState> emit,
  ) async {
    print('🔵 [FavoritesBloc] Clearing local favorites (keeping them in local storage)');
    
    // Обновляем repository с новым токеном
    _updateRepository();
    
    // НЕ очищаем локальное хранилище - оно сохраняется для будущего использования
    // Просто эмитим пустое состояние и загружаем с сервера
    emit(FavoritesState({}, {}, isLoading: false));
    
    // Загружаем с сервера
    add(LoadFavoritesFromServer());
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
