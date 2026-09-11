import 'package:equatable/equatable.dart';
import '../models/auction_status.dart';

abstract class AuctionState extends Equatable {
  const AuctionState();

  @override
  List<Object?> get props => [];
}

class AuctionInitial extends AuctionState {}

class AuctionLoading extends AuctionState {}

class AuctionLoaded extends AuctionState {
  final AuctionStatus status;
  final bool isBidding;
  final String? errorMessage;

  const AuctionLoaded({
    required this.status,
    this.isBidding = false,
    this.errorMessage,
  });

  AuctionLoaded copyWith({
    AuctionStatus? status,
    bool? isBidding,
    String? errorMessage,
  }) {
    return AuctionLoaded(
      status: status ?? this.status,
      isBidding: isBidding ?? this.isBidding,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, isBidding, errorMessage];
}

class AuctionError extends AuctionState {
  final String message;
  const AuctionError(this.message);

  @override
  List<Object?> get props => [message];
}
