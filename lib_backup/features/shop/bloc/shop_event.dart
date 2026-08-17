import 'package:hashtagg/core/models/shop.dart';

abstract class ShopEvent {}

class LoadShop extends ShopEvent {
  final int userId;
  final String token;
  final int shopId;

  LoadShop({
    required this.userId,
    required this.token,
    required this.shopId,
  });
}

class CreateShop extends ShopEvent {
  final int userId;
  final String token;

  CreateShop({
    required this.userId,
    required this.token,
  });
}

class UpdateShop extends ShopEvent {
  final int userId;
  final String token;
  final int shopId;
  final String title;
  final String? description;
  final int? themeCategoryId;
  final String? shopIdHash;
  final List<Map<String, String>>? sliders;
  final List<Map<String, String>>? logo;
  final List<ShopLink>? links;

  UpdateShop({
    required this.userId,
    required this.token,
    required this.shopId,
    required this.title,
    this.description,
    this.themeCategoryId,
    this.shopIdHash,
    this.sliders,
    this.logo,
    this.links,
  });
}

class LoadShopForEdit extends ShopEvent {
  final int userId;
  final String token;
  final int shopId;

  LoadShopForEdit({
    required this.userId,
    required this.token,
    required this.shopId,
  });
}

class AddShopPage extends ShopEvent {
  final int userId;
  final String token;
  final int shopId;
  final String name;
  final String text;
  final String alias;

  AddShopPage({
    required this.userId,
    required this.token,
    required this.shopId,
    required this.name,
    required this.text,
    required this.alias,
  });
}

class UpdateShopPage extends ShopEvent {
  final int userId;
  final String token;
  final int pageId;
  final String name;
  final String text;
  final String alias;

  UpdateShopPage({
    required this.userId,
    required this.token,
    required this.pageId,
    required this.name,
    required this.text,
    required this.alias,
  });
}

class DeleteShopPage extends ShopEvent {
  final int userId;
  final String token;
  final int pageId;

  DeleteShopPage({
    required this.userId,
    required this.token,
    required this.pageId,
  });
}

class UploadShopImage extends ShopEvent {
  final String filePath;
  final int userId;
  final String token;

  UploadShopImage({
    required this.filePath,
    required this.userId,
    required this.token,
  });
}
