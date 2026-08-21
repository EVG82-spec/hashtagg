import 'package:equatable/equatable.dart';

abstract class ShopPublicEvent extends Equatable {
  const ShopPublicEvent();

  @override
  List<Object?> get props => [];
}

class LoadPublicShop extends ShopPublicEvent {
  final String shopId;
  final bool forceRefresh;
  final int? categoryId; // 👈 ДОБАВЛЯЕМ

  const LoadPublicShop({
    required this.shopId,
    this.forceRefresh = false,
    this.categoryId, // 👈 ДОБАВЛЯЕМ
  });

  @override
  List<Object?> get props => [shopId, forceRefresh, categoryId];
}
