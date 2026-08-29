// lib/features/shop/models/shop.dart
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

// ============================================================
// КЛАСС SHOP - ОСНОВНАЯ МОДЕЛЬ
// ============================================================

class Shop {
  final int id;
  final int userId;
  final String idHash;
  final String title;
  final String? description;
  final String? logo;
  final int themeCategoryId;
  final String? themeCategoryName;
  final int status;
  final String? statusNote;
  final DateTime? validityDate;
  final int viewsCount;
  final bool isOwner;
  final bool isActive;
  final List<ShopSlider>? sliders;
  final List<ShopPage>? pages;
  final List<ShopLink>? links;
  final int adsCount;
  final int subscribersCount;
  final String? qrCode;
  final String? slug;
  final Uint8List? qrBytes;

  // ============================================================
  // ГЕТТЕРЫ ДЛЯ МЕДИА
  // ============================================================

  String? get avatarUrl {
    if (userId > 0 && idHash.isNotEmpty) {
      return 'https://hashtagg.ru/media/users/$userId/shop/$idHash/avatar.jpg';
    }
    return null;
  }

  String? get bannerUrl {
    if (sliders != null && sliders!.isNotEmpty) {
      final firstSlider = sliders!.first;
      if (firstSlider.link.isNotEmpty) {
        return firstSlider.link;
      }
    }

    if (userId > 0 && idHash.isNotEmpty) {
      return 'https://hashtagg.ru/media/users/$userId/shop/$idHash/banner.jpg';
    }
    return null;
  }

  Shop({
    required this.id,
    required this.userId,
    required this.idHash,
    required this.title,
    this.description,
    this.logo,
    required this.themeCategoryId,
    this.themeCategoryName,
    required this.status,
    this.statusNote,
    this.validityDate,
    required this.viewsCount,
    required this.isOwner,
    required this.isActive,
    this.sliders,
    this.pages,
    this.links,
    required this.adsCount,
    required this.subscribersCount,
    this.qrCode,
    this.slug,
    this.qrBytes,
  });

  // ============================================================
  // fromJson - ПАРСИНГ ИЗ API
  // ============================================================

  factory Shop.fromJson(Map<String, dynamic> json) {
    print('🟢🟢🟢 [Shop.fromJson] CALLED');
    print('   Title: ${json['clients_shops_title'] ?? json['title']}');
    print('   ALL KEYS: ${json.keys.join(', ')}');
    print('   id_user: ${json['id_user']}');
    print('   user_id: ${json['user_id']}');
    print('   clients_shops_id_user: ${json['clients_shops_id_user']}');
    print('   id_hash: ${json['id_hash']}');
    print('   clients_shops_id_hash: ${json['clients_shops_id_hash']}');
    print('   shop_id_hash: ${json['shop_id_hash']}');
    print('   id: ${json['id']}');
    print('   clients_shops_id: ${json['clients_shops_id']}');

    print('🟢🟢🟢 [Shop.fromJson] CALLED');
    print('   Title: ${json['clients_shops_title'] ?? json['title']}');
    print('   Keys: ${json.keys.join(', ')}');

    final hasPrefix = json.containsKey('clients_shops_id');
    print('   hasPrefix: $hasPrefix'); // 👈 ЭТА ПЕРЕМЕННАЯ ДОЛЖНА БЫТЬ
    print('   hasPrefix: $hasPrefix');

    // ✅ ПАРСИМ SLUG
    final slug = hasPrefix
        ? (json['clients_shops_slug'] as String?)
        : (json['slug'] as String?);

    // 👇 ДОБАВЬ ЭТИ ПРИНТЫ ДЛЯ ССЫЛОК
    print(
      '🔗 [Shop.fromJson] link_1_link: ${json['link_1_link'] ?? json['link_1_link']}',
    );
    print(
      '🔗 [Shop.fromJson] link_2_link: ${json['link_2_link'] ?? json['link_2_link']}',
    );
    print(
      '🔗 [Shop.fromJson] link_3_link: ${json['link_3_link'] ?? json['link_3_link']}',
    );
    print(
      '🔗 [Shop.fromJson] clients_shops link_1_link: ${json['link_1_link']}',
    );
    print(
      '🔗 [Shop.fromJson] clients_shops link_2_link: ${json['link_2_link']}',
    );
    print(
      '🔗 [Shop.fromJson] clients_shops link_3_link: ${json['link_3_link']}',
    );

    // ============================================================
    // 1. ПАРСИМ ID
    // ============================================================
    final id = hasPrefix
        ? _parseInt(json['clients_shops_id'])
        : _parseInt(json['id']);

    // ============================================================
    // 2. ПАРСИМ userId - ИЗ user.id (для списка магазинов)
    // ============================================================
    int userId = 0;

    // Сначала пробуем из корневых полей
    if (json['id_user'] != null) {
      userId = _parseInt(json['id_user']);
    } else if (json['user_id'] != null) {
      userId = _parseInt(json['user_id']);
    } else if (json['clients_shops_id_user'] != null) {
      userId = _parseInt(json['clients_shops_id_user']);
    } else if (json['user'] != null && json['user'] is Map) {
      // ✅ ДЛЯ СПИСКА МАГАЗИНОВ - userId ВНУТРИ user
      final userMap = json['user'] as Map<String, dynamic>;
      userId = _parseInt(userMap['id']);
      print('   🔍 userId from user.id: $userId');
    }

    print('   🔍 final userId: $userId');

    // ============================================================
    // 3. ПОЛУЧАЕМ ID ТЕКУЩЕГО ПОЛЬЗОВАТЕЛЯ ИЗ Hive
    // ============================================================
    int currentUserId = 0;
    try {
      final box = Hive.box('user');
      final userData = box.get('user') as Map?;
      if (userData != null) {
        currentUserId = userData['id'] is int
            ? userData['id'] as int
            : int.tryParse(userData['id'].toString()) ?? 0;
      }
    } catch (e) {
      print('⚠️ [Shop.fromJson] Error getting current user: $e');
    }
    print('   🔍 currentUserId from Hive: $currentUserId');

    // ============================================================
    // 4. ОПРЕДЕЛЯЕМ ВЛАДЕЛЬЦА
    // ============================================================
    final bool isOwner =
        json['is_owner'] == true ||
        json['owner'] == true ||
        json['owner'] == 1 ||
        (userId > 0 && currentUserId > 0 && userId == currentUserId);
    print('   🔍 isOwner: $isOwner');

    // ============================================================
    // 5. ПАРСИМ idHash (ХЕШ МАГАЗИНА)
    // ============================================================
    String idHash = '';

    // 1. Сначала ищем в корневых полях
    if (json['clients_shops_id_hash'] != null) {
      idHash = json['clients_shops_id_hash'].toString();
    } else if (json['id_hash'] != null) {
      idHash = json['id_hash'].toString();
    } else if (json['shop_id_hash'] != null) {
      idHash = json['shop_id_hash'].toString();
    } else if (json['user'] != null && json['user'] is Map) {
      // 2. Для списка магазинов — хеш в объекте user
      final userMap = json['user'] as Map<String, dynamic>;
      if (userMap['id_hash'] != null) {
        idHash = userMap['id_hash'].toString();
        print('   🔍 idHash from user.id_hash: $idHash');
      } else if (userMap['hash'] != null) {
        idHash = userMap['hash'].toString();
        print('   🔍 idHash from user.hash: $idHash');
      }
    }

    // 3. Если ничего не нашли — используем id (запасной вариант)
    if (idHash.isEmpty) {
      idHash = json['id']?.toString() ?? '';
      print('   ⚠️ idHash not found, using id: $idHash');
    }

    print('🔍 [Shop.fromJson] final idHash: "$idHash"');

    final title = hasPrefix
        ? (json['clients_shops_title'] as String? ?? '')
        : (json['title'] as String? ?? '');

    final description = hasPrefix
        ? (json['clients_shops_desc'] as String?)
        : (json['description'] as String?);

    // ============================================================
    // 6. АВАТАРКА — ВСЕГДА ИЗ ПАПКИ МАГАЗИНА (НЕ ИЗ LOGO)
    // ============================================================
    // ❌ НЕ ПАРСИМ logoRaw, НЕ ИСПОЛЬЗУЕМ ЕГО
    String? logoUrl = null; // 👈 ВСЕГДА null

    print('   ℹ️ Avatar will be loaded from folder, logo from API is ignored');

    final themeCategoryId = hasPrefix
        ? _parseInt(json['clients_shops_id_theme_category'])
        : _parseInt(json['id_theme_category']);

    final themeCategoryName = json['name_theme_category'] as String?;

    final status = hasPrefix
        ? _parseInt(json['clients_shops_status'])
        : _parseInt(json['status']);

    final statusNote = hasPrefix
        ? (json['clients_shops_status_note'] as String?)
        : (json['status_note'] as String?);

    final viewsCount = hasPrefix
        ? _parseInt(json['clients_shops_count_view'])
        : (json['count_view'] as int? ?? 0);

    final isActive =
        json['is_active'] == true ||
        json['activity_shop'] == true ||
        json['activity_shop'] == 1;

    // ============================================================
    // 7. ПАРСИМ СЛАЙДЕРЫ
    // ============================================================
    List<ShopSlider>? sliders;
    if (json['sliders'] != null && (json['sliders'] as List).isNotEmpty) {
      try {
        sliders = (json['sliders'] as List).map((s) {
          if (s is String) {
            return ShopSlider(name: '', link: s);
          } else if (s is Map) {
            return ShopSlider.fromJson(s.cast<String, dynamic>());
          }
          return ShopSlider(name: '', link: '');
        }).toList();
      } catch (e) {
        print('⚠️ [Shop.fromJson] Error parsing sliders: $e');
        sliders = null;
      }
    }

    // ============================================================
    // 8. ПАРСИМ СТРАНИЦЫ
    // ============================================================
    List<ShopPage>? pages;
    if (json['pages'] != null && (json['pages'] as List).isNotEmpty) {
      try {
        pages = (json['pages'] as List).map((p) {
          if (p is Map) {
            return ShopPage.fromJson(p.cast<String, dynamic>());
          }
          return ShopPage(id: 0, name: '', text: '');
        }).toList();
      } catch (e) {
        print('⚠️ [Shop.fromJson] Error parsing pages: $e');
        pages = null;
      }
    }

    // ============================================================
    // 9. ПАРСИМ ССЫЛКИ (СОЦСЕТИ)
    // ============================================================
    List<ShopLink>? links;
    final linkList = <ShopLink>[];
    for (int i = 1; i <= 3; i++) {
      // ✅ ПРОВЕРЯЕМ ОБА ВАРИАНТА КЛЮЧЕЙ
      final textKey = hasPrefix ? 'link_${i}_text' : 'link_${i}_text';
      final linkKey = hasPrefix ? 'link_${i}_link' : 'link_${i}_link';
      final imageKey = hasPrefix ? 'link_${i}_image' : 'link_${i}_image';

      final text = json[textKey] as String?;
      final link = json[linkKey] as String?;
      final image = json[imageKey] as String?;

      if ((text != null && text.isNotEmpty) ||
          (link != null && link.isNotEmpty) ||
          (image != null && image.isNotEmpty)) {
        linkList.add(ShopLink(text: text, link: link, image: image));
      }
    }
    if (linkList.isNotEmpty) links = linkList;

    print('🔗 [Shop.fromJson] links parsed: ${links?.length ?? 0}');

    // ============================================================
    // 10. ПАРСИМ КОЛИЧЕСТВО ТОВАРОВ
    // ============================================================
    int adsCount = 0;
    print('📊 [Shop.fromJson] count_ads raw: ${json['count_ads']}');
    print(
      '📊 [Shop.fromJson] count_ads type: ${json['count_ads'].runtimeType}',
    );

    if (json['clients_shops_count_ads'] != null) {
      adsCount = _parseInt(json['clients_shops_count_ads']);
      print('📊 [Shop.fromJson] from clients_shops_count_ads: $adsCount');
    } else if (json['count_ads'] != null) {
      final countAds = json['count_ads'];
      print('📊 [Shop.fromJson] countAds value: "$countAds"');
      if (countAds is String) {
        final match = RegExp(r'\d+').firstMatch(countAds);
        print('📊 [Shop.fromJson] match: ${match?.group(0)}');
        if (match != null) {
          adsCount = int.tryParse(match.group(0)!) ?? 0;
          print('📊 [Shop.fromJson] parsed adsCount: $adsCount');
        }
      } else {
        adsCount = _parseInt(countAds);
      }
    } else if (json['ads_count'] != null) {
      adsCount = _parseInt(json['ads_count']);
    }

    print('📊 [Shop.fromJson] FINAL adsCount: $adsCount');

    // ✅ ДОБАВЬ ЭТУ СТРОКУ!
    final subscribersCount = _parseInt(json['subscribers_count']);

    // ✅ ПАРСИМ QR-КОД
    final qrCode = json['qr_code'] as String?;

    return Shop(
      id: id,
      userId: userId,
      idHash: idHash,
      title: title,
      description: description,
      logo: logoUrl,
      themeCategoryId: themeCategoryId,
      themeCategoryName: themeCategoryName,
      status: status,
      statusNote: statusNote,
      validityDate: null,
      viewsCount: viewsCount,
      isOwner: isOwner,
      isActive: isActive,
      sliders: sliders,
      pages: pages,
      links: links,
      adsCount: adsCount,
      subscribersCount: subscribersCount, // 👈 ТЕПЕРЬ ОПРЕДЕЛЕНА!
      qrCode: qrCode,
      slug: slug,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Shop copyWith({
    int? id,
    int? userId,
    String? idHash,
    String? title,
    String? description,
    String? logo,
    int? themeCategoryId,
    String? themeCategoryName,
    int? status,
    String? statusNote,
    DateTime? validityDate,
    int? viewsCount,
    bool? isOwner,
    bool? isActive,
    List<ShopSlider>? sliders,
    List<ShopPage>? pages,
    List<ShopLink>? links,
    int? adsCount,
    int? subscribersCount,
    Uint8List? qrBytes,
  }) {
    return Shop(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      idHash: idHash ?? this.idHash,
      title: title ?? this.title,
      description: description ?? this.description,
      logo: logo ?? this.logo,
      themeCategoryId: themeCategoryId ?? this.themeCategoryId,
      themeCategoryName: themeCategoryName ?? this.themeCategoryName,
      status: status ?? this.status,
      statusNote: statusNote ?? this.statusNote,
      validityDate: validityDate ?? this.validityDate,
      viewsCount: viewsCount ?? this.viewsCount,
      isOwner: isOwner ?? this.isOwner,
      isActive: isActive ?? this.isActive,
      sliders: sliders ?? this.sliders,
      pages: pages ?? this.pages,
      links: links ?? this.links,
      adsCount: adsCount ?? this.adsCount,
      subscribersCount: subscribersCount ?? this.subscribersCount,
      qrCode: qrCode ?? this.qrCode,
      qrBytes: qrBytes ?? this.qrBytes,
    );
  }
}

// ============================================================
// КЛАСС ShopSlider
// ============================================================

class ShopSlider {
  final int? id;
  final String name;
  final String link;

  ShopSlider({this.id, required this.name, required this.link});

  factory ShopSlider.fromJson(Map<String, dynamic> json) {
    return ShopSlider(
      id: json['id'] as int?,
      name: json['name'] as String? ?? '',
      link: json['link'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {if (id != null) 'id': id, 'name': name, 'link': link};
  }
}

// ============================================================
// КЛАСС ShopPage
// ============================================================

class ShopPage {
  final int id;
  final String name;
  final String text;
  final String? alias;
  final int status;

  ShopPage({
    required this.id,
    required this.name,
    required this.text,
    this.alias,
    this.status = 1,
  });

  factory ShopPage.fromJson(Map<String, dynamic> json) {
    return ShopPage(
      id: json['id'] ?? 0,
      name: json['name'] as String? ?? '',
      text: json['text'] as String? ?? '',
      alias: json['alias'] as String?,
      status: json['status'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'text': text,
      if (alias != null) 'alias': alias,
      'status': status,
    };
  }
}

// ============================================================
// КЛАСС ShopLink
// ============================================================

class ShopLink {
  final String? image;
  final String? text;
  final String? link;

  ShopLink({this.image, this.text, this.link});

  factory ShopLink.fromJson(Map<String, dynamic> json) {
    return ShopLink(
      image: json['image'] as String?,
      text: json['text'] as String?,
      link: json['link'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (image != null) 'image': image,
      if (text != null) 'text': text,
      if (link != null) 'link': link,
    };
  }
}

// ============================================================
// КЛАСС ShopCategory
// ============================================================

class ShopCategory {
  final int id;
  final String name;
  final String? image;
  final int parentId;
  final bool hasSubcategory;
  final String breadcrumb;
  final List<ShopCategory>? nested;

  ShopCategory({
    required this.id,
    required this.name,
    this.image,
    this.parentId = 0,
    this.hasSubcategory = false,
    this.breadcrumb = '',
    this.nested,
  });

  factory ShopCategory.fromJson(Map<String, dynamic> json) {
    return ShopCategory(
      id: int.tryParse(json['category_board_id'].toString()) ?? 0,
      name: json['category_board_name'] as String? ?? '',
      image: json['category_board_image'] as String?,
      parentId: int.tryParse(json['category_board_id_parent'].toString()) ?? 0,
      hasSubcategory:
          json['subcategory'] == true ||
          json['subcategory'] == 'true' ||
          json['subcategory'] == 1,
      breadcrumb: json['breadcrumb'] as String? ?? '',
      nested: json['nested'] != null
          ? (json['nested'] as List)
                .map((e) => ShopCategory.fromJson(e))
                .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      if (image != null) 'image': image,
      'parentId': parentId,
      'hasSubcategory': hasSubcategory,
      'breadcrumb': breadcrumb,
    };
  }
}

// lib/features/shop/models/shop.dart

class UserTariff {
  final int id;
  final String name;
  final int price;
  final int days;
  final List<int> services;
  final DateTime? dateCompletion;

  UserTariff({
    required this.id,
    required this.name,
    required this.price,
    required this.days,
    required this.services,
    this.dateCompletion,
  });

  factory UserTariff.fromJson(Map<String, dynamic> json) {
    List<int> services = [];

    final serviceNameMap = {
      'Персональный магазин': 1,
      'Дополнительные страницы в магазине': 2, // 👈 ИСПРАВЛЕНО НАЗВАНИЕ!
      'Уникальный адрес магазина': 3,
      'Поиск в магазине только по вашим товарам': 4,
      'Скрытие конкурентов в ваших объявлениях': 5,
      'Расширенная статистика': 6,
      'Планировщик задач': 7,
      'Календарь бронирования': 8,
      'Сторисы на 7 дней': 11,
      'Ссылки магазина': 12,
    };

    if (json['services'] != null && json['services'] is List) {
      for (var service in json['services']) {
        if (service is Map<String, dynamic>) {
          final name = service['name'] as String? ?? '';
          final serviceId = serviceNameMap[name];
          if (serviceId != null) {
            services.add(serviceId);
          }
        }
      }
    }

    return UserTariff(
      id: json['id'] is int
          ? json['id']
          : int.tryParse(json['id'].toString()) ?? 0,
      name: json['name'] ?? '',
      price: json['price'] is int
          ? json['price']
          : int.tryParse(json['price'].toString()) ?? 0,
      days: json['days'] is int
          ? json['days']
          : int.tryParse(json['days'].toString()) ?? 0,
      services: services,
      dateCompletion: json['date_completion'] != null
          ? DateTime.tryParse(json['date_completion'])
          : null,
    );
  }

  bool hasService(String alias) {
    final serviceMap = {
      'shop': 1,
      'shop_page': 2,
      'unique_shop_address': 3,
      'search_shop': 4,
      'hiding_competitors_ads': 5,
      'statistics_ad': 6,
      'scheduler': 7,
      'booking_calendar': 8,
      'stories_3_days': 10,
      'stories_7_days': 11,
      'shop_links': 12,
    };

    final serviceId = serviceMap[alias];
    if (serviceId == null) return false;
    return services.contains(serviceId);
  }

  bool get isActive {
    if (dateCompletion == null) return true;
    return dateCompletion!.isAfter(DateTime.now());
  }
}
