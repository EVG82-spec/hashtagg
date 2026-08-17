import 'package:equatable/equatable.dart';

abstract class ShopPublicEvent extends Equatable {
  const ShopPublicEvent();

  @override
  List<Object?> get props => [];
}

class LoadPublicShop extends ShopPublicEvent {
  final String shopId;

  const LoadPublicShop({required this.shopId});

  @override
  List<Object?> get props => [shopId];
}