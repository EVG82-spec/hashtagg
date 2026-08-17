import 'package:flutter/foundation.dart';

class Shop {
  final int id;
  final int userId;
  final String idHash;
  final String title;
  final String? description;
  final String? logo;
  final int themeCategoryId;
  final String? themeCategoryName;
  final int status; // 0-модерация, 1-активен, 2-отклонен
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
  });

  factory Shop.fromJson(Map<String, dynamic> json) {
    return Shop(
      id: _parseInt(json['id']),
      userId: _parseInt(json['id_user']),
      idHash: json['id_hash'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['text'] as String? ?? json['desc'] as String?,
      logo: json['logo'] as String?,
      themeCategoryId: _parseInt(json['id_theme_category']),
      themeCategoryName: json['name_theme_category'] as String?,
      status: _parseInt(json['status']),
      statusNote: json['status_note'] as String?,
      validityDate: null, // Добавим позже если нужно
      viewsCount: 0, // Добавим из статистики
      isOwner: json['owner'] == true || json['owner'] == 1,
      isActive: json['activity_shop'] == true || json['activity_shop'] == 1,
      sliders: json['sliders'] != null
          ? (json['sliders'] as List)
              .map((s) {
                if (s is String) {
                  // Если слайдер - это просто URL строка
                  return ShopSlider(name: '', link: s);
                } else if (s is Map) {
                  return ShopSlider.fromJson(s as Map<String, dynamic>);
                }
                return ShopSlider(name: '', link: '');
              })
              .toList()
          : null,
      pages: json['pages'] != null
          ? (json['pages'] as List)
              .map((p) => ShopPage.fromJson(p))
              .toList()
          : null,
      links: _parseLinks(json),
      adsCount: _parseAdsCount(json['count_ads']),
      subscribersCount: _parseInt(json['subscribers_count']),
    );
  }

  static List<ShopLink>? _parseLinks(Map<String, dynamic> json) {
    final links = <ShopLink>[];
    
    // Парсим 3 ссылки из полей link_1_*, link_2_*, link_3_*
    for (int i = 1; i <= 3; i++) {
      final text = json['link_${i}_text'] as String?;
      final link = json['link_${i}_link'] as String?;
      final image = json['link_${i}_image'] as String?;
      
      if (kDebugMode) {
        print('[Shop] Link $i: text=$text, link=$link, image=$image');
      }
      
      if ((text != null && text.isNotEmpty) || 
          (link != null && link.isNotEmpty) || 
          (image != null && image.isNotEmpty)) {
        links.add(ShopLink(
          text: text,
          link: link,
          image: image,
        ));
      }
    }
    
    if (kDebugMode) {
      print('[Shop] Parsed ${links.length} links');
    }
    
    return links.isEmpty ? null : links;
  }

  static int _parseAdsCount(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      // Парсим строку типа "5 объявлений"
      final match = RegExp(r'(\d+)').firstMatch(value);
      if (match != null) {
        return int.tryParse(match.group(1)!) ?? 0;
      }
    }
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'id_user': userId,
      'id_hash': idHash,
      'title': title,
      'text': description,
      'logo': logo,
      'id_theme_category': themeCategoryId,
      'name_theme_category': themeCategoryName,
      'status': status,
      'status_note': statusNote,
      'owner': isOwner,
      'activity_shop': isActive,
      'sliders': sliders?.map((s) => s.toJson()).toList(),
      'pages': pages?.map((p) => p.toJson()).toList(),
      'links': links?.map((l) => l.toJson()).toList(),
      'subscribers_count': subscribersCount,
    };
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
    );
  }
}

class ShopSlider {
  final int? id;
  final String name;
  final String link;

  ShopSlider({
    this.id,
    required this.name,
    required this.link,
  });

  factory ShopSlider.fromJson(Map<String, dynamic> json) {
    return ShopSlider(
      id: _parseIntNullable(json['id']),
      name: json['name'] as String? ?? '',
      link: json['link'] as String? ?? '',
    );
  }

  static int? _parseIntNullable(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'link': link,
    };
  }
}

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
      id: _parseInt(json['id']),
      name: json['name'] as String? ?? '',
      text: json['text'] as String? ?? '',
      alias: json['alias'] as String?,
      status: _parseInt(json['status']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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

class ShopCategory {
  final int id;
  final String name;

  ShopCategory({
    required this.id,
    required this.name,
  });

  factory ShopCategory.fromJson(Map<String, dynamic> json) {
    return ShopCategory(
      id: _parseInt(json['id']),
      name: json['name'] as String? ?? '',
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class ShopLink {
  final String? image;
  final String? text;
  final String? link;

  ShopLink({
    this.image,
    this.text,
    this.link,
  });

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

  bool get isEmpty => (image == null || image!.isEmpty) && 
                      (text == null || text!.isEmpty) && 
                      (link == null || link!.isEmpty);
}
