// lib/features/shop/widgets/shop_social_edit_modal.dart
import 'package:flutter/material.dart';

import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hive/hive.dart';

import 'package:hashtagg/core/network/shop_api_repository.dart'; // 👈 ДОБАВИТЬ

class ShopSocialEditModal extends StatefulWidget {
  final Shop shop;
  final ShopApiRepository repository; // 👈 ДОБАВИТЬ

  const ShopSocialEditModal({
    Key? key,
    required this.shop,
    required this.repository, // 👈 ОБЯЗАТЕЛЬНО
  }) : super(key: key);

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
      text:
          widget.shop.links
              ?.firstWhere(
                (l) => l.text?.toLowerCase().contains('telegram') == true,
                orElse: () => ShopLink(text: '', link: ''),
              )
              .link ??
          '',
    );
    _vkController = TextEditingController(
      text:
          widget.shop.links
              ?.firstWhere(
                (l) => l.text?.toLowerCase().contains('vk') == true,
                orElse: () => ShopLink(text: '', link: ''),
              )
              .link ??
          '',
    );
    _maxController = TextEditingController(
      text:
          widget.shop.links
              ?.firstWhere(
                (l) => l.text?.toLowerCase().contains('max') == true,
                orElse: () => ShopLink(text: '', link: ''),
              )
              .link ??
          '',
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
              icon: 'https://hashtagg.ru/templates/img/tg.png',
              label: 'Telegram',
              controller: _telegramController,
              placeholder: 'https://t.me/username',
            ),
            SizedBox(height: 14),
            // VK
            _SocialInputField(
              icon: 'https://hashtagg.ru/templates/img/vk.png',
              label: 'VK',
              controller: _vkController,
              placeholder: 'https://vk.com/username',
            ),
            SizedBox(height: 14),
            // Max
            _SocialInputField(
              icon: 'https://hashtagg.ru/templates/img/max.png',
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
                  child: Text(
                    'Сохранить',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _saveSocial() async {
    print('🔗 [ShopSocialEditModal] Saving social links');

    final links = <ShopLink>[];

    final tgLink = _telegramController.text.trim();
    print('   Telegram raw: "$tgLink"');
    if (tgLink.isNotEmpty) {
      links.add(ShopLink(text: 'Telegram', link: tgLink));
      print('   ✅ Telegram added');
    }

    final vkLink = _vkController.text.trim();
    print('   VK raw: "$vkLink"');
    if (vkLink.isNotEmpty) {
      links.add(ShopLink(text: 'VK', link: vkLink));
      print('   ✅ VK added');
    }

    final maxLink = _maxController.text.trim();
    print('   Max raw: "$maxLink"');
    if (maxLink.isNotEmpty) {
      links.add(ShopLink(text: 'Max', link: maxLink));
      print('   ✅ Max added');
    }

    print('📤 [ShopSocialEditModal] Links to save: $links');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final box = Hive.box('user');
      final userData = box.get('user');
      final token = box.get('auth_token');
      final userId = userData?['id'] as int? ?? 0;

      // ✅ ИСПОЛЬЗУЕМ РЕПОЗИТОРИЙ ИЗ ПАРАМЕТРОВ
      final result = await widget.repository.updateShop(
        userId: userId,
        token: token,
        shopId: widget.shop.id,
        title: widget.shop.title,
        links: links,
      );

      Navigator.pop(context);

      if (result['status'] == true) {
        print('✅ [ShopSocialEditModal] Social links saved');
        Navigator.pop(context, true);
      } else {
        print('❌ [ShopSocialEditModal] Failed: ${result['error']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Ошибка сохранения'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌❌❌ [ShopSocialEditModal] ERROR: $e');
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
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
            Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
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
