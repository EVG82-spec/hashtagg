import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../repository/auction_api_repository.dart';
import 'auction_event.dart';
import 'auction_state.dart';

class AuctionBloc extends Bloc<AuctionEvent, AuctionState> {
  final AuctionApiRepository repository;

  Timer? _autoUpdateTimer;
  int _currentShopId = 0;

  AuctionBloc({required this.repository}) : super(AuctionInitial()) {
    on<LoadAuctionStatus>(_onLoadStatus);
    on<PlaceBid>(_onPlaceBid);
    on<ActivateParticipation>(_onActivate);
    on<SaveAutoSettings>(_onSaveAutoSettings);
    on<StartAutoUpdate>(_onStartAutoUpdate);
    on<StopAutoUpdate>(_onStopAutoUpdate);
    on<AuctionTick>(_onTick);
  }

  Future<void> _onLoadStatus(
    LoadAuctionStatus event,
    Emitter<AuctionState> emit,
  ) async {
    if (state is! AuctionLoaded) {
      emit(AuctionLoading());
    }

    try {
      final status = await repository.getStatus(shopId: event.shopId);
      _currentShopId = event.shopId;
      emit(AuctionLoaded(status: status));
    } catch (e) {
      print('❌ [AuctionBloc] Load error: $e');
      emit(AuctionError(e.toString()));
    }
  }

  Future<void> _onPlaceBid(PlaceBid event, Emitter<AuctionState> emit) async {
    if (state is! AuctionLoaded) return;
    final currentState = state as AuctionLoaded;

    // Оптимистичное обновление
    emit(currentState.copyWith(isBidding: true, errorMessage: null));

    try {
      final response = await repository.placeBid(
        shopId: event.shopId,
        targetPlace: event.targetPlace,
      );

      if (response['success'] == true) {
        // Перезагружаем данные
        final status = await repository.getStatus(shopId: event.shopId);
        emit(AuctionLoaded(status: status));
      } else {
        emit(
          currentState.copyWith(
            isBidding: false,
            errorMessage: response['message']?.toString() ?? 'Ошибка ставки',
          ),
        );
      }
    } catch (e) {
      print('❌ [AuctionBloc] PlaceBid error: $e');
      emit(
        currentState.copyWith(
          isBidding: false,
          errorMessage: 'Ошибка соединения',
        ),
      );
    }
  }

  Future<void> _onActivate(
    ActivateParticipation event,
    Emitter<AuctionState> emit,
  ) async {
    try {
      final response = await repository.activateParticipation(
        shopId: event.shopId,
      );

      if (response['success'] == true) {
        final status = await repository.getStatus(shopId: event.shopId);
        emit(AuctionLoaded(status: status));
      } else {
        if (state is AuctionLoaded) {
          emit(
            (state as AuctionLoaded).copyWith(
              errorMessage:
                  response['message']?.toString() ?? 'Ошибка активации',
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [AuctionBloc] Activate error: $e');
    }
  }

  Future<void> _onSaveAutoSettings(
    SaveAutoSettings event,
    Emitter<AuctionState> emit,
  ) async {
    try {
      final response = await repository.saveAutoSettings(
        shopId: event.shopId,
        isEnabled: event.isEnabled,
        dailyLimit: event.dailyLimit,
        bidIntervalMinutes: event.bidIntervalMinutes,
      );

      if (response['success'] == true) {
        final status = await repository.getStatus(shopId: event.shopId);
        emit(AuctionLoaded(status: status));
      } else {
        if (state is AuctionLoaded) {
          emit(
            (state as AuctionLoaded).copyWith(
              errorMessage:
                  response['message']?.toString() ?? 'Ошибка сохранения',
            ),
          );
        }
      }
    } catch (e) {
      print('❌ [AuctionBloc] SaveAutoSettings error: $e');
    }
  }

  void _onStartAutoUpdate(StartAutoUpdate event, Emitter<AuctionState> emit) {
    _autoUpdateTimer?.cancel();
    _currentShopId = event.shopId;
    _autoUpdateTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => add(AuctionTick(shopId: event.shopId)),
    );
  }

  void _onStopAutoUpdate(StopAutoUpdate event, Emitter<AuctionState> emit) {
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = null;
  }

  Future<void> _onTick(AuctionTick event, Emitter<AuctionState> emit) async {
    try {
      final status = await repository.getStatus(shopId: event.shopId);
      emit(AuctionLoaded(status: status));
    } catch (e) {
      print('❌ [AuctionBloc] Tick error: $e');
    }
  }

  @override
  Future<void> close() {
    _autoUpdateTimer?.cancel();
    return super.close();
  }
}
