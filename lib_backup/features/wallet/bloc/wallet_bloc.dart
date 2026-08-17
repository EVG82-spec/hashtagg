import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/network/wallet_api_repository.dart';

// ── События ──────────────────────────────────────────────────────────────────

abstract class WalletEvent {}

class LoadWalletHistory extends WalletEvent {
  final int userId;
  final String token;

  LoadWalletHistory({required this.userId, required this.token});
}

class InitiatePayment extends WalletEvent {
  final int userId;
  final String token;
  final double amount;
  final String codePayment;

  InitiatePayment({
    required this.userId,
    required this.token,
    required this.amount,
    required this.codePayment,
  });
}

class CheckPaymentStatus extends WalletEvent {
  final int userId;
  final String token;
  final int orderId;

  CheckPaymentStatus({
    required this.userId,
    required this.token,
    required this.orderId,
  });
}

// ── Состояния ────────────────────────────────────────────────────────────────

abstract class WalletState {}

class WalletInitial extends WalletState {}

class WalletLoading extends WalletState {}

class WalletHistoryLoaded extends WalletState {
  final List<Map<String, dynamic>> history;

  WalletHistoryLoaded(this.history);
}

class PaymentInitiated extends WalletState {
  final String paymentLink;
  final int orderId;

  PaymentInitiated({required this.paymentLink, required this.orderId});
}

class PaymentStatusChecked extends WalletState {
  final bool isPaid;

  PaymentStatusChecked(this.isPaid);
}

class WalletError extends WalletState {
  final String message;

  WalletError(this.message);
}

// ── BLoC ─────────────────────────────────────────────────────────────────────

class WalletBloc extends Bloc<WalletEvent, WalletState> {
  final WalletApiRepository _repository;

  // Публичный доступ к repository
  WalletApiRepository get repository => _repository;

  WalletBloc({WalletApiRepository? repository})
      : _repository = repository ?? WalletApiRepository(),
        super(WalletInitial()) {
    on<LoadWalletHistory>(_onLoadWalletHistory);
    on<InitiatePayment>(_onInitiatePayment);
    on<CheckPaymentStatus>(_onCheckPaymentStatus);
  }

  Future<void> _onLoadWalletHistory(
    LoadWalletHistory event,
    Emitter<WalletState> emit,
  ) async {
    print('🔵 [WalletBloc] Loading wallet history - userId: ${event.userId}');
    emit(WalletLoading());

    try {
      final result = await _repository.getHistory(
        userId: event.userId,
        token: event.token,
      );

      if (result['status'] == true) {
        final history = (result['data'] as List)
            .map((e) => e as Map<String, dynamic>)
            .toList();
        
        // Убеждаемся что новые записи сверху (если есть поле id или timestamp)
        // История уже должна приходить отсортированной с сервера (order by id desc)
        
        print('✅ [WalletBloc] History loaded: ${history.length} records');
        emit(WalletHistoryLoaded(history));
      } else {
        print('🔴 [WalletBloc] Failed to load history: ${result['error']}');
        emit(WalletError(result['error'] ?? 'Не удалось загрузить историю'));
      }
    } catch (e) {
      print('🔴 [WalletBloc] History error: $e');
      emit(WalletError('Ошибка загрузки истории: $e'));
    }
  }

  Future<void> _onInitiatePayment(
    InitiatePayment event,
    Emitter<WalletState> emit,
  ) async {
    print('🔵 [WalletBloc] Initiating payment - userId: ${event.userId}, amount: ${event.amount}');
    emit(WalletLoading());

    try {
      final result = await _repository.initPayment(
        userId: event.userId,
        token: event.token,
        amount: event.amount,
        codePayment: event.codePayment,
      );

      if (result['status'] == true) {
        print('✅ [WalletBloc] Payment initiated - link: ${result['link']}');
        emit(PaymentInitiated(
          paymentLink: result['link'],
          orderId: result['id_order'],
        ));
      } else {
        print('🔴 [WalletBloc] Failed to initiate payment: ${result['error']}');
        emit(WalletError(result['error'] ?? 'Не удалось инициировать платеж'));
      }
    } catch (e) {
      print('🔴 [WalletBloc] Payment initiation error: $e');
      emit(WalletError('Ошибка инициализации платежа: $e'));
    }
  }

  Future<void> _onCheckPaymentStatus(
    CheckPaymentStatus event,
    Emitter<WalletState> emit,
  ) async {
    print('🔵 [WalletBloc] Checking payment status - orderId: ${event.orderId}');

    try {
      final result = await _repository.checkPaymentStatus(
        userId: event.userId,
        token: event.token,
        orderId: event.orderId,
      );

      if (result['status'] == true) {
        final isPaid = result['is_paid'] == true;
        print(isPaid 
          ? '✅ [WalletBloc] Payment completed' 
          : '🔵 [WalletBloc] Payment not completed yet');
        emit(PaymentStatusChecked(isPaid));
      } else {
        print('🔴 [WalletBloc] Failed to check payment status: ${result['error']}');
        emit(WalletError(result['error'] ?? 'Не удалось проверить статус платежа'));
      }
    } catch (e) {
      print('🔴 [WalletBloc] Payment status check error: $e');
      emit(WalletError('Ошибка проверки статуса: $e'));
    }
  }
}
