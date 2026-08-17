import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/core/network/tariffs_api_repository.dart';
import 'package:hashtagg/core/network/profile_api_repository.dart';
import 'package:hive/hive.dart';

class TariffsScreen extends StatefulWidget {
  const TariffsScreen({super.key});

  @override
  State<TariffsScreen> createState() => _TariffsScreenState();
}

class _TariffsScreenState extends State<TariffsScreen> {
  final PageController _pageController = PageController();
  final TariffsApiRepository _tariffsApi = TariffsApiRepository();
  final ProfileApiRepository _profileApi = ProfileApiRepository();
  
  int _currentPage = 0;
  bool _isLoading = true;
  String? _error;
  List<dynamic> _tariffs = [];
  bool _hasActiveTariff = false;

  @override
  void initState() {
    super.initState();
    _refreshUserProfile();
    _loadTariffs();
  }

  /// Обновление данных профиля пользователя
  Future<void> _refreshUserProfile() async {
    final authBloc = context.read<AuthBloc>();
    final user = authBloc.state.user;
    
    if (user == null) return;
    
    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;
    
    if (token == null) return;
    
    try {
      final result = await _profileApi.getProfile(
        userId: user.id,
        token: token,
      );
      
      if (result['id'] != null) {
        // Безопасное преобразование tariffId
        final tariffIdRaw = result['tariff_id'];
        final newTariffId = tariffIdRaw == null 
            ? null 
            : (tariffIdRaw is int ? tariffIdRaw : int.parse(tariffIdRaw.toString()));
        
        if (newTariffId != user.tariffId) {
          print('🔵 [TariffsScreen] Updating tariffId from ${user.tariffId} to $newTariffId');
          authBloc.add(UserUpdated(user.copyWith(tariffId: newTariffId)));
        }
      }
    } catch (e) {
      print('🔴 [TariffsScreen] Error refreshing profile: $e');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadTariffs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final authBloc = context.read<AuthBloc>();
    final user = authBloc.state.user;

    if (user == null) {
      setState(() {
        _isLoading = false;
        _error = 'Пользователь не авторизован';
      });
      return;
    }

    // Получаем токен напрямую из Hive
    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;

    if (token == null) {
      setState(() {
        _isLoading = false;
        _error = 'Ошибка авторизации';
      });
      return;
    }

    final result = await _tariffsApi.getData(
      userId: user.id,
      token: token,
    );

    if (result['status'] == true) {
      // Сортируем тарифы по цене (от дешевых к дорогим)
      final tariffs = result['data'] ?? [];
      tariffs.sort((a, b) {
        // Безопасное преобразование цены
        final priceA = a['price']['now'] is num 
            ? (a['price']['now'] as num).toInt()
            : int.parse(a['price']['now'].toString());
        final priceB = b['price']['now'] is num 
            ? (b['price']['now'] as num).toInt()
            : int.parse(b['price']['now'].toString());
        return priceA.compareTo(priceB);
      });
      
      setState(() {
        _tariffs = tariffs;
        _hasActiveTariff = (user.tariffId != null && user.tariffId! > 0);
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['error'] ?? 'Ошибка загрузки тарифов';
        _isLoading = false;
      });
    }
  }

  Future<void> _activateTariff(dynamic tariff) async {
    final authBloc = context.read<AuthBloc>();
    final user = authBloc.state.user;

    if (user == null) return;

    // Получаем токен напрямую из Hive
    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;

    if (token == null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка авторизации')),
      );
      return;
    }

    // Безопасное преобразование цены
    final price = tariff['price']['now'] is num 
        ? (tariff['price']['now'] as num).toInt()
        : int.parse(tariff['price']['now'].toString());
    final balance = user.walletBalance;

    if (balance < price) {
      Navigator.pop(context);
      _showInsufficientFundsSheet(tariff, balance);
      return;
    }

    // Безопасное преобразование tariff ID для API
    final tariffIdForApi = tariff['id'] is int 
        ? tariff['id'] as int
        : int.parse(tariff['id'].toString());

    final result = await _tariffsApi.activate(
      userId: user.id,
      token: token,
      tariffId: tariffIdForApi,
    );

    if (result['status'] == true) {
      // Используем тот же ID для обновления пользователя
      final tariffId = tariffIdForApi;
      
      print('🔵 [TariffsScreen] Activating tariff: tariffId=$tariffId');
      print('🔵 [TariffsScreen] Current user.tariffId=${user.tariffId}');
      
      authBloc.add(UserUpdated(user.copyWith(
        walletBalance: balance - price,
        tariffId: tariffId,
      )));
      
      print('🔵 [TariffsScreen] UserUpdated event sent with tariffId=$tariffId');
      
      Navigator.pop(context);
      _showSuccessSheet(tariff);
      _loadTariffs();
    } else if (result['balance'] == false) {
      Navigator.pop(context);
      _showInsufficientFundsSheet(tariff, balance);
    } else if (result['answer'] != null) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['answer'])),
      );
    } else {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Ошибка активации тарифа')),
      );
    }
  }

  Future<void> _deleteTariff() async {
    final authBloc = context.read<AuthBloc>();
    final user = authBloc.state.user;

    if (user == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Отменить тариф?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Тариф будет удалён немедленно без возврата средств. Магазин также будет деактивирован.',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Отмена', style: GoogleFonts.montserrat()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Удалить', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Получаем токен напрямую из Hive
    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка авторизации')),
      );
      return;
    }

    final result = await _tariffsApi.deleteTariff(
      userId: user.id,
      token: token,
    );

    if (result['status'] == true) {
      authBloc.add(UserUpdated(user.copyWith(tariffId: 0)));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тариф успешно удалён')),
      );
      _loadTariffs();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['error'] ?? 'Ошибка удаления тарифа')),
      );
    }
  }

  Future<void> _showAdSelectionSheet() async {
    final authBloc = context.read<AuthBloc>();
    final user = authBloc.state.user;

    if (user == null) return;

    final result = await _profileApi.getUserAds(userId: user.id);

    if (!mounted) return;

    if (result['status'] != true || result['data'] == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось загрузить объявления')),
      );
      return;
    }

    final ads = result['data'] as List;

    if (ads.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У вас нет объявлений')),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: EdgeInsets.only(
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Выберите объявление',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: ads.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final ad = ads[index];
                    return ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        context.push('/ad-statistics/${ad['ads_id']}');
                      },
                      leading: ad['ads_images'] != null && ad['ads_images'].isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                ad['ads_images'][0],
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.image, color: Colors.grey),
                                ),
                              ),
                            )
                          : Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.image, color: Colors.grey),
                            ),
                      title: Text(
                        ad['ads_title'] ?? 'Без названия',
                        style: GoogleFonts.montserrat(fontSize: 15),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${ad['ads_price']} ₽',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showInsufficientFundsSheet(dynamic tariff, int balance) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8DEFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  size: 72,
                  color: Color(0xff917dfa),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Недостаточно средств',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$balance ₽',
                style: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Баланс кошелька',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/wallet');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff917dfa),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Пополнить баланс',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSuccessSheet(dynamic tariff) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 60,
                  color: Color(0xFF4CAF8E),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Оплачено!',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '«${tariff['name']}» активирован',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF8E),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Отлично!',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showPaymentConfirmSheet(dynamic tariff) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8DEFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  size: 72,
                  color: Color(0xff917dfa),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Спишется с баланса',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${tariff['price']['now']} ₽',
                style: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _activateTariff(tariff),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff917dfa),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Продолжить',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Theme.of(context).appBarTheme.backgroundColor,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Тарифы',
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _error!,
                        style: GoogleFonts.montserrat(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTariffs,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : _tariffs.isEmpty
                  ? Center(
                      child: Text(
                        'Тарифы недоступны',
                        style: GoogleFonts.montserrat(),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 8),
                            child: PageView.builder(
                              controller: _pageController,
                              itemCount: _tariffs.length,
                              onPageChanged: (index) {
                                setState(() => _currentPage = index);
                              },
                              itemBuilder: (context, index) {
                                final tariff = _tariffs[index];
                                final authBloc = context.read<AuthBloc>();
                                final user = authBloc.state.user;
                                
                                // Безопасное сравнение ID с учетом типов
                                final tariffId = tariff['id'] is int 
                                    ? tariff['id'] as int
                                    : int.parse(tariff['id'].toString());
                                final isActive = user?.tariffId != null && tariffId == user!.tariffId;
                                
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: _TariffCard(
                                    tariff: tariff,
                                    isActive: isActive,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(_tariffs.length, (index) {
                              final isActive = index == _currentPage;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                margin: const EdgeInsets.symmetric(horizontal: 4),
                                width: isActive ? 28 : 10,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? (isDark ? Colors.white : const Color(0xff917dfa))
                                      : (isDark 
                                          ? const Color(0xff233040) 
                                          : const Color(0xff917dfa).withValues(alpha: 0.3)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              );
                            }),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: MediaQuery.of(context).padding.bottom + 16,
                          ),
                          child: Column(
                            children: [
                              Builder(
                                builder: (context) {
                                  final authBloc = context.read<AuthBloc>();
                                  final user = authBloc.state.user;
                                  final currentTariff = _tariffs[_currentPage];
                                  
                                  // Безопасное сравнение ID с учетом типов
                                  final tariffId = currentTariff['id'] is int 
                                      ? currentTariff['id'] as int
                                      : int.parse(currentTariff['id'].toString());
                                  final isCurrentTariff = user?.tariffId != null && tariffId == user!.tariffId;
                                  
                                  print('🔵 [TariffsScreen] Checking tariff: id=$tariffId, user.tariffId=${user?.tariffId}, isCurrentTariff=$isCurrentTariff');
                                  
                                  return Column(
                                    children: [
                                      if (isCurrentTariff) ...[
                                        SizedBox(
                                          width: double.infinity,
                                          child: OutlinedButton(
                                            onPressed: _deleteTariff,
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.red,
                                              side: const BorderSide(color: Colors.red),
                                              padding: const EdgeInsets.symmetric(vertical: 18),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(30),
                                              ),
                                            ),
                                            child: Text(
                                              'Отменить тариф',
                                              style: GoogleFonts.montserrat(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(vertical: 18),
                                          decoration: BoxDecoration(
                                            color: isDark ? const Color(0xff233040) : Colors.grey[200],
                                            borderRadius: BorderRadius.circular(30),
                                          ),
                                          child: Text(
                                            'Текущий тариф',
                                            textAlign: TextAlign.center,
                                            style: GoogleFonts.montserrat(
                                              color: isDark ? Colors.white : Colors.grey[600],
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ] else ...[
                                        SizedBox(
                                          width: double.infinity,
                                          child: ElevatedButton(
                                            onPressed: () => _showPaymentConfirmSheet(currentTariff),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isDark ? const Color(0xff233040) : const Color(0xFF917dfa),
                                              padding: const EdgeInsets.symmetric(vertical: 18),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(30),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: Text(
                                              'Подключить',
                                              style: GoogleFonts.montserrat(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
    );
  }
}

class _TariffCard extends StatelessWidget {
  final dynamic tariff;
  final bool isActive;

  const _TariffCard({
    required this.tariff,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final price = tariff['price']['now'];
    final oldPrice = tariff['price']['old'];
    final services = tariff['services'] as List?;

    return Container(
      decoration: BoxDecoration(
        color: isActive 
            ? const Color(0xFFE8F5E9) 
            : (isDark ? const Color(0xff233040) : const Color(0xFFF0EEFF)),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (isActive) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF8E),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Активный',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              tariff['name'],
              style: GoogleFonts.montserrat(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: isActive ? Colors.black : (isDark ? Colors.white : Colors.black),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '$price ₽',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isActive ? Colors.black : (isDark ? Colors.white : Colors.black),
                  ),
                ),
                if (oldPrice != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    '$oldPrice ₽',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE57373),
                      decoration: TextDecoration.lineThrough,
                      decorationColor: const Color(0xFFE57373),
                    ),
                  ),
                ],
                const SizedBox(width: 8),
                Text(
                  tariff['days_string'],
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    color: isActive ? Colors.black87 : (isDark ? Colors.white70 : Colors.black87),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              tariff['text'],
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
            if (services != null && services.isNotEmpty) ...[
              const SizedBox(height: 20),
              ...services.map((service) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check,
                          color: isActive ? const Color(0xFF4CAF8E) : const Color(0xff917dfa),
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            service['name'],
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              color: isActive ? Colors.black87 : (isDark ? Colors.white70 : Colors.black87),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }
}
