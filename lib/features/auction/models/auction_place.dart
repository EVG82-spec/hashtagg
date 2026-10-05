class AuctionPlace {
  final int place;
  final String placeEmoji;
  final int? shopId;
  final String shopName;
  final double bidPrice;
  final double minimumBid; // 👈 переименовали nextBid → minimumBid
  final bool isMyShop;
  final bool isEmpty;

  const AuctionPlace({
    required this.place,
    required this.placeEmoji,
    this.shopId,
    required this.shopName,
    required this.bidPrice,
    required this.minimumBid,
    required this.isMyShop,
    required this.isEmpty,
  });

  /// Стартовая цена слота (500/400/300/200/100)
  double get startPrice {
    switch (place) {
      case 1:
        return 500;
      case 2:
        return 400;
      case 3:
        return 300;
      case 4:
        return 200;
      case 5:
        return 100;
      default:
        return 0;
    }
  }

  /// Цена для действия (выкуп занятого места или занятие пустого)
  /// Занятое → текущая цена (bid_price) — её показываем на кнопке
  /// Пустое → стартовая цена
  double get actionPrice => isEmpty ? startPrice : bidPrice;

  /// Минимальная ставка для выкупа (bid_price + 100)
  double get minBidPrice => isEmpty ? startPrice : minimumBid;

  /// Есть ли возможность поднять (не пустое)
  bool get canRaise => !isEmpty && !isMyShop;

  factory AuctionPlace.fromJson(Map<String, dynamic> json) {
    return AuctionPlace(
      place: _parseInt(json['place']),
      placeEmoji: json['place_emoji']?.toString() ?? '',
      shopId: json['shop_id'] != null ? _parseInt(json['shop_id']) : null,
      shopName: json['shop_name']?.toString() ?? '—',
      bidPrice: _parseDouble(json['bid_price']),
      minimumBid: _parseDouble(json['minimum_bid'] ?? json['next_bid']),
      isMyShop: json['is_my_shop'] == true || json['is_my_shop'] == 1,
      isEmpty: json['is_empty'] == true || json['is_empty'] == 1,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  /// Можно ли поднять это место
  /// Если моё место выше (меньше) этого — нельзя
  bool canRaiseFromMyPlace(int? myPlace) {
    if (myPlace == null) return true; // вне ТОП-5 → всё доступно
    return place < myPlace; // моё место 3 → доступны 1, 2
  }
}
