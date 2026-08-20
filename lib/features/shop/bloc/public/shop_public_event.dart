import 'package:equatable/equatable.dart';

abstract class ShopPublicEvent extends Equatable {
  const ShopPublicEvent();

  @override
  List<Object?> get props => [];
}

class LoadPublicShop extends ShopPublicEvent {
  final String shopId;
  final bool forceRefresh; // 👈 ДОБАВИТЬ

  const LoadPublicShop({
    required this.shopId,
    this.forceRefresh = false, // 👈 ПО УМОЛЧАНИЮ false
  });

  @override
  List<Object?> get props => [shopId];
}
