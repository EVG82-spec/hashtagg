import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';
import 'shop_public_event.dart';
import 'shop_public_state.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hive/hive.dart';

class ShopPublicBloc extends Bloc<ShopPublicEvent, ShopPublicState> {
  final ShopApiRepository _repository;

  ShopApiRepository get repository => _repository;

  ShopPublicBloc(this._repository) : super(ShopPublicInitial()) {
    on<LoadPublicShop>(_onLoadPublicShop);
  }

  Future<void> _onLoadPublicShop(
    LoadPublicShop event,
    Emitter<ShopPublicState> emit,
  ) async {
    print('🔄🔄🔄 [ShopPublicBloc] LOADING shop: ${event.shopId}');
    print('   forceRefresh: ${event.forceRefresh}');
    print('   categoryId: ${event.categoryId}');

    if (!event.forceRefresh && state is ShopPublicLoaded) {
      final currentState = state as ShopPublicLoaded;
      if (currentState.shop.id.toString() == event.shopId) {
        print('📦 [ShopPublicBloc] Using cached data');
        return;
      }
    }

    try {
      emit(ShopPublicLoading());

      if (event.shopId.isEmpty || event.shopId == '0') {
        print('❌ [ShopPublicBloc] Invalid shopId: ${event.shopId}');
        emit(ShopPublicError('Неверный ID магазина'));
        return;
      }

      print('📡 [ShopPublicBloc] Calling API for shop: ${event.shopId}');
      final shop = await _repository.getPublicShop(shopId: event.shopId);

      // ✅ ПОЛУЧАЕМ ID ТЕКУЩЕГО ПОЛЬЗОВАТЕЛЯ ИЗ HIVE
      final currentUserId = _getCurrentUserId();
      print('👤 [ShopPublicBloc] Current user ID: $currentUserId');
      print('🏪 [ShopPublicBloc] Shop owner ID: ${shop.userId}');

      // ✅ УСТАНАВЛИВАЕМ isOwner
      final isOwner = currentUserId == shop.userId;
      print('🔑 [ShopPublicBloc] isOwner: $isOwner');

      // ✅ ОБНОВЛЯЕМ SHOP С ПОЛЕМ isOwner
      final updatedShop = shop.copyWith(isOwner: isOwner);

      print('✅ [ShopPublicBloc] Shop loaded: ${updatedShop.title}');
      print(
        '📊 [ShopPublicBloc] Shop ID: ${updatedShop.id}, UserId: ${updatedShop.userId}',
      );
      print('📄 [ShopPublicBloc] Status: ${updatedShop.status}');
      print('🔑 [ShopPublicBloc] isOwner: ${updatedShop.isOwner}');

      print('📡 [ShopPublicBloc] Calling API for ads...');
      print('   categoryId: ${event.categoryId}');
      final ads = await _repository.getShopAds(
        shopId: event.shopId,
        categoryId: event.categoryId,
      );
      print('✅ [ShopPublicBloc] Ads loaded: ${ads.length}');

      // ✅ ЗАГРУЖАЕМ ТАРИФ
      UserTariff? tariff;
      if (shop.userId > 0) {
        print(
          '🔴🔴🔴 [ShopPublicBloc] Calling getUserTariff for userId: ${shop.userId}',
        );
        tariff = await _repository.getUserTariff(userId: shop.userId);
        print('📦📦📦 [ShopPublicBloc] TARIFF RECEIVED:');
        print('   name: ${tariff?.name}');
        print('   services: ${tariff?.services}');
        print('   has shop_links: ${tariff?.hasService('shop_links')}');
      }

      // ❌ УБИРАЕМ ГЕНЕРАЦИЮ QR-КОДА
      // QR-код будет показан через QrImageView в ShopQrWidget

      emit(ShopPublicLoaded(updatedShop, ads: ads, tariff: tariff));
    } catch (e) {
      print('❌❌❌ [ShopPublicBloc] ERROR: $e');
      emit(ShopPublicError(e.toString()));
    }
  }

  // ✅ МЕТОД ДЛЯ ПОЛУЧЕНИЯ ID ТЕКУЩЕГО ПОЛЬЗОВАТЕЛЯ
  int _getCurrentUserId() {
    try {
      final box = Hive.box('user');
      final userData = box.get('user') as Map?;
      if (userData != null) {
        final id = userData['id'];
        if (id is int) return id;
        if (id is String) return int.tryParse(id) ?? 0;
      }
      return 0;
    } catch (e) {
      print('❌ [ShopPublicBloc] Error getting user ID: $e');
      return 0;
    }
  }
}
