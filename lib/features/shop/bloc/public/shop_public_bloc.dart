import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';
import 'shop_public_event.dart';
import 'shop_public_state.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class ShopPublicBloc extends Bloc<ShopPublicEvent, ShopPublicState> {
  final ShopApiRepository _repository;

  ShopPublicBloc(this._repository) : super(ShopPublicInitial()) {
    on<LoadPublicShop>(_onLoadPublicShop);
  }

  Future<void> _onLoadPublicShop(
      LoadPublicShop event,
      Emitter<ShopPublicState> emit,
      ) async {
    // 👇 ДОБАВЬ ЭТИ ЛОГИ
    print('🔄🔄🔄 [ShopPublicBloc] LOADING shop: ${event.shopId}');

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

      print('📡 [ShopPublicBloc] Calling API for ads...');
      final ads = await _repository.getShopAds(shopId: event.shopId);
      print('✅ [ShopPublicBloc] Ads loaded: ${ads.length}');

      emit(ShopPublicLoaded(shop, ads: ads));
    } catch (e) {
      print('❌❌❌ [ShopPublicBloc] ERROR: $e');
      emit(ShopPublicError(e.toString()));
    }
  }
}