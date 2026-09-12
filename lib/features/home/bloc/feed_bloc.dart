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

class FeedSearchShopsEvent extends FeedEvent {
  final String query;
  FeedSearchShopsEvent({required this.query});
}

// ==================== СОСТОЯНИЕ ====================

class FeedState {
  final FeedCategory category;
  final int currentPage;
  final bool isLoadingMore;
  final List<FeedAd> ads;
  final List<Shop> shops;
  final bool hasNext;
  final String shopsSearchQuery;

  const FeedState({
    this.category = FeedCategory.recommendations,
    this.currentPage = 1,
    this.isLoadingMore = false,
    this.ads = const [],
    this.shops = const [],
    this.hasNext = false,
    this.shopsSearchQuery = '',
  });

  FeedState copyWith({
    FeedCategory? category,
    int? currentPage,
    bool? isLoadingMore,
    List<FeedAd>? ads,
    List<Shop>? shops,
    bool? hasNext,
    String? shopsSearchQuery,
  }) {
    return FeedState(
      category: category ?? this.category,
      currentPage: currentPage ?? this.currentPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      ads: ads ?? this.ads,
      shops: shops ?? this.shops,
      hasNext: hasNext ?? this.hasNext,
      shopsSearchQuery: shopsSearchQuery ?? this.shopsSearchQuery,
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
    on<FeedSearchShopsEvent>(_onSearchShops);
  }

  // 👇 НОВЫЙ ОБРАБОТЧИК
  Future<void> _onSearchShops(
    FeedSearchShopsEvent event,
    Emitter<FeedState> emit,
  ) async {
    try {
      print('🔍 [FeedBloc] Searching shops: "${event.query}"');
      final shops = await _repository.getShops(search: event.query);
      print('✅ [FeedBloc] Found ${shops.length} shops');
      emit(state.copyWith(shops: shops, shopsSearchQuery: event.query));
    } catch (e) {
      print('❌ [FeedBloc] Error searching shops: $e');
    }
  }

  // Смена категории
  Future<void> _onCategoryChange(
    FeedCategoryChangeEvent event,
    Emitter<FeedState> emit,
  ) async {
    if (event.category == FeedCategory.companies) {
      try {
        print('🔄 [FeedBloc] Loading shops...');
        final shops = await _repository
            .getShops(); // ✅ без параметров или с search: ''
        print('✅ [FeedBloc] Loaded ${shops.length} shops');
        emit(
          state.copyWith(
            category: event.category,
            shops: shops,
            shopsSearchQuery: '', // сбрасываем поиск при смене вкладки
            ads: const [],
          ),
        );
      } catch (e) {
        print('❌ [FeedBloc] Error loading shops: $e');
      }
    } else {
      emit(
        state.copyWith(
          category: event.category,
          currentPage: 1,
          shops: const [],
        ),
      );
    }
  }

  // Загрузка следующих страниц
  void _onLoadMore(FeedLoadMoreEvent event, Emitter<FeedState> emit) {
    if (!state.hasNext) return;

    emit(
      state.copyWith(currentPage: state.currentPage + 1, isLoadingMore: true),
    );
  }

  // Загрузка магазинов (для вкладки "Компании")
  void _onLoadShops(FeedLoadShopsEvent event, Emitter<FeedState> emit) async {
    try {
      final shops = await _repository.getShops();
      emit(state.copyWith(shops: shops));
    } catch (e) {
      print('❌ [FeedBloc] Error loading shops: $e');
    }
  }
}
