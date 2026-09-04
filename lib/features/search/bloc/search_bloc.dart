//G:\hashtagg_app\lib\features\search\bloc\search_bloc.dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/network/catalog_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/core/network/home_api_repository.dart';

// Events
abstract class SearchEvent {}

class SearchAds extends SearchEvent {
  final CatalogSearchParams params;
  SearchAds(this.params);
}

class LoadMoreAds extends SearchEvent {}

// States
abstract class SearchState {}

class SearchInitial extends SearchState {}

class SearchLoading extends SearchState {}

class SearchLoaded extends SearchState {
  final List<FeedAd> ads;
  final String count;
  final int totalPages;
  final int currentPage;
  final bool hasMore;

  SearchLoaded({
    required this.ads,
    required this.count,
    required this.totalPages,
    required this.currentPage,
  }) : hasMore = currentPage < totalPages;
}

class SearchError extends SearchState {
  final String message;
  SearchError(this.message);
}

class SearchLoadingMore extends SearchState {
  final List<FeedAd> currentAds;
  SearchLoadingMore(this.currentAds);
}

// BLoC
class SearchBloc extends Bloc<SearchEvent, SearchState> {
  final CatalogApiRepository _repository;
  CatalogSearchParams? _lastParams;

  SearchBloc()
    : _repository = CatalogApiRepository(DioClient.createDio()),
      super(SearchInitial()) {
    on<SearchAds>(_onSearchAds);
    on<LoadMoreAds>(_onLoadMoreAds);
  }

  Future<void> _onSearchAds(SearchAds event, Emitter<SearchState> emit) async {
    emit(SearchLoading());
    _lastParams = event.params;

    final result = await _repository.getAds(event.params);

    if (result.success && result.data != null) {
      final data = result.data!;
      final ads = (data['data'] as List)
          .map((json) => FeedAd.fromJson(json))
          .toList();

      emit(
        SearchLoaded(
          ads: ads,
          count: data['count'] ?? '0',
          totalPages: data['pages'] ?? 0,
          currentPage: event.params.page,
        ),
      );
    } else {
      emit(SearchError(result.error ?? 'Failed to load ads'));
    }
  }

  Future<void> _onLoadMoreAds(
    LoadMoreAds event,
    Emitter<SearchState> emit,
  ) async {
    if (state is! SearchLoaded || _lastParams == null) return;

    final currentState = state as SearchLoaded;
    if (!currentState.hasMore) return;

    emit(SearchLoadingMore(currentState.ads));

    final nextPage = currentState.currentPage + 1;
    final newParams = CatalogSearchParams(
      categoryId: _lastParams!.categoryId,
      cityId: _lastParams!.cityId,
      regionId: _lastParams!.regionId,
      countryId: _lastParams!.countryId,
      search: _lastParams!.search,
      priceStart: _lastParams!.priceStart,
      priceEnd: _lastParams!.priceEnd,
      sorting: _lastParams!.sorting,
      page: nextPage,
      secure: _lastParams!.secure,
      vip: _lastParams!.vip,
      onlineView: _lastParams!.onlineView,
      auction: _lastParams!.auction,
      booking: _lastParams!.booking,
      filters: _lastParams!.filters,
    );

    final result = await _repository.getAds(newParams);

    if (result.success && result.data != null) {
      final data = result.data!;
      final newAds = (data['data'] as List)
          .map((json) => FeedAd.fromJson(json))
          .toList();

      emit(
        SearchLoaded(
          ads: [...currentState.ads, ...newAds],
          count: data['count'] ?? '0',
          totalPages: data['pages'] ?? 0,
          currentPage: nextPage,
        ),
      );
    } else {
      // Возвращаем предыдущее состояние при ошибке
      emit(currentState);
    }
  }
}
