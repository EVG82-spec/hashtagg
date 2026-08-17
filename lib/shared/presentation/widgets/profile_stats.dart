import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class ProfileStats extends StatelessWidget {
  final double rating;
  final int reviews;
  final int listings;
  final int subscribers;
  final int? userId; // ID пользователя для перехода на отзывы

  const ProfileStats({
    super.key,
    this.rating = 0.0,
    this.reviews = 0,
    this.listings = 0,
    this.subscribers = 0,
    this.userId,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatItem(value: rating.toStringAsFixed(1), label: 'Рейтинг'),
        GestureDetector(
          onTap: userId != null
              ? () => context.push('/user/$userId/reviews')
              : null,
          child: _StatItem(
            value: reviews.toString(),
            label: 'Отзывы',
            isClickable: userId != null,
          ),
        ),
        _StatItem(value: listings.toString(), label: 'Объявлений'),
        _StatItem(value: subscribers.toString(), label: 'Подписчиков'),
      ],
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final bool isClickable;

  const _StatItem({
    required this.value,
    required this.label,
    this.isClickable = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isClickable 
                ? Color(0xff917dfa) 
                : (isDark ? Colors.white : Colors.black),
          ),
        ),
        Text(
          label,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            color: isClickable 
                ? Color(0xff917dfa) 
                : (isDark ? Colors.white70 : Colors.black87),
          ),
        ),
      ],
    );
  }
}
