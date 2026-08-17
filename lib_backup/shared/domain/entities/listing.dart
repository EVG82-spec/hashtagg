enum ListingStatus {
  active, // Активный
  moderation, // На модерации
  completed, // Завершённые/Проданные
  archived, // В архиве
}

extension ListingStatusExtension on ListingStatus {
  String get localizedName {
    switch (this) {
      case ListingStatus.active:
        return 'Активный';
      case ListingStatus.moderation:
        return 'На модерации';
      case ListingStatus.completed:
        return 'Завершённые';
      case ListingStatus.archived:
        return 'В архиве';
    }
  }
}

class BreadcrumbItem {
  final String name;
  final String link;
  final int id;

  BreadcrumbItem({
    required this.name,
    required this.link,
    required this.id,
  });

  factory BreadcrumbItem.fromJson(Map<String, dynamic> json) {
    return BreadcrumbItem(
      name: json['name']?.toString() ?? '',
      link: json['link']?.toString() ?? '',
      id: _parseIntSafe(json['id']),
    );
  }
  
  static int _parseIntSafe(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class Listing {
  int? id;
  String title;
  List<BreadcrumbItem>? breadcrumbs; // Хлебные крошки категорий
  String? location;
  String? cityAlias; // Slug города для формирования ссылок
  String? listingAlias; // Slug объявления для формирования ссылок
  String? link; // Полная ссылка на объявление (возвращается из API)
  int? views;
  String? publishedAt;
  int? price;
  String? currency = 'RUB';
  String description;
  ListingStatus status;
  int? userId; // ID пользователя-владельца объявления
  double? latitude;
  double? longitude;
  List<String>? images; // Изображения объявления
  String? userName; // Имя пользователя-продавца
  String? userAvatar; // Аватар пользователя
  double? userRating; // Рейтинг пользователя (0.0 - 5.0)
  String? userPhone; // Телефон пользователя-продавца

  Listing({
    this.id,
    this.title = '',
    this.breadcrumbs,
    this.location,
    this.cityAlias,
    this.listingAlias,
    this.link,
    this.views,
    this.publishedAt,
    this.price,
    this.description = '',
    this.status = ListingStatus.active,
    this.userId,
    this.latitude,
    this.longitude,
    this.images,
    this.userName,
    this.userAvatar,
    this.userRating,
    this.userPhone,
  });
}
