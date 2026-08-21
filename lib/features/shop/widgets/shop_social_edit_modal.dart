// lib/features/shop/widgets/shop_social_edit_modal.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hive/hive.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';

class ShopSocialEditModal extends StatefulWidget {
  final Shop shop;
  final ShopApiRepository repository;

  const ShopSocialEditModal({
    Key? key,
    required this.shop,
    required this.repository,
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

    final links = widget.shop.links ?? [];

    // ✅ БЕРЕМ ПО ПОЗИЦИИ (1-я = Telegram, 2-я = VK, 3-я = Max)
    final telegramLink = links.length > 0 ? links[0].link ?? '' : '';
    final vkLink = links.length > 1 ? links[1].link ?? '' : '';
    final maxLink = links.length > 2 ? links[2].link ?? '' : '';

    print('🔗 [ShopSocialEditModal] initState');
    print('   telegramLink: $telegramLink');
    print('   vkLink: $vkLink');
    print('   maxLink: $maxLink');

    _telegramController = TextEditingController(text: telegramLink);
    _vkController = TextEditingController(text: vkLink);
    _maxController = TextEditingController(text: maxLink);
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
        padding: EdgeInsets.all(20),
        width: double.infinity, // ✅ РАСТЯГИВАЕТСЯ ПО ШИРИНЕ
        constraints: BoxConstraints(
          maxWidth: 300, // ✅ МАКСИМАЛЬНАЯ ШИРИНА (для планшетов/десктопа)
          maxHeight: MediaQuery.of(context).size.height * 0.6, // ✅ 60% ВЫСОТЫ
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '',
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
              'Укажите ссылки на ваши соцсети',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            SizedBox(height: 16),

            // ✅ СКРОЛЛИНГ ДЛЯ ПОЛЕЙ
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 8),
                child: Column(
                  children: [
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
                  ],
                ),
              ),
            ),

            SizedBox(height: 16),

            // Кнопки
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
    print('🔗 [ShopSocialEditModal] _saveSocial() START');

    final links = <ShopLink>[];

    final tgLink = _telegramController.text.trim();
    if (tgLink.isNotEmpty) {
      links.add(ShopLink(text: 'Telegram', link: tgLink));
      print('   Telegram: $tgLink');
    }

    final vkLink = _vkController.text.trim();
    if (vkLink.isNotEmpty) {
      links.add(ShopLink(text: 'VK', link: vkLink));
      print('   VK: $vkLink');
    }

    final maxLink = _maxController.text.trim();
    if (maxLink.isNotEmpty) {
      links.add(ShopLink(text: 'Max', link: maxLink));
      print('   Max: $maxLink');
    }

    print('📤 [ShopSocialEditModal] Total links: ${links.length}');

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
            // ✅ ИКОНКА В ФИОЛЕТОВОМ КРУГЕ
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: const Color(0xFF8956FF),
                borderRadius: BorderRadius.circular(80),
              ),
              child: Center(
                child: Image.network(
                  icon,
                  width: 16,
                  height: 16,
                  color: Colors.white,
                  errorBuilder: (_, __, ___) =>
                      Icon(Icons.link, size: 14, color: Colors.white),
                ),
              ),
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.url,
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
              borderSide: BorderSide(color: Color(0xFF8956FF), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 30),
          ),
        ),
      ],
    );
  }
}
