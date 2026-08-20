// lib/features/shop/widgets/modals/shop_management_modal.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/features/shop/bloc/shop_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_event.dart';
import 'package:hashtagg/features/shop/bloc/shop_state.dart';
import 'package:hashtagg/core/routes.dart';

class ShopManagementModal extends StatelessWidget {
  final Shop shop;
  final ShopBloc shopBloc; // 👈 ПРИНИМАЕМ

  const ShopManagementModal({
    Key? key,
    required this.shop,
    required this.shopBloc, // 👈 ОБЯЗАТЕЛЬНЫЙ ПАРАМЕТР
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final modalContext = context;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(24),
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Управление магазином',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Выберите действие для вашего магазина',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
            SizedBox(height: 20),

            // 1. Редактировать магазин
            _ModalButton(
              title: 'Редактировать магазин',
              color: const Color(0xFF8956FF),
              icon: Icons.edit,
              onTap: () {
                Navigator.pop(context);
                context.push('/shop/edit/${shop.id}');
              },
            ),
            SizedBox(height: 12),

            // 2. Добавить страницу
            _ModalButton(
              title: 'Добавить страницу',
              color: Color(0xFF8956FF),
              icon: Icons.add,
              onTap: () {
                Navigator.pop(context);
                context.push('/shop/pages/add?shop_id=${shop.id}');
              },
            ),
            SizedBox(height: 12),

            // 3. Деактивировать (только если статус 1 - активен)
            if (shop.status == 1) ...[
              _ModalButton(
                title: 'Деактивировать магазин',
                color: Color(0xFFF59E0B),
                icon: Icons.pause,
                onTap: () {
                  Navigator.pop(context);
                  // ✅ ПЕРЕДАЕМ ВСЕ 4 АРГУМЕНТА
                  _showConfirmDialog(
                    context,
                    'Деактивировать магазин?',
                    'Магазин будет скрыт от пользователей',
                    () => _deactivateShop(context),
                  );
                },
              ),
              SizedBox(height: 12),
            ],

            // Кнопка "Удалить магазин"
            _ModalButton(
              title: 'Удалить магазин',
              color: Color(0xFFEF4444),
              icon: Icons.delete,
              onTap: () {
                print('👆👆👆 [ShopManagement] User tapped DELETE SHOP button');
                Navigator.pop(context);
                // ✅ ПЕРЕДАЕМ ВСЕ 4 АРГУМЕНТА
                _showConfirmDialog(
                  modalContext,
                  'Удалить магазин?',
                  'Это действие нельзя отменить. Все данные магазина будут удалены.',
                  () => _executeDelete(context),
                );
              },
            ),

            SizedBox(height: 16),

            _ModalButton(
              title: 'Закрыть',
              color: Color(0xFFF3F4F6),
              textColor: Color(0xFF374151),
              icon: Icons.close,
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onConfirm,
  ) {
    print('📢 [ShopManagement] _showConfirmDialog() called');

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              print('✅ [ShopManagement] Confirmed!');
              Navigator.pop(dialogContext);
              // ✅ ПЕРЕДАЕМ ТОТ ЖЕ КОНТЕКСТ, НО С ЗАДЕРЖКОЙ
              Future.delayed(const Duration(milliseconds: 50), () {
                onConfirm();
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: title.contains('Удалить')
                  ? Colors.red
                  : Color(0xFFF59E0B),
            ),
            child: Text(
              title.contains('Удалить') ? 'Удалить' : 'Деактивировать',
            ),
          ),
        ],
      ),
    );
  }

  void _executeDelete(BuildContext context) {
    print('🔥🔥🔥 [ShopManagement] _executeDelete() START');
    print('   shop.id: ${shop.id}');

    // ✅ ИСПОЛЬЗУЕМ rootNavigatorKey ИЗ routes.dart
    final rootContext = rootNavigatorKey.currentContext;

    if (rootContext == null) {
      print('❌ [ShopManagement] rootNavigatorKey.currentContext is null');
      return;
    }

    print('✅ [ShopManagement] Using global root context');

    // ✅ ПОКАЗЫВАЕМ ИНДИКАТОР НА ГЛОБАЛЬНОМ КОНТЕКСТЕ
    showDialog(
      context: rootContext,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final box = Hive.box('user');
      final userData = box.get('user');
      final token = box.get('auth_token');
      final userId = userData?['id'] as int? ?? 0;

      print('📤 [ShopManagement] userId: $userId');
      print('📤 [ShopManagement] shopId: ${shop.id}');

      shopBloc.add(DeleteShop(userId: userId, token: token, shopId: shop.id));

      _waitForDeletion(rootContext);
    } catch (e) {
      print('❌ [ShopManagement] ERROR: $e');
      if (rootContext.mounted) {
        Navigator.pop(rootContext);
        ScaffoldMessenger.of(
          rootContext,
        ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
  }

  void _deactivateShop(BuildContext context) {
    // TODO: API вызов деактивации
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Магазин деактивирован')));
  }

  void _deleteShop(BuildContext context) {
    print('🔥🔥🔥 [ShopManagement] _deleteShop() CALLED!');
    print('   shop.id: ${shop.id}');
    print('✅ [ShopManagement] Using shopBloc: $shopBloc');

    // ✅ ОТКЛАДЫВАЕМ ПОКАЗ ДИАЛОГА
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) {
        print('❌ [ShopManagement] Context not mounted, aborting');
        return;
      }

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Удалить магазин?'),
          content: Text(
            'Это действие нельзя отменить. Все данные магазина будут удалены.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () async {
                print('🔥🔥🔥 [ShopManagement] DELETE CONFIRMED!');
                Navigator.pop(dialogContext);

                if (!context.mounted) {
                  print('❌ [ShopManagement] Context not mounted after confirm');
                  return;
                }

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (_) =>
                      const Center(child: CircularProgressIndicator()),
                );

                try {
                  final box = Hive.box('user');
                  final userData = box.get('user');
                  final token = box.get('auth_token');
                  final userId = userData?['id'] as int? ?? 0;

                  print('📤 [ShopManagement] userId: $userId');
                  print('📤 [ShopManagement] shopId: ${shop.id}');

                  shopBloc.add(
                    DeleteShop(userId: userId, token: token, shopId: shop.id),
                  );

                  await _waitForDeletion(context);
                } catch (e) {
                  print('❌ [ShopManagement] ERROR: $e');
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                  }
                }
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Удалить'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _waitForDeletion(BuildContext context) async {
    print('⏳ [ShopManagement] _waitForDeletion() START');

    final completer = Completer<void>();
    late final StreamSubscription<ShopState> subscription;

    subscription = shopBloc.stream.listen((state) {
      print('📡 [ShopManagement] State: ${state.runtimeType}');

      if (state is ShopDeleted) {
        print('✅✅✅ [ShopManagement] ShopDeleted!');
        subscription.cancel();
        if (context.mounted) {
          Navigator.pop(context); // Закрываем индикатор
        }

        final box = Hive.box('user');
        box.delete('shop_id');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Магазин успешно удален'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context); // Возвращаемся на профиль
        }
        completer.complete();
      } else if (state is ShopError) {
        print('❌ [ShopManagement] ShopError: ${state.message}');
        subscription.cancel();
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message), backgroundColor: Colors.red),
          );
        }
        completer.complete();
      }
    });

    return completer.future;
  }
}

class _ModalButton extends StatelessWidget {
  final String title;
  final Color color;
  final Color? textColor;
  final IconData icon;
  final VoidCallback onTap;

  const _ModalButton({
    required this.title,
    required this.color,
    this.textColor,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 20),
        label: Text(
          title,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: textColor ?? Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}
