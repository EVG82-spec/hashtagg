/// Модель категории объявлений
class Category {
  final int id;
  final String name;
  final List<String>? nameWordWrap;
  final String? image;
  final int parentId;
  final bool hasSubcategory;
  final String? breadcrumb;

  Category({
    required this.id,
    required this.name,
    this.nameWordWrap,
    this.image,
    required this.parentId,
    required this.hasSubcategory,
    this.breadcrumb,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: _parseInt(json['category_board_id']),
      name: (json['category_board_name'] as String?) ?? 'Без названия',
      nameWordWrap: json['category_board_name_word_wrap'] != null
          ? List<String>.from(json['category_board_name_word_wrap'])
          : null,
      image: json['category_board_image'] as String?,
      parentId: _parseInt(json['category_board_id_parent']),
      hasSubcategory: json['subcategory'] as bool? ?? false,
      breadcrumb: json['breadcrumb'] as String?,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'category_board_id': id,
      'category_board_name': name,
      'category_board_name_word_wrap': nameWordWrap,
      'category_board_image': image,
      'category_board_id_parent': parentId,
      'subcategory': hasSubcategory,
      'breadcrumb': breadcrumb,
    };
  }
}
