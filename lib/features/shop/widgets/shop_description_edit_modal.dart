// lib/features/shop/widgets/shop_description_edit_modal.dart
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';

class ShopDescriptionEditModal extends StatefulWidget {
  final Shop shop;
  final ShopApiRepository repository;

  const ShopDescriptionEditModal({
    Key? key,
    required this.shop,
    required this.repository,
  }) : super(key: key);

  @override
  State<ShopDescriptionEditModal> createState() =>
      _ShopDescriptionEditModalState();
}

class _ShopDescriptionEditModalState extends State<ShopDescriptionEditModal> {
  late TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.shop.description ?? '');
    _controller.addListener(_updateCounter);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateCounter() {
    setState(() {});
  }

  Future<void> _save() async {
    final text = _controller.text.trim();

    // Проверяем длину (максимум 80 символов)
    if (text.length > 80) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Описание не должно превышать 80 символов'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final box = Hive.box('user');
      final userData = box.get('user');
      final token = box.get('auth_token');
      final userId = userData?['id'] as int? ?? 0;

      final result = await widget.repository.updateShop(
        userId: userId,
        token: token,
        shopId: widget.shop.id,
        title: widget.shop.title,
        description: text.isEmpty ? null : text,
      );

      setState(() => _isLoading = false);

      if (result['status'] == true) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Ошибка сохранения'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Изменить описание',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey.shade400),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Данный текст будет отображаться в карточке магазина в общем списке. Не более 80 символов.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLength: 80,
              maxLines: 4,
              minLines: 2,
              decoration: InputDecoration(
                hintText: 'Введите описание магазина...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                    color: const Color(0xFF8956FF),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                counterText: '', // Убираем стандартный счетчик
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '${_controller.text.length}/80',
                style: TextStyle(
                  fontSize: 12,
                  color: _controller.text.length > 80
                      ? Colors.red
                      : Colors.grey.shade500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Отмена'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8956FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Сохранить'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
