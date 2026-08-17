import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/network/home_api_repository.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

// ==================== КАТЕГОРИИ ====================

enum FeedCategory { recommendations, fresh, companies }

// ==================== СОБЫТИЯ ====================

sealed class FeedEvent {}

class FeedCategoryChangeEvent extends FeedEvent {
  final FeedCategory category;
  FeedCategoryChangeEvent({required this.category});
}

class FeedLoadMoreEvent extends FeedEvent {}

class FeedLoadShopsEvent extends FeedEvent {}

// ==================== СОСТОЯНИЕ ====================

class FeedState {
  final FeedCategory category;
  final int currentPage;
  final bool isLoadingMore;
  final List<FeedAd> ads;
  final List<Shop> shops;
  final bool hasNext;

  const FeedState({
    this.category = FeedCategory.recommendations,
    this.currentPage = 1,
    this.isLoadingMore = false,
    this.ads = const [],
    this.shops = const [],
    this.hasNext = false,
  });

  FeedState copyWith({
    FeedCategory? category,
    int? currentPage,
    bool? isLoadingMore,
    List<FeedAd>? ads,
    List<Shop>? shops,
    bool? hasNext,
  }) {
    return FeedState(
      category: category ?? this.category,
      currentPage: currentPage ?? this.currentPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      ads: ads ?? this.ads,
      shops: shops ?? this.shops,
      hasNext: hasNext ?? this.hasNext,
    );
  }
}

// ==================== BLOC ====================

class FeedBloc extends Bloc<FeedEvent, FeedState> {
  final ShopApiRepository _repository; // 👈 ДОБАВЛЕН РЕПОЗИТОРИЙ

  FeedBloc(this._repository) : super(const FeedState()) {
    on<FeedCategoryChangeEvent>(_onCategoryChange);
    on<FeedLoadMoreEvent>(_onLoadMore);
    on<FeedLoadShopsEvent>(_onLoadShops);
  }

  // Смена категории
  void _onCategoryChange(
      FeedCategoryChangeEvent event,
      Emitter<FeedState> emit,
      ) async {
    if (event.category == FeedCategory.companies) {
      try {
        print('🔄 [FeedBloc] Loading shops...');

        final shops = await _repository.getShops();

        print('✅ [FeedBloc] Loaded ${shops.length} shops from API');

        // Детальный лог каждого магазина из API
        for (var i = 0; i < shops.length; i++) {
          final shop = shops[i];
          print('   📦 Shop #$i:');
          print('      ID: ${shop.id}');
          print('      Title: ${shop.title}');
          print('      Logo: ${shop.logo}');
          print('      UserId: ${shop.userId}');
        }

        emit(state.copyWith(
          category: event.category,
          shops: shops,
          ads: const [],
        ));
      } catch (e) {
        print('❌ [FeedBloc] Error loading shops: $e');
      }
    } else {
      // Для других категорий - обычная лента
      emit(state.copyWith(
        category: event.category,
        currentPage: 1,
        shops: const [],
      ));
    }
  }

  // Загрузка следующих страниц
  void _onLoadMore(
      FeedLoadMoreEvent event,
      Emitter<FeedState> emit,
      ) {
    if (!state.hasNext) return;

    emit(state.copyWith(
      currentPage: state.currentPage + 1,
      isLoadingMore: true,
    ));
  }

  // Загрузка магазинов (для вкладки "Компании")
  void _onLoadShops(
      FeedLoadShopsEvent event,
      Emitter<FeedState> emit,
      ) async {
    try {
      final shops = await _repository.getShops();
      emit(state.copyWith(shops: shops));
    } catch (e) {
      print('❌ [FeedBloc] Error loading shops: $e');
    }
  }
}