class AutoSettings {
  final int id;
  final int shopId;
  final int userId;
  final bool isEnabled;
  final int targetPlace;
  final int maxBidStep;
  final double dailyLimit;
  final int bidIntervalMinutes;
  final String? lastBidAt;

  const AutoSettings({
    required this.id,
    required this.shopId,
    required this.userId,
    required this.isEnabled,
    required this.targetPlace,
    required this.maxBidStep,
    required this.dailyLimit,
    required this.bidIntervalMinutes,
    this.lastBidAt,
  });

  factory AutoSettings.fromJson(Map<String, dynamic> json) {
    return AutoSettings(
      id: _parseInt(json['id']),
      shopId: _parseInt(json['shop_id']),
      userId: _parseInt(json['user_id']),
      isEnabled:
          json['is_enabled'] == 1 ||
          json['is_enabled'] == true ||
          json['is_enabled'] == '1',
      targetPlace: _parseInt(json['target_place']),
      maxBidStep: _parseInt(json['max_bid_step']),
      dailyLimit: _parseDouble(json['daily_limit']),
      bidIntervalMinutes: _parseInt(json['bid_interval_minutes']),
      lastBidAt: json['last_bid_at']?.toString(),
    );
  }

  static AutoSettings empty() {
    return const AutoSettings(
      id: 0,
      shopId: 0,
      userId: 0,
      isEnabled: false,
      targetPlace: 1,
      maxBidStep: 50,
      dailyLimit: 500.0,
      bidIntervalMinutes: 60,
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
