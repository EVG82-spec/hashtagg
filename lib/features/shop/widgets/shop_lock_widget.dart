// lib/features/shop/widgets/shop_lock_widget.dart
import 'package:flutter/material.dart';

class ShopLockWidget extends StatelessWidget {
  final String message;
  final double? height;

  const ShopLockWidget({
    Key? key,
    required this.message,
    this.height,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height ?? 48,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 16,
            color: Colors.grey.shade500,
          ),
          const SizedBox(width: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}