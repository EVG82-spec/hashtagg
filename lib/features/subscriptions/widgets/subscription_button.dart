import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/shared/presentation/bloc/subscriptions_bloc.dart';

class SubscriptionButton extends StatelessWidget {
  final User user;

  const SubscriptionButton({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SubscriptionsBloc, SubscriptionsState>(
      builder: (context, state) {
        final isSubscribed = state.ids.contains(user.id);

        return GestureDetector(
          onTap: () {
            final bloc = context.read<SubscriptionsBloc>();
            if (isSubscribed) {
              bloc.add(RemoveSubscription(user.id));
            } else {
              // ✅ ИСПОЛЬЗУЙ ИМЕНОВАННЫЙ КОНСТРУКТОР
              bloc.add(
                AddSubscription(
                  userId: user.id,
                  shopId: 0, // 👈 Для обычных пользователей shopId = 0
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
            child: Text(
              isSubscribed ? 'Отписаться' : 'Подписаться',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: isSubscribed ? const Color(0xff917dfa) : Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        );
      },
    );
  }
}
