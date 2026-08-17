import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/core/network/packages_api_repository.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ListingPackagesScreen extends StatefulWidget {
  const ListingPackagesScreen({super.key});

  @override
  State<ListingPackagesScreen> createState() => _ListingPackagesScreenState();
}

class _ListingPackagesScreenState extends State<ListingPackagesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final PackagesApiRepository _packagesApi = PackagesApiRepository();

  bool _isLoading = true;
  String? _error;
  List<dynamic> _activePackages = [];
  List<dynamic> _completedPackages = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPackages();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
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
    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;

    print('🔵 [ListingPackagesScreen] User ID: ${user.id}');
    print('🔵 [ListingPackagesScreen] Token: ${token}...');

    final result = await _packagesApi.getOrdersPackages(
      userId: user.id,
      token: token ?? '',
    );

    if (result['status'] == true) {
      setState(() {
        _activePackages = result['active'] ?? [];
        _completedPackages = result['completed'] ?? [];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['error'] ?? 'Ошибка загрузки пакетов';
        _isLoading = false;
      });
    }
  }

  void _onBuyPackage() async {
    final result = await context.push('/listing-packages/add');
    // Если вернулись после успешной покупки, перезагружаем список
    if (result == true) {
      _loadPackages();
    }
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
          'Пакеты объявлений',
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
                        onPressed: _loadPackages,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Информационный блок + кнопка
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xff233040) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Удобный способ для тех, кто публикует много. Покупая пакет объявлений, вы платите меньше, чем при покупке единичного размещения. Пакет действует 30 дней!',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: isDark ? Colors.white70 : Colors.black87,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _onBuyPackage,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xff917dfa),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(30),
                                  ),
                                  elevation: 0,
                                ),
                                child: Text(
                                  'Купить пакет',
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
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Табы
                    TabBar(
                      controller: _tabController,
                      labelColor: isDark ? Colors.white : Colors.black,
                      unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
                      indicatorColor: isDark ? Colors.white : Colors.black,
                      indicatorWeight: 2,
                      labelStyle: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                      unselectedLabelStyle: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                      tabs: const [
                        Tab(text: 'Активные'),
                        Tab(text: 'Завершенные'),
                      ],
                    ),

                    // Содержимое табов
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildPackageList(
                            packages: _activePackages,
                            emptyMessage: 'Активных пакетов нет',
                            isActive: true,
                          ),
                          _buildPackageList(
                            packages: _completedPackages,
                            emptyMessage: 'Завершённых пакетов нет',
                            isActive: false,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildPackageList({
    required List<dynamic> packages,
    required String emptyMessage,
    required bool isActive,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (packages.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPackages,
        color: Color(0xff917dfa),
        edgeOffset: 40.0,
        displacement: 20.0,
        strokeWidth: 3.0,
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height - 300,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 140,
                    height: 140,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE0F2F1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.work_outline,
                      size: 72,
                      color: Color(0xFF4DB6AC),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    emptyMessage,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPackages,
      color: Color(0xff917dfa),
      edgeOffset: 40.0,
      displacement: 20.0,
      strokeWidth: 3.0,
      child: ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: packages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final pkg = packages[index];
        final progress = double.tryParse(pkg['progress'] ?? '0') ?? 0.0;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff233040) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xff917dfa).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.inventory_2_outlined,
                      color: Color(0xff917dfa),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pkg['category_name'] ?? 'Категория',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          pkg['count_ad'] ?? '',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        pkg['employed'] ?? '',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff917dfa),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        pkg['remain_day'] ?? '',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (isActive) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xff917dfa),
                    ),
                    minHeight: 6,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Создан: ${pkg['create_date'] ?? ''}',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: Colors.grey[400],
                ),
              ),
            ],
          ),
        );
      },
      ),
    );
  }
}
