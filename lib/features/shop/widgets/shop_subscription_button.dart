//G:\hashtagg_app\lib\features\shop\widgets\shop_subscription_button.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/shared/presentation/bloc/subscriptions_bloc.dart';

class ShopSubscriptionButton extends StatelessWidget {
  final Shop shop;

  const ShopSubscriptionButton({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscriptionsBloc, SubscriptionsState>(
      builder: (context, state) {
        final isSubscribed = state.ids.contains(shop.userId);

        // ✅ ДОБАВЛЯЕМ ПРИНТ СТАТУСА
        print('🔵 [ShopSubscriptionButton] shop.userId: ${shop.userId}');
        print('🔵 [ShopSubscriptionButton] isSubscribed: $isSubscribed');
        print('🔵 [ShopSubscriptionButton] state.ids: ${state.ids}');

        return GestureDetector(
          onTap: () {
            print('👆 [ShopSubscriptionButton] TAPPED!');
            print('   isSubscribed: $isSubscribed');
            print('   shop.userId: ${shop.userId}');

            final bloc = context.read<SubscriptionsBloc>();
            if (isSubscribed) {
              print(
                '📤 [ShopSubscriptionButton] Removing subscription for: ${shop.userId}',
              );
              bloc.add(RemoveSubscription(shop.userId));
            } else {
              print(
                '📤 [ShopSubscriptionButton] Adding subscription for: ${shop.userId}',
              );
              final user = User(
                id: shop.userId,
                name: shop.title,
                avatar: shop.avatarUrl ?? '',
              );
              bloc.add(
                AddSubscription(
                  userId: shop.userId,
                  shopId: shop.id,
                  user: user,
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSubscribed ? Colors.white : const Color(0xff917dfa),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xff917dfa), width: 1),
            ),
            child: Center(
              child: Text(
                isSubscribed ? 'Отписаться' : 'Подписаться',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: isSubscribed ? const Color(0xff917dfa) : Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
