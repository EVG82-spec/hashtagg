import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/core/models/shop.dart';

class ShopStatsScreen extends StatelessWidget {
  final Shop shop;

  const ShopStatsScreen({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Статистика магазина',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // TODO: Обновление статистики
          await Future.delayed(Duration(seconds: 1));
        },
        color: Color(0xff917dfa),
        child: SingleChildScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Основные метрики
              _buildSectionTitle('Основные показатели', isDark),
              SizedBox(height: 12),
              _buildMetricsGrid(isDark),
              SizedBox(height: 24),

              // Контент
              _buildSectionTitle('Контент', isDark),
              SizedBox(height: 12),
              _buildContentStats(isDark),
              SizedBox(height: 24),

              // Информация
              _buildInfoCard(isDark),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black,
      ),
    );
  }

  Widget _buildMetricsGrid(bool isDark) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.shopping_bag_outlined,
                value: shop.adsCount.toString(),
                label: 'Объявления',
                color: Colors.blue,
                isDark: isDark,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.inventory_2_outlined,
                value: shop.adsCount.toString(),
                label: 'Товары',
                color: Colors.green,
                isDark: isDark,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.people_outline,
                value: shop.subscribersCount.toString(),
                label: 'Подписчики',
                color: Colors.orange,
                isDark: isDark,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.store_outlined,
                value: shop.isActive ? 'Активен' : 'Неактивен',
                label: 'Статус',
                color: shop.isActive ? Colors.green : Colors.grey,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentStats(bool isDark) {
    final pagesCount = shop.pages?.length ?? 0;
    final slidersCount = shop.sliders?.length ?? 0;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildContentRow(
            icon: Icons.description_outlined,
            label: 'Страницы',
            value: '$pagesCount / 10',
            progress: pagesCount / 10,
            isDark: isDark,
          ),
          SizedBox(height: 16),
          _buildContentRow(
            icon: Icons.photo_library_outlined,
            label: 'Слайдеры',
            value: '$slidersCount / 4',
            progress: slidersCount / 4,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildContentRow({
    required IconData icon,
    required String label,
    required String value,
    required double progress,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Color(0xff917dfa), size: 20),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xff917dfa),
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xff917dfa)),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard(bool isDark) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xff917dfa).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Color(0xff917dfa).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xff917dfa)),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Статистика обновляется каждые 24 часа',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
