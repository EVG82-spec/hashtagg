import 'package:hashtagg/features/shop/models/shop.dart';

abstract class ShopState {}

class ShopInitial extends ShopState {}

class ShopLoading extends ShopState {}

class ShopLoaded extends ShopState {
  final Shop shop;

  ShopLoaded(this.shop);
}

class ShopEditDataLoaded extends ShopState {
  final Map<String, dynamic> data;
  final List<ShopCategory> categories;

  ShopEditDataLoaded({
    required this.data,
    required this.categories,
  }) {
    print('🔍🔍🔍 [ShopEditDataLoaded] CONSTRUCTOR');
    data.forEach((key, value) {
      print('   $key: $value (${value.runtimeType})');
    });
  }
}

class ShopCreated extends ShopState {
  final int shopId;

  ShopCreated(this.shopId);
}

class ShopUpdated extends ShopState {}

class ShopPageAdded extends ShopState {}

class ShopPageUpdated extends ShopState {}

class ShopPageDeleted extends ShopState {}

class ShopImageUploaded extends ShopState {
  final String imageName;
  final String imageUrl;

  ShopImageUploaded({
    required this.imageName,
    required this.imageUrl,
  });
}

class ShopNotFound extends ShopState {}

class ShopAccessDenied extends ShopState {
  final String message;

  ShopAccessDenied(this.message);
}

class ShopError extends ShopState {
  final String message;

  ShopError(this.message);
}
