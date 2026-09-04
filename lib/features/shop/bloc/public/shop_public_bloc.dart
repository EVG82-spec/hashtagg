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
      print('✅ [ShopPublicBloc] Shop loaded: ${shop.title}');
      print('📊 [ShopPublicBloc] Shop ID: ${shop.id}, UserId: ${shop.userId}');
      print('📄 [ShopPublicBloc] Status: ${shop.status}');

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

      emit(ShopPublicLoaded(shop, ads: ads, tariff: tariff));
    } catch (e) {
      print('❌❌❌ [ShopPublicBloc] ERROR: $e');
      emit(ShopPublicError(e.toString()));
    }
  }
}
