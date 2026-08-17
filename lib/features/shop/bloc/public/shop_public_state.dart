import 'package:equatable/equatable.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/core/network/home_api_repository.dart';

abstract class ShopPublicState extends Equatable {
  const ShopPublicState();

  @override
  List<Object?> get props => [];
}

class ShopPublicInitial extends ShopPublicState {}

class ShopPublicLoading extends ShopPublicState {}

class ShopPublicLoaded extends ShopPublicState {
  final Shop shop;
  final List<FeedAd> ads;

  const ShopPublicLoaded(this.shop, {this.ads = const []}); // 👈 ИСПРАВЛЕНО

  @override
  List<Object?> get props => [shop, ads];
}

class ShopPublicError extends ShopPublicState {
  final String message;
  const ShopPublicError(this.message);

  @override
  List<Object?> get props => [message];
}