class BalanceLogItem {
  final String datetime;
  final double summa;
  final String name;
  final String method;

  const BalanceLogItem({
    required this.datetime,
    required this.summa,
    required this.name,
    required this.method,
  });

  factory BalanceLogItem.fromJson(Map<String, dynamic> json) {
    return BalanceLogItem(
      datetime: json['datetime']?.toString() ?? '',
      summa: _parseDouble(json['summa']),
      name: json['name']?.toString() ?? 'Операция',
      method: json['method']?.toString() ?? '',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
