class User {
  int id;
  String name;
  String? surname;
  String? last_name;
  String? shortname;
  String? email;
  String? phone;
  String? avatar;
  String? status;
  String? token;

  // Дополнительные поля
  bool? isCompany;
  String? companyName;
  bool? safeDealEnabled;
  String? ymoneyAccount;
  bool? bookingEnabled;
  String? cardNumber;
  bool? showPhoneInListings;
  int walletBalance;
  int? tariffId;
  List<String>? activeServices; // Список активных сервисов тарифа (например: ['stories', 'top_ads'])
  String? referralLink; // Реферальная ссылка пользователя

  User({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatar,
    this.status,
    this.token,
    this.last_name,
    this.surname,
    this.shortname,
    this.isCompany,
    this.companyName,
    this.safeDealEnabled,
    this.ymoneyAccount,
    this.bookingEnabled,
    this.cardNumber,
    this.showPhoneInListings,
    this.walletBalance = 0,
    this.tariffId,
    this.activeServices,
    this.referralLink,
  });

  User copyWith({
    int? id,
    String? name,
    String? surname,
    String? last_name,
    String? shortname,
    String? email,
    String? phone,
    String? avatar,
    String? status,
    String? token,
    bool? isCompany,
    String? companyName,
    bool? safeDealEnabled,
    String? ymoneyAccount,
    bool? bookingEnabled,
    String? cardNumber,
    bool? showPhoneInListings,
    int? walletBalance,
    int? tariffId,
    List<String>? activeServices,
    String? referralLink,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      last_name: last_name ?? this.last_name,
      shortname: shortname ?? this.shortname,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      status: status ?? this.status,
      token: token ?? this.token,
      isCompany: isCompany ?? this.isCompany,
      companyName: companyName ?? this.companyName,
      safeDealEnabled: safeDealEnabled ?? this.safeDealEnabled,
      ymoneyAccount: ymoneyAccount ?? this.ymoneyAccount,
      bookingEnabled: bookingEnabled ?? this.bookingEnabled,
      cardNumber: cardNumber ?? this.cardNumber,
      showPhoneInListings: showPhoneInListings ?? this.showPhoneInListings,
      walletBalance: walletBalance ?? this.walletBalance,
      tariffId: tariffId ?? this.tariffId,
      activeServices: activeServices ?? this.activeServices,
      referralLink: referralLink ?? this.referralLink,
    );
  }
}
