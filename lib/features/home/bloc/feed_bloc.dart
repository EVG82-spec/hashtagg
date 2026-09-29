import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/network/home_api_repository.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

// ==================== КАТЕГОРИИ ====================

enum FeedCategory { recommendations, fresh, companies }

// ==================== СОБЫТИЯ ====================

sealed class FeedEvent {
  const FeedEvent();
}

class FeedCategoryChangeEvent extends FeedEvent {
  final FeedCategory category;
  const FeedCategoryChangeEvent({required this.category});
}

class FeedLoadMoreEvent extends FeedEvent {
  const FeedLoadMoreEvent();
}

class FeedLoadShopsEvent extends FeedEvent {
  const FeedLoadShopsEvent();
}

class FeedSearchShopsEvent extends FeedEvent {
  final String query;
  const FeedSearchShopsEvent({required this.query});
}

class LoadMoreShopsEvent extends FeedEvent {
  const LoadMoreShopsEvent();
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

  // 👇 НОВЫЕ ПОЛЯ для пагинации магазинов
  final int shopsCurrentPage;
  final bool shopsHasMore;
  final bool shopsIsLoadingMore;

  const FeedState({
    this.category = FeedCategory.recommendations,
    this.currentPage = 1,
    this.isLoadingMore = false,
    this.ads = const [],
    this.shops = const [],
    this.hasNext = false,
    this.shopsSearchQuery = '',
    this.shopsCurrentPage = 1,
    this.shopsHasMore = false,
    this.shopsIsLoadingMore = false,
  });

  FeedState copyWith({
    FeedCategory? category,
    int? currentPage,
    bool? isLoadingMore,
    List<FeedAd>? ads,
    List<Shop>? shops,
    bool? hasNext,
    String? shopsSearchQuery,
    int? shopsCurrentPage,
    bool? shopsHasMore,
    bool? shopsIsLoadingMore,
  }) {
    return FeedState(
      category: category ?? this.category,
      currentPage: currentPage ?? this.currentPage,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      ads: ads ?? this.ads,
      shops: shops ?? this.shops,
      hasNext: hasNext ?? this.hasNext,
      shopsSearchQuery: shopsSearchQuery ?? this.shopsSearchQuery,
      shopsCurrentPage: shopsCurrentPage ?? this.shopsCurrentPage,
      shopsHasMore: shopsHasMore ?? this.shopsHasMore,
      shopsIsLoadingMore: shopsIsLoadingMore ?? this.shopsIsLoadingMore,
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
    on<LoadMoreShopsEvent>(_onLoadMoreShops);
  }

  // ─────────────────────────────────────────────────
  // ПОИСК МАГАЗИНОВ
  // ─────────────────────────────────────────────────
  Future<void> _onSearchShops(
    FeedSearchShopsEvent event,
    Emitter<FeedState> emit,
  ) async {
    print('🟢🟢🟢 [_onSearchShops] CALLED: "${event.query}"'); // 👈
    try {
      print('🔍 [FeedBloc] Searching shops: "${event.query}"');

      // Сбрасываем пагинацию при новом поиске
      final result = await _repository.getShopsWithPagination(
        page: 1,
        search: event.query,
      );

      final shops = result['shops'] as List<Shop>;
      final hasMore = result['has_more'] as bool;

      print('✅ [FeedBloc] Found ${shops.length} shops, hasMore: $hasMore');

      emit(
        state.copyWith(
          shops: shops,
          shopsSearchQuery: event.query,
          shopsCurrentPage: 1,
          shopsHasMore: hasMore,
          shopsIsLoadingMore: false,
        ),
      );
    } catch (e) {
      print('❌ [FeedBloc] Error searching shops: $e');
    }
  }

  // Смена категории
  // ─────────────────────────────────────────────────
  // СМЕНА КАТЕГОРИИ
  // ─────────────────────────────────────────────────
  Future<void> _onCategoryChange(
    FeedCategoryChangeEvent event,
    Emitter<FeedState> emit,
  ) async {
    print('🔴🔴🔴 [_onCategoryChange] CALLED: ${event.category}'); // 👈
    if (event.category == FeedCategory.companies) {
      print('🔴🔴🔴 [_onCategoryChange] LOADING SHOPS...'); // 👈
      try {
        print('🔄 [FeedBloc] Loading shops (page 1)...');

        final result = await _repository.getShopsWithPagination(
          page: 1,
          search: '',
        );

        final shops = result['shops'] as List<Shop>;
        final hasMore = result['has_more'] as bool;

        print('✅ [FeedBloc] Loaded ${shops.length} shops, hasMore: $hasMore');

        emit(
          state.copyWith(
            category: event.category,
            shops: shops,
            shopsSearchQuery: '',
            shopsCurrentPage: 1,
            shopsHasMore: hasMore,
            shopsIsLoadingMore: false,
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

  // ─────────────────────────────────────────────────
  // ЗАГРУЗКА СЛЕДУЮЩЕЙ СТРАНИЦЫ МАГАЗИНОВ
  // ─────────────────────────────────────────────────
  Future<void> _onLoadMoreShops(
    LoadMoreShopsEvent event,
    Emitter<FeedState> emit,
  ) async {
    // Защита от повторных вызовов
    if (!state.shopsHasMore || state.shopsIsLoadingMore) {
      print(
        '⚠️ [FeedBloc] Skip loadMore: hasMore=${state.shopsHasMore}, isLoading=${state.shopsIsLoadingMore}',
      );
      return;
    }

    emit(state.copyWith(shopsIsLoadingMore: true));

    try {
      final nextPage = state.shopsCurrentPage + 1;
      print('🔄 [FeedBloc] Loading shops page $nextPage...');

      final result = await _repository.getShopsWithPagination(
        page: nextPage,
        search: state.shopsSearchQuery,
      );

      final newShops = result['shops'] as List<Shop>;
      final hasMore = result['has_more'] as bool;

      print(
        '✅ [FeedBloc] Loaded ${newShops.length} more shops, hasMore: $hasMore',
      );

      emit(
        state.copyWith(
          shops: [...state.shops, ...newShops], // append
          shopsCurrentPage: nextPage,
          shopsHasMore: hasMore,
          shopsIsLoadingMore: false,
        ),
      );
    } catch (e) {
      print('❌ [FeedBloc] Error loading more shops: $e');
      emit(state.copyWith(shopsIsLoadingMore: false));
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
  // Загрузка магазинов (для вкладки "Компании")
  void _onLoadShops(FeedLoadShopsEvent event, Emitter<FeedState> emit) async {
    try {
      final result = await _repository.getShopsWithPagination(
        page: 1,
        search: '',
      );

      final shops = result['shops'] as List<Shop>;
      final hasMore = result['has_more'] as bool;

      emit(
        state.copyWith(
          shops: shops,
          shopsCurrentPage: 1,
          shopsHasMore: hasMore,
        ),
      );
    } catch (e) {
      print('❌ [FeedBloc] Error loading shops: $e');
    }
  }
}
