import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/features/auction/models/auction_place.dart';
import '../models/auction_status.dart';

class AuctionManualMode extends StatelessWidget {
  final AuctionStatus status;
  final bool isBidding;
  final ValueChanged<AuctionPlace> onBid; // 👈 было ValueChanged<int>

  const AuctionManualMode({
    Key? key,
    required this.status,
    required this.isBidding,
    required this.onBid,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final bgColor = isDark ? const Color(0xff2a2a3e) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xffe9ecef),
        ),
      ),
      child: Column(
        children: [
          // ── Заголовок таблицы ──
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1a1a2e),
              borderRadius: BorderRadius.vertical(top: Radius.circular(10)),
            ),
            child: Row(
              children: [
                _headerCell('Место', flex: 16),
                _headerCell('Магазин', flex: 30),
                _headerCell('Действие', flex: 18),
              ],
            ),
          ),

          // ── Строки ──
          if (status.topPlaces.isEmpty)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                'Нет данных',
                style: GoogleFonts.montserrat(
                  color: textColor.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
            )
          else
            ...status.topPlaces.map((place) => _buildRow(context, place)),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.montserrat(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          height: 1.1,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildRow(BuildContext context, AuctionPlace place) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    // 👈 Проверка блокировки "ниже своего места"
    final isBelowMyPlace =
        status.myPlace != null && place.place > status.myPlace!;

    // 👇 ПРАВИЛЬНАЯ ЛОГИКА:
    // Для проверки баланса нужно минимум, чтобы выкупить
    final hasEnoughBalance = status.balance >= place.minBidPrice;

    final bool canBid =
        status.isParticipant &&
        !place.isMyShop &&
        !isBelowMyPlace &&
        hasEnoughBalance;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: place.isMyShop
            ? (isDark
                  ? const Color(0xFFFFFBE6).withOpacity(0.08)
                  : const Color(0xFFFFFBE6))
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : const Color(0xfff1f3f5),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Место
          Expanded(
            flex: 16,
            child: Text(
              place.placeEmoji.isNotEmpty
                  ? place.placeEmoji
                  : '#${place.place}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Магазин
          Expanded(
            flex: 30,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                place.shopName,
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  fontWeight: place.isMyShop
                      ? FontWeight.w700
                      : FontWeight.w500,
                  color: place.isMyShop ? const Color(0xFF8956FF) : textColor,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // Действие
          Expanded(flex: 18, child: _buildActionButton(context, place, canBid)),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    AuctionPlace place,
    bool canBid,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 1. Моё место → «Ваше место»
    if (place.isMyShop) {
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            'Ваше место',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    // 2. Цена на кнопке:
    // - Пустое → startPrice
    // - Занятое → bidPrice (текущая цена)
    final displayPrice = place.isEmpty ? place.startPrice : place.bidPrice;
    final actionText = place.isEmpty
        ? 'Занять ${displayPrice.toInt()}₽'
        : '↑ ${displayPrice.toInt()}₽';

    return Center(
      child: SizedBox(
        height: 32,
        child: ElevatedButton(
          onPressed: canBid && !isBidding ? () => onBid(place) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canBid
                ? const Color(0xFF2ecc71)
                : const Color(0xFFe0e0e0),
            foregroundColor: canBid ? Colors.white : Colors.grey,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            elevation: 0,
          ),
          child: isBidding
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  actionText,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
        ),
      ),
    );
  }
}
