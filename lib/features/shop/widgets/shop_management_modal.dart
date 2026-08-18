// lib/features/shop/widgets/modals/shop_management_modal.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class ShopManagementModal extends StatelessWidget {
  final Shop shop;

  const ShopManagementModal({Key? key, required this.shop}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: EdgeInsets.all(24),
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
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
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
              ),
            ),
            SizedBox(height: 20),

            // 1. Редактировать магазин
            // Кнопка "Редактировать магазин"
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

            // 4. Удалить магазин
            _ModalButton(
              title: 'Удалить магазин',
              color: Color(0xFFEF4444),
              icon: Icons.delete,
              onTap: () {
                Navigator.pop(context);
                _showConfirmDialog(
                  context,
                  'Удалить магазин?',
                  'Это действие нельзя отменить',
                      () => _deleteShop(context),
                );
              },
            ),
            SizedBox(height: 16),

            // 5. Закрыть
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

  void _showConfirmDialog(BuildContext context, String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            style: TextButton.styleFrom(
              foregroundColor: Color(0xFFEF4444),
            ),
            child: Text('Удалить'),
          ),
        ],
      ),
    );
  }

  void _deactivateShop(BuildContext context) {
    // TODO: API вызов деактивации
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Магазин деактивирован')),
    );
  }

  void _deleteShop(BuildContext context) {
    // TODO: API вызов удаления
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Магазин удален')),
    );
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
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
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