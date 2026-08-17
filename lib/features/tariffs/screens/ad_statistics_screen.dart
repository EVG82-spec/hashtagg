import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/core/network/tariffs_api_repository.dart';

class AdStatisticsScreen extends StatefulWidget {
  final int adId;

  const AdStatisticsScreen({
    super.key,
    required this.adId,
  });

  @override
  State<AdStatisticsScreen> createState() => _AdStatisticsScreenState();
}

class _AdStatisticsScreenState extends State<AdStatisticsScreen> {
  final TariffsApiRepository _tariffsApi = TariffsApiRepository();

  bool _isLoading = true;
  String? _error;
  List<dynamic> _items = [];
  Map<String, dynamic> _dates = {};
  List<dynamic>? _activeUsers;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
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

    final result = await _tariffsApi.getStatisticsAd(
      userId: user.id,
      token: user.token ?? '',
      adId: widget.adId,
    );

    if (result['status'] == true) {
      final data = result['data'];
      setState(() {
        _items = data['items'] ?? [];
        _dates = data['dates'] ?? {};
        _activeUsers = data['active_users'];
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = result['error'] ?? 'Ошибка загрузки статистики';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Статистика объявления',
          style: GoogleFonts.montserrat(
            color: Colors.black,
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
                        onPressed: _loadStatistics,
                        child: const Text('Повторить'),
                      ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Метрики
                    Text(
                      'Метрики',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._items.map((item) {
                      final code = item['code'];
                      final value = _dates[code] ?? 0;
                      return _buildMetricCard(
                        name: item['name'],
                        value: value.toString(),
                      );
                    }),

                    // Активные пользователи
                    if (_activeUsers != null && _activeUsers!.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      Text(
                        'Активные пользователи',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._activeUsers!.map((user) => _buildUserCard(user)),
                    ],
                  ],
                ),
    );
  }

  Widget _buildMetricCard({required String name, required String value}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xff917dfa),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(dynamic user) {
    final history = user['history'] as List?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: user['avatar'] != null && user['avatar'] != ''
                    ? NetworkImage(user['avatar'])
                    : null,
                child: user['avatar'] == null || user['avatar'] == ''
                    ? const Icon(Icons.person, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  user['name'] ?? 'Пользователь',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (history != null && history.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            ...history.map((action) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.circle,
                        size: 6,
                        color: Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${action['action']}: ${action['title']}',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }
}
