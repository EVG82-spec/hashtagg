// lib/features/shop/widgets/shop_navigation.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_state.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/features/shop/screens/shop_page_edit_screen.dart';
import 'package:hashtagg/features/shop/widgets/shop_lock_widget.dart';

class ShopNavigation extends StatelessWidget {
  final Shop shop;
  final bool isEditing;
  final VoidCallback? onAddPage;
  final Function(int)? onPageSelected;
  final Function(int)? onPageEdit;
  final int? currentPageId;

  const ShopNavigation({
    Key? key,
    required this.shop,
    this.isEditing = false,
    this.onAddPage,
    this.onPageSelected,
    this.onPageEdit,
    this.currentPageId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final pages = shop.pages ?? [];
    final isOwner = shop.isOwner;

    // ✅ БЕЗОПАСНОЕ ПОЛУЧЕНИЕ ТАРИФА (ОДИН РАЗ!)
    final tariff = context.select<ShopPublicBloc, UserTariff?>((bloc) {
      final state = bloc.state;
      if (state is ShopPublicLoaded) {
        return state.tariff;
      }
      return null;
    });

    final hasShopPage = tariff?.hasService('shop_page') ?? false;
    final isDraft = shop.status == 4;
    final isModeration = shop.status == 0;

    print('🔍 [ShopNavigation] build()');
    print('   pages count: ${pages.length}');
    print('   isEditing: $isEditing');
    print('   currentPageId: $currentPageId');
    print('   hasShopPage: $hasShopPage');

    // ============================================================
    // НЕТ СТРАНИЦ
    // ============================================================
    if (pages.isEmpty) {
      // Если есть услуга - показываем кнопку "Добавить страницу"
      if (isEditing && isOwner && hasShopPage && onAddPage != null) {
        return _buildAddPageButton();
      }

      // Если нет услуги и черновик/модерация - замочек
      if (isEditing && isOwner && (isDraft || isModeration) && !hasShopPage) {
        return ShopLockWidget(
          message: '🔒 Страницы доступны в тарифах «Максимум» и «Безлимит»',
        );
      }

      return const SizedBox.shrink();
    }

    // ============================================================
    // ЕСТЬ СТРАНИЦЫ
    // ============================================================
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
        ),
      ),
      child: Column(
        children: [
          // Навигация по страницам
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Главная
                _NavButton(
                  title: 'Главная',
                  isActive: currentPageId == null,
                  onTap: () {
                    print('🏠 [ShopNavigation] Главная');
                    if (onPageSelected != null) {
                      onPageSelected!(0);
                    }
                  },
                ),
                const SizedBox(width: 6),
                // Страницы с кнопками редактирования/удаления
                if (pages.isNotEmpty)
                  ...pages.map(
                    (page) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _NavButton(
                            title: page.name,
                            isActive: currentPageId == page.id,
                            onTap: () {
                              print(
                                '📄 [ShopNavigation] Страница: ${page.name} (id: ${page.id})',
                              );
                              if (onPageSelected != null) {
                                onPageSelected!(page.id);
                              }
                            },
                          ),
                          // ✅ Кнопка редактирования страницы (только в режиме редактора)
                          if (isEditing && isOwner && hasShopPage)
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: GestureDetector(
                                onTap: () {
                                  print(
                                    '✏️ [ShopNavigation] Edit page: ${page.id}',
                                  );
                                  _openPageEdit(context, page);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF8956FF,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.edit,
                                    size: 14,
                                    color: const Color(0xFF8956FF),
                                  ),
                                ),
                              ),
                            ),
                          // ✅ Кнопка удаления страницы (только в режиме редактора)
                          if (isEditing && isOwner && hasShopPage)
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: GestureDetector(
                                onTap: () {
                                  print(
                                    '🗑️ [ShopNavigation] Delete page: ${page.id}',
                                  );
                                  _showDeletePageDialog(context, page);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Icon(
                                    Icons.close,
                                    size: 14,
                                    color: Colors.red,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Кнопка "Добавить страницу" (если есть услуга)
          if (isEditing && isOwner && hasShopPage && onAddPage != null)
            _buildAddPageButton(),
          // Замочек (если нет услуги и черновик/модерация)
          if (isEditing && isOwner && (isDraft || isModeration) && !hasShopPage)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ShopLockWidget(
                message:
                    '🔒 Страницы доступны в тарифах «Максимум» и «Безлимит»',
              ),
            ),
        ],
      ),
    );
  }

  // ✅ КНОПКА "ДОБАВИТЬ СТРАНИЦУ"
  Widget _buildAddPageButton() {
    return Padding(
      padding: const EdgeInsets.only(top: 12, left: 4, right: 4),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: onAddPage,
          icon: const Icon(Icons.add, size: 18, color: Colors.white),
          label: const Text(
            'Добавить страницу',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF8956FF),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            minimumSize: const Size(double.infinity, 48),
          ),
        ),
      ),
    );
  }

  // ✅ ОТКРЫТИЕ РЕДАКТОРА СТРАНИЦЫ
  void _openPageEdit(BuildContext context, ShopPage page) {
    final shopId = shop.id;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopPageEditScreen(shopId: shopId, page: page),
      ),
    ).then((result) {
      if (result == true) {
        print('✅ [ShopNavigation] Page updated, reloading...');
        // TODO: Обновить данные магазина
      }
    });
  }

  // ✅ ДИАЛОГ УДАЛЕНИЯ СТРАНИЦЫ
  void _showDeletePageDialog(BuildContext context, ShopPage page) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить страницу?'),
        content: Text('Страница "${page.name}" будет удалена безвозвратно'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _deletePage(context, page);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  // ✅ УДАЛЕНИЕ СТРАНИЦЫ
  void _deletePage(BuildContext context, ShopPage page) {
    print('🗑️ [ShopNavigation] Deleting page: ${page.id}');

    // TODO: Вызвать DeleteShopPage через BLoC
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Страница удалена'),
        backgroundColor: Colors.green,
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String title;
  final bool isActive;
  final VoidCallback onTap;

  const _NavButton({
    required this.title,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? Color(0xFFDCF4FF) : Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(24),
          border: isActive
              ? Border.all(color: Color(0xFF8956FF), width: 1.5)
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isActive ? Color(0xFF8956FF) : Color(0xFF1A1F29),
          ),
        ),
      ),
    );
  }
}
