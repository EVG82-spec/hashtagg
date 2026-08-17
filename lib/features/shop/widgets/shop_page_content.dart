// lib/features/shop/widgets/shop_page_content.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class ShopPageContent extends StatelessWidget {
  final ShopPage page;

  const ShopPageContent({Key? key, required this.page}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final content = page.text;

    return Container(
      padding: EdgeInsets.all(16),
      child: content.isNotEmpty
          ? Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (page.name.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text(
                page.name,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1F29),
                ),
              ),
            ),
          Text(
            content,
            style: TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ],
      )
          : Center(
        child: Text(
          'Страница без содержимого',
          style: TextStyle(
            color: Colors.grey.shade500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}