class AuctionPlace {
  final int place;
  final String placeEmoji;
  final int? shopId;
  final String shopName;
  final double bidPrice;
  final double nextBid;
  final bool isMyShop;
  final bool isEmpty;

  const AuctionPlace({
    required this.place,
    required this.placeEmoji,
    this.shopId,
    required this.shopName,
    required this.bidPrice,
    required this.nextBid,
    required this.isMyShop,
    required this.isEmpty,
  });

  factory AuctionPlace.fromJson(Map<String, dynamic> json) {
    return AuctionPlace(
      place: _parseInt(json['place']),
      placeEmoji: json['place_emoji']?.toString() ?? '',
      shopId: json['shop_id'] != null ? _parseInt(json['shop_id']) : null,
      shopName: json['shop_name']?.toString() ?? '—',
      bidPrice: _parseDouble(json['bid_price']),
      nextBid: _parseDouble(json['next_bid']),
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
}
