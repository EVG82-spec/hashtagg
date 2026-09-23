import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/auction_status.dart';

class AuctionManualMode extends StatelessWidget {
  final AuctionStatus status;
  final bool isBidding;
  final ValueChanged<int> onBid;

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
                _headerCell('Текущая\nставка', flex: 18),
                _headerCell('Следующая\nставка', flex: 18),
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

  Widget _buildRow(BuildContext context, place) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    // Логика кнопки:
    // 1. Моё место → заблокирована
    // 2. Баланс < цена → заблокирована
    // 3. Пустое → "Занять за X ₽"
    // 4. Чужое → "↑ X ₽"
    final price = place.actionPrice;
    final hasEnoughBalance = status.balance >= price;

    final bool canBid =
        status.isParticipant && !place.isMyShop && hasEnoughBalance;

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

          // Текущая ставка
          Expanded(
            flex: 18,
            child: Text(
              place.isEmpty ? '—' : '${place.bidPrice.toInt()} ₽',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Следующая ставка
          Expanded(
            flex: 18,
            child: Text(
              '${place.nextBid.toInt()} ₽',
              textAlign: TextAlign.center,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFe67e22),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Действие
          Expanded(
            flex: 18,
            child: _buildActionButton(context, place, canBid, price),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    dynamic place,
    bool canBid,
    double price,
  ) {
    // Моё место → пусто (без кнопки)
    if (place.isMyShop) {
      return Center(
        child: Text(
          '—',
          style: GoogleFonts.montserrat(fontSize: 12, color: Colors.grey),
        ),
      );
    }

    // Кнопка
    return Center(
      child: SizedBox(
        height: 28,
        child: ElevatedButton(
          onPressed: canBid && !isBidding ? () => onBid(place.place) : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: canBid
                ? const Color(0xFF2ecc71)
                : const Color(0xFFe0e0e0),
            foregroundColor: canBid ? Colors.white : Colors.grey,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            minimumSize: const Size(0, 28),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            elevation: 0,
          ),
          child: isBidding
              ? const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  place.isEmpty
                      ? 'Занять ${price.toInt()}₽'
                      : '↑ ${price.toInt()}₽',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
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
