// lib/features/shop/screens/shop_empty_promo_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:dio/dio.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';

class ShopEmptyPromoScreen extends StatelessWidget {
  final bool hasTariff;

  const ShopEmptyPromoScreen({
    Key? key,
    required this.hasTariff,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff151e27) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xff151e27) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Магазин',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Откройте свой онлайн-магазин',
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Превратите свой профиль в полноценный онлайн-магазин с рекламной обложкой, удобными фильтрами, персональными страницами и поиском',
              style: GoogleFonts.montserrat(
                fontSize: 15,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
                height: 1.5,
              ),
            ),
            const Spacer(),
            Center(
              child: Icon(
                Icons.storefront,
                size: 120,
                color: isDark ? Colors.white54 : Colors.grey.shade300,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: hasTariff
                    ? () => _openShop(context)
                    : () => _goToTariffs(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8956FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  hasTariff ? 'Открыть магазин' : 'Подключить тариф',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _openShop(BuildContext context) async {
    print('🏪 [ShopEmpty] Открыть магазин');

    try {
      final box = Hive.box('user');
      final userData = box.get('user');
      final token = box.get('auth_token');

      if (userData == null || token == null) {
        print('❌ [ShopEmpty] No user data or token');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка: пользователь не авторизован')),
        );
        return;
      }

      final userId = userData['id'] is int
          ? userData['id']
          : int.tryParse(userData['id'].toString()) ?? 0;

      final dio = Dio(BaseOptions(
        baseUrl: 'https://hashtagg.ru',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ));
      final repository = ShopApiRepository(dio);

      final result = await repository.createShop(
        userId: userId,
        token: token,
      );

      print('📦 [ShopEmpty] Create shop result: $result');

      if (result['status'] == true) {
        // ✅ ПРЕОБРАЗУЕМ String В int
        final shopId = result['id'] is String
            ? int.tryParse(result['id'].toString()) ?? 0
            : result['id'] as int;

        print('✅ [ShopEmpty] Shop created with id: $shopId');

        await box.put('shop_id', shopId);
        context.pushReplacement('/shop/$shopId');

      } else {
        print('❌ [ShopEmpty] Failed to create shop: ${result['error']}');
        // ⚠️ Ошибку показываем
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Ошибка создания магазина'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ [ShopEmpty] Error: $e');
      // ⚠️ Ошибку показываем
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _goToTariffs(BuildContext context) {
    context.push('/tariffs');
  }
}