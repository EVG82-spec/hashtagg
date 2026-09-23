import 'auction_place.dart';
import 'auto_settings.dart';
import 'balance_log_item.dart';

class AuctionStatus {
  final double balance;
  final bool isParticipant;
  final String? expireDate;
  final List<AuctionPlace> topPlaces;
  final int? myPlace;
  final double? myBid;
  final bool isOutsideTop;
  final List<BalanceLogItem> balanceLog;
  final double totalSpentToday;
  final AutoSettings? autoSettings;

  const AuctionStatus({
    required this.balance,
    required this.isParticipant,
    this.expireDate,
    required this.topPlaces,
    this.myPlace,
    this.myBid,
    this.isOutsideTop = false,
    required this.balanceLog,
    required this.totalSpentToday,
    this.autoSettings,
  });

  factory AuctionStatus.fromJson(Map<String, dynamic> json) {
    print('🔍 [AuctionStatus] Parsing JSON: $json');

    return AuctionStatus(
      balance: _parseDouble(json['balance']),
      isParticipant:
          json['is_participant'] == true ||
          json['is_participant'] == 1 ||
          json['is_participant'] == '1',
      expireDate: json['expire_date']?.toString(),
      topPlaces:
          (json['top_places'] as List?)
              ?.map((e) => AuctionPlace.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      myPlace: json['my_place'] != null ? _parseInt(json['my_place']) : null,
      myBid: json['my_bid'] != null ? _parseDouble(json['my_bid']) : null,
      isOutsideTop:
          json['is_outside_top'] == true || json['is_outside_top'] == 1,
      balanceLog:
          (json['balance_log'] as List?)
              ?.map((e) => BalanceLogItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      totalSpentToday: _parseDouble(json['total_spent_today']),
      autoSettings: json['auto_settings'] != null
          ? AutoSettings.fromJson(json['auto_settings'] as Map<String, dynamic>)
          : null,
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

  static AuctionStatus empty() {
    return const AuctionStatus(
      balance: 0,
      isParticipant: false,
      topPlaces: [],
      balanceLog: [],
      totalSpentToday: 0,
    );
  }
}
