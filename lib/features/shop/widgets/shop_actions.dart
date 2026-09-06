// lib/features/shop/widgets/shop_actions.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_event.dart';
import 'package:hashtagg/features/shop/widgets/shop_description_edit_modal.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/features/shop/bloc/shop_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_state.dart';
import 'package:hashtagg/features/shop/widgets/shop_lock_widget.dart';
import 'package:hashtagg/features/shop/widgets/shop_subscription_button.dart';
import 'package:hashtagg/features/shop/widgets/shop_management_modal.dart';
import 'package:hashtagg/features/shop/widgets/shop_qr_widget.dart';

import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'dart:io';

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

  void _showQRModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7, //высота модалки куара
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xff1a1a2e)
              : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Индикатор
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            // ✅ ИСПОЛЬЗУЕМ ГОТОВЫЙ ВИДЖЕТ
            ShopQrWidget(shop: shop),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = shop.isOwner;
    final isDraft = shop.status == 4;
    final isModeration = shop.status == 0;

    // ✅ БЕЗОПАСНОЕ ПОЛУЧЕНИЕ ТАРИФА
    final tariff = context.select<ShopPublicBloc, UserTariff?>((bloc) {
      final state = bloc.state;
      if (state is ShopPublicLoaded) {
        return state.tariff;
      }
      return null;
    });

    // ✅ Есть ли ссылки в магазине (независимо от тарифа)
    final hasLinks = shop.links != null && shop.links!.isNotEmpty;

    // ✅ Есть ли услуга shop_links (для РЕДАКТИРОВАНИЯ владельцем)
    final hasService =
        tariff?.hasService('shop_links') ?? false; // 👈 ОСТАВЛЯЕМ!

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
          //_buildBreadcrumbs(context),
          const SizedBox(height: 10),

          // ── Строка 1: Кнопка управления + Соцсети ──
          Row(
            children: [
              // ✅ КНОПКА С ФИКСИРОВАННОЙ ШИРИНОЙ И ВЫРАВНИВАНИЕМ ВЛЕВО
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 160, // 👈 ФИКСИРОВАННАЯ ШИРИНА
                  child: isOwner
                      ? ElevatedButton(
                          onPressed: () => _showShopManagement(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8956FF),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            minimumSize: const Size(double.infinity, 48),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Управление',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        )
                      : ShopSubscriptionButton(shop: shop),
                ),
              ),
              // QR-КНОПКА
              GestureDetector(
                onTap: () => _showQRModal(context),
                child: Container(
                  width: 50,
                  height: 50,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8956FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF8956FF).withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.qr_code,
                    color: Color(0xFF8956FF),
                    size: 40,
                  ),
                ),
              ),

              // ✅ ИКОНКИ СОЦСЕТЕЙ (ВЫРАВНЕНЫ ВПРАВО)
              if (hasLinks)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8956FF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
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
                            iconUrl:
                                'https://hashtagg.ru/templates/img/max.png',
                            url: socialLinks['max'] ?? '',
                            isEditing: isEditing,
                            label: 'Max',
                            onEdit: onSocialEdit,
                          ),
                          // Карандаш (только в режиме редактора)
                          if (isEditing && onSocialEdit != null && hasService)
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
                  ),
                ),

              // ЕСЛИ НЕТ УСЛУГИ И ЭТО ЧЕРНОВИК/МОДЕРАЦИЯ - ЗАМОЧЕК
              if (!hasService &&
                  isOwner &&
                  isEditing &&
                  (isModeration || isDraft))
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: ShopLockWidget(
                      message:
                          '🔒 Соцсети доступны в тарифах «Максимум» и «Безлимит»',
                    ),
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

          // ── Строка 3: Редактировать описание (только для владельца) ──
          if (isOwner && isEditing) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _editDescription(context),
                icon: Icon(
                  Icons.edit,
                  size: 18,
                  color: const Color(0xFF8956FF),
                ),
                label: Text(
                  shop.description?.isNotEmpty == true
                      ? 'Редактировать описание'
                      : 'Добавить описание',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF8956FF),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFF8956FF)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
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

  // Вместо заглушки _handleSubscribe
  void _handleSubscribe(BuildContext context) {
    // Ничего не делаем - кнопка сама обрабатывает через Bloc
  }

  void _showShopManagement(BuildContext context) {
    print('🔧 [ShopActions] Opening management modal');
    final shopBloc = BlocProvider.of<ShopBloc>(context);
    showDialog(
      context: context,
      builder: (_) => ShopManagementModal(shop: shop, shopBloc: shopBloc),
    );
  }

  void _editDescription(BuildContext context) {
    print('📝 [ShopActions] Edit description');

    // Получаем текущий shop через контекст
    final shop = this.shop;

    showDialog(
      context: context,
      builder: (_) => ShopDescriptionEditModal(
        shop: shop,
        repository: context.read<ShopPublicBloc>().repository,
      ),
    ).then((result) {
      if (result == true) {
        print('✅ [ShopActions] Description updated');
        // Перезагружаем данные
        context.read<ShopPublicBloc>().add(
          LoadPublicShop(shopId: shop.id.toString(), forceRefresh: true),
        );
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Описание обновлено!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
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
