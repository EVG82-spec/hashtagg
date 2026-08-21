// lib/features/shop/widgets/shop_actions.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/features/shop/bloc/shop_bloc.dart';
import 'package:go_router/go_router.dart';
import 'shop_management_modal.dart';

class ShopActions extends StatelessWidget {
  final Shop shop;
  final bool isEditing;
  final VoidCallback? onSocialEdit;

  const ShopActions({
    Key? key,
    required this.shop,
    this.isEditing = false,
    this.onSocialEdit,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isOwner = shop.isOwner;

    // Берем ссылки из shop.links
    final Map<String, String> socialLinks = {};
    if (shop.links != null) {
      for (int i = 0; i < shop.links!.length && i < 3; i++) {
        final link = shop.links![i];
        if (link.link != null && link.link!.isNotEmpty) {
          if (i == 0)
            socialLinks['telegram'] = link.link!;
          else if (i == 1)
            socialLinks['vk'] = link.link!;
          else if (i == 2)
            socialLinks['max'] = link.link!;
        }
      }
    }

    print('🔗 [ShopActions] socialLinks: $socialLinks');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ХЛЕБНЫЕ КРОШКИ ──
          _buildBreadcrumbs(context),

          const SizedBox(height: 10),

          // ── Строка 1: Кнопка управления + Соцсети ──
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (isOwner) {
                      _showShopManagement(context);
                    } else {
                      _handleSubscribe(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8956FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    minimumSize: const Size(double.infinity, 48),
                    elevation: 0,
                  ),
                  child: Text(
                    isOwner ? 'Управление' : 'Подписаться',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              // ✅ ИКОНКИ СОЦСЕТЕЙ
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF8956FF),
                  borderRadius: BorderRadius.circular(80),
                ),
                child: Row(
                  children: [
                    _SocialIcon(
                      iconUrl: 'https://hashtagg.ru/templates/img/tg.png',
                      url: socialLinks['telegram'] ?? '',
                      isEditing: isEditing,
                      label: 'Telegram',
                      onEdit: onSocialEdit,
                    ),
                    const SizedBox(width: 5),
                    _SocialIcon(
                      iconUrl: 'https://hashtagg.ru/templates/img/vk.png',
                      url: socialLinks['vk'] ?? '',
                      isEditing: isEditing,
                      label: 'VK',
                      onEdit: onSocialEdit,
                    ),
                    const SizedBox(width: 5),
                    _SocialIcon(
                      iconUrl: 'https://hashtagg.ru/templates/img/max.png',
                      url: socialLinks['max'] ?? '',
                      isEditing: isEditing,
                      label: 'Max',
                      onEdit: onSocialEdit,
                    ),
                    // ✅ КАРАНДАШИК (только в режиме редактора)
                    if (isEditing && onSocialEdit != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          onTap: onSocialEdit,
                          child: Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),

          // ── Строка 2: Добавить товар (только для владельца) ──
          if (isOwner) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.push('/listing-add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8956FF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  minimumSize: const Size(double.infinity, 48),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add, size: 20, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text(
                      'Добавить товар',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Табы (навигация) ──
          const SizedBox(height: 10),
          _buildNavigationTabs(context),
        ],
      ),
    );
  }

  // ✅ ХЛЕБНЫЕ КРОШКИ (слабо-голубой стиль)
  Widget _buildBreadcrumbs(BuildContext context) {
    final pages = shop.pages ?? [];
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Главная
            Text(
              'Главная',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Color(0xFF008EFF),
                fontWeight: FontWeight.w500,
              ),
            ),

            // Если есть страницы - показываем их
            if (pages.isNotEmpty) ...[
              Text(
                ' / ',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
              // Все товары (активная страница)
              Text(
                'Все товары',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
              // Остальные страницы
              ...pages.map((page) {
                return Row(
                  children: [
                    Text(
                      ' / ',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    Text(
                      page.name,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? Colors.grey.shade500
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ] else ...[
              // Если страниц нет - показываем только "Все товары"
              Text(
                ' / ',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
              ),
              Text(
                'Все товары',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNavigationTabs(BuildContext context) {
    final pages = shop.pages ?? [];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ...pages.map(
            (page) => Padding(
              padding: EdgeInsets.only(left: 8),
              child: _NavTab(
                title: page.name,
                isActive: false,
                onTap: () {
                  print('📄 [ShopActions] Страница: ${page.name}');
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleSubscribe(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Функция подписки в разработке'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showShopManagement(BuildContext context) {
    print('🔧 [ShopActions] Opening management modal');
    final shopBloc = BlocProvider.of<ShopBloc>(context);
    showDialog(
      context: context,
      builder: (_) => ShopManagementModal(shop: shop, shopBloc: shopBloc),
    );
  }
}

// ============================================================
// ВСПОМОГАТЕЛЬНЫЙ ВИДЖЕТ - ИКОНКА СОЦСЕТИ
// ============================================================
class _SocialIcon extends StatelessWidget {
  final String iconUrl;
  final String url;
  final bool isEditing;
  final String label;
  final VoidCallback? onEdit;

  const _SocialIcon({
    required this.iconUrl,
    required this.url,
    required this.isEditing,
    required this.label,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        if (url.isNotEmpty) {
          final uri = Uri.parse(url);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } else if (isEditing) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Добавьте ссылку для $label через карандаш ✏️'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Image.network(
            iconUrl,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            color: Colors.white,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.link, size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// ВСПОМОГАТЕЛЬНЫЙ ВИДЖЕТ - ТАБ НАВИГАЦИИ
// ============================================================
class _NavTab extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _NavTab({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? Color(0xFF8956FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isActive ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }
}
