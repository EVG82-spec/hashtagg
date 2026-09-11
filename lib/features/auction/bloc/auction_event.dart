import 'package:equatable/equatable.dart';

abstract class AuctionEvent extends Equatable {
  const AuctionEvent();

  @override
  List<Object?> get props => [];
}

class LoadAuctionStatus extends AuctionEvent {
  final int shopId;
  final bool forceRefresh;

  const LoadAuctionStatus({required this.shopId, this.forceRefresh = false});

  @override
  List<Object?> get props => [shopId, forceRefresh];
}

class PlaceBid extends AuctionEvent {
  final int shopId;
  final int targetPlace;

  const PlaceBid({required this.shopId, required this.targetPlace});

  @override
  List<Object?> get props => [shopId, targetPlace];
}

class ActivateParticipation extends AuctionEvent {
  final int shopId;

  const ActivateParticipation({required this.shopId});

  @override
  List<Object?> get props => [shopId];
}

class SaveAutoSettings extends AuctionEvent {
  final int shopId;
  final bool isEnabled;
  final double dailyLimit;
  final int bidIntervalMinutes;

  const SaveAutoSettings({
    required this.shopId,
    required this.isEnabled,
    required this.dailyLimit,
    required this.bidIntervalMinutes,
  });

  @override
  List<Object?> get props => [
    shopId,
    isEnabled,
    dailyLimit,
    bidIntervalMinutes,
  ];
}

class StartAutoUpdate extends AuctionEvent {
  final int shopId;
  const StartAutoUpdate({required this.shopId});

  @override
  List<Object?> get props => [shopId];
}

class StopAutoUpdate extends AuctionEvent {
  const StopAutoUpdate();
}

class AuctionTick extends AuctionEvent {
  final int shopId;
  const AuctionTick({required this.shopId});

  @override
  List<Object?> get props => [shopId];
}
