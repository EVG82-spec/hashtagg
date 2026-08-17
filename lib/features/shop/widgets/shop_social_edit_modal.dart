// lib/features/shop/widgets/shop_social_edit_modal.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class ShopSocialEditModal extends StatefulWidget {
  final Shop shop;

  const ShopSocialEditModal({Key? key, required this.shop}) : super(key: key);

  @override
  State<ShopSocialEditModal> createState() => _ShopSocialEditModalState();
}

class _ShopSocialEditModalState extends State<ShopSocialEditModal> {
  late TextEditingController _telegramController;
  late TextEditingController _vkController;
  late TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    // Инициализируем из links
    _telegramController = TextEditingController(
      text: widget.shop.links?.firstWhere(
            (l) => l.text?.toLowerCase().contains('telegram') == true,
        orElse: () => ShopLink(text: '', link: ''),
      ).link ?? '',
    );
    _vkController = TextEditingController(
      text: widget.shop.links?.firstWhere(
            (l) => l.text?.toLowerCase().contains('vk') == true,
        orElse: () => ShopLink(text: '', link: ''),
      ).link ?? '',
    );
    _maxController = TextEditingController(
      text: widget.shop.links?.firstWhere(
            (l) => l.text?.toLowerCase().contains('max') == true,
        orElse: () => ShopLink(text: '', link: ''),
      ).link ?? '',
    );
  }

  @override
  void dispose() {
    _telegramController.dispose();
    _vkController.dispose();
    _maxController.dispose();
    super.dispose();
  }

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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Редактировать соцсети',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.grey.shade400),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Введите ссылки на ваши социальные сети',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            SizedBox(height: 20),
            // Telegram
            _SocialInputField(
              icon: 'assets/icons/tg.png',
              label: 'Telegram',
              controller: _telegramController,
              placeholder: 'https://t.me/username',
            ),
            SizedBox(height: 14),
            // VK
            _SocialInputField(
              icon: 'assets/icons/vk.png',
              label: 'VK',
              controller: _vkController,
              placeholder: 'https://vk.com/username',
            ),
            SizedBox(height: 14),
            // Max
            _SocialInputField(
              icon: 'assets/icons/max.png',
              label: 'Max',
              controller: _maxController,
              placeholder: 'https://max.ru/username',
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Отмена'),
                ),
                SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _saveSocial,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF8956FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Сохранить', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveSocial() {
    // TODO: Сохранить соцсети через API
    Navigator.pop(context);
  }
}

class _SocialInputField extends StatelessWidget {
  final String icon;
  final String label;
  final TextEditingController controller;
  final String placeholder;

  const _SocialInputField({
    required this.icon,
    required this.label,
    required this.controller,
    required this.placeholder,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Image.asset(icon, width: 18, height: 18),
            SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
        SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: placeholder,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF8956FF)),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
      ],
    );
  }
}