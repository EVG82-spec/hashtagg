class AdService {
  final int id;
  final String name;
  final String description;
  final String price;
  final double priceRaw;
  final String? oldPrice;
  final double? oldPriceRaw;
  final int days;
  final bool canChangeDays;
  final bool isActive;
  final bool available;
  final String message;
  final bool recommended;

  AdService({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.priceRaw,
    this.oldPrice,
    this.oldPriceRaw,
    required this.days,
    required this.canChangeDays,
    required this.isActive,
    required this.available,
    required this.message,
    required this.recommended,
  });

  factory AdService.fromJson(Map<String, dynamic> json) {
    return AdService(
      id: _parseInt(json['id']),
      name: json['name'] as String,
      description: json['description'] as String,
      price: json['price'] as String,
      priceRaw: _parseDouble(json['price_raw']),
      oldPrice: json['old_price'] as String?,
      oldPriceRaw: json['old_price_raw'] != null 
          ? _parseDouble(json['old_price_raw']) 
          : null,
      days: _parseInt(json['days']),
      canChangeDays: json['can_change_days'] as bool,
      isActive: json['is_active'] as bool,
      available: json['available'] as bool,
      message: json['message'] as String? ?? '',
      recommended: json['recommended'] as bool,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  // Иконка услуги
  String get icon {
    switch (id) {
      case 1: // Поднятие
        return '🚀';
      case 2: // VIP
        return '👑';
      case 3: // Turbo
        return '⚡';
      default:
        return '✨';
    }
  }

  // Цвет услуги
  int get color {
    switch (id) {
      case 1: // Поднятие
        return 0xff4CAF50;
      case 2: // VIP
        return 0xffFFD700;
      case 3: // Turbo
        return 0xffFF6B6B;
      default:
        return 0xff917dfa;
    }
  }
}

class AdServicesResponse {
  final List<AdService> services;
  final String balance;
  final double balanceRaw;

  AdServicesResponse({
    required this.services,
    required this.balance,
    required this.balanceRaw,
  });

  factory AdServicesResponse.fromJson(Map<String, dynamic> json) {
    return AdServicesResponse(
      services: (json['services'] as List)
          .map((service) => AdService.fromJson(service))
          .toList(),
      balance: json['balance'] as String,
      balanceRaw: _parseDouble(json['balance_raw']),
    );
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
