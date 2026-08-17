import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/shared/application/usecase/favorite_usecase.dart';
import 'package:hashtagg/shared/application/usecase/unfavorite_usecase.dart';
import 'package:hashtagg/shared/domain/entities/listing.dart';
import 'package:hashtagg/shared/infrastructure/services/basic_listing_service.dart';
import 'package:hashtagg/core/network/listing_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hive/hive.dart';

sealed class ListingEvent {}

class ListingFavoriteEvent extends ListingEvent {}

class ListingUnfavoriteEvent extends ListingEvent {}

class LoadSimilarAds extends ListingEvent {
  final int listingId;
  LoadSimilarAds(this.listingId);
}

class ChangeAdStatus extends ListingEvent {
  final int adId;
  final int status; // 1=active, 5=sold, 8=delete, 3=archive
  ChangeAdStatus({required this.adId, required this.status});
}

class ListingState {
  final Listing listing;
  final bool isFavorite;
  final String? error;
  final List<Listing>? similarAds;
  final bool isLoadingSimilar;
  final bool isChangingStatus;

  ListingState({
    required this.listing,
    required this.isFavorite,
    this.error,
    this.similarAds,
    this.isLoadingSimilar = false,
    this.isChangingStatus = false,
  });

  factory ListingState.initial(Listing listing) {
    final box = Hive.box('favorites');
    final isFavorite = box.get(listing.id) == 1;
    return ListingState(listing: listing, isFavorite: isFavorite);
  }

  ListingState copyWith({
    Listing? listing,
    bool? isFavorite,
    String? error,
    List<Listing>? similarAds,
    bool? isLoadingSimilar,
    bool? isChangingStatus,
  }) {
    return ListingState(
      listing: listing ?? this.listing,
      isFavorite: isFavorite ?? this.isFavorite,
      error: error,
      similarAds: similarAds ?? this.similarAds,
      isLoadingSimilar: isLoadingSimilar ?? this.isLoadingSimilar,
      isChangingStatus: isChangingStatus ?? this.isChangingStatus,
    );
  }
}

class ListingBloc extends Bloc<ListingEvent, ListingState> {
  final AuthBloc? _authBloc;
  late ListingApiRepository _apiRepository;

  ListingBloc({required Listing listing, AuthBloc? authBloc})
    : _authBloc = authBloc,
      super(ListingState.initial(listing)) {
    _apiRepository = ListingApiRepository(DioClient.createDio());

    on<ListingFavoriteEvent>((event, emit) {
      FavoriteUseCase(BasicListingService()).execute(state.listing.id!);
      emit(state.copyWith(isFavorite: true));
    });

    on<ListingUnfavoriteEvent>((event, emit) {
      UnfavoriteUseCase(BasicListingService()).execute(state.listing.id!);
      emit(state.copyWith(isFavorite: false));
    });

    on<LoadSimilarAds>(_onLoadSimilarAds);
    on<ChangeAdStatus>(_onChangeAdStatus);
  }

  Future<void> reportListing({
    required int listingId,
    required String text,
  }) async {
    final user = _authBloc?.state.user;
    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;

    if (user == null || token == null) {
      emit(state.copyWith(error: 'Необходимо авторизоваться'));
      return;
    }

    final result = await _apiRepository.reportListing(
      userId: user.id,
      token: token,
      listingId: listingId,
      text: text,
    );

    if (result.success) {
      emit(state.copyWith(error: null));
    } else {
      emit(state.copyWith(error: result.error));
    }
  }

  Future<void> _onLoadSimilarAds(
    LoadSimilarAds event,
    Emitter<ListingState> emit,
  ) async {
    emit(state.copyWith(isLoadingSimilar: true));

    try {
      print('🔵 [ListingBloc] Loading similar ads for: ${event.listingId}');
      
      final result = await _apiRepository.getSimilarAds(
        listingId: event.listingId,
      );

      if (result.success && result.data != null) {
        print('✅ [ListingBloc] Loaded ${result.data!.length} similar ads');
        emit(state.copyWith(
          similarAds: result.data,
          isLoadingSimilar: false,
        ));
      } else {
        print('🔴 [ListingBloc] Failed to load similar ads: ${result.error}');
        emit(state.copyWith(
          isLoadingSimilar: false,
          error: result.error,
        ));
      }
    } catch (e) {
      print('🔴 [ListingBloc] Exception loading similar ads: $e');
      emit(state.copyWith(
        isLoadingSimilar: false,
        error: e.toString(),
      ));
    }
  }

  Future<void> _onChangeAdStatus(
    ChangeAdStatus event,
    Emitter<ListingState> emit,
  ) async {
    final user = _authBloc?.state.user;
    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;

    if (user == null || token == null) {
      emit(state.copyWith(error: 'Необходимо авторизоваться'));
      return;
    }

    emit(state.copyWith(isChangingStatus: true));

    try {
      print('🔵 [ListingBloc] Changing ad status: ${event.adId} to ${event.status}');
      
      final result = await _apiRepository.changeAdStatus(
        userId: user.id,
        token: token,
        adId: event.adId,
        status: event.status,
      );

      if (result.success) {
        print('✅ [ListingBloc] Ad status changed successfully');
        emit(state.copyWith(
          isChangingStatus: false,
          error: null,
        ));
      } else {
        print('🔴 [ListingBloc] Failed to change ad status: ${result.error}');
        emit(state.copyWith(
          isChangingStatus: false,
          error: result.error,
        ));
      }
    } catch (e) {
      print('🔴 [ListingBloc] Exception changing ad status: $e');
      emit(state.copyWith(
        isChangingStatus: false,
        error: e.toString(),
      ));
    }
  }
}
