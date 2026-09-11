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

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff2a2a3e) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xffe9ecef),
        ),
      ),
      child: Column(
        children: [
          // Заголовок таблицы
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: const BoxDecoration(
              color: Color(0xFF1a1a2e),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                _headerCell('Место', flex: 1),
                _headerCell('Магазин', flex: 3),
                _headerCell('Ставка', flex: 2),
                _headerCell('', flex: 2),
              ],
            ),
          ),
          // Строки
          ...status.topPlaces.map((place) => _buildRow(context, place)),
          if (status.topPlaces.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Нет данных',
                style: GoogleFonts.montserrat(
                  color: textColor.withOpacity(0.5),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: GoogleFonts.montserrat(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildRow(BuildContext context, place) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canBid =
        status.isParticipant &&
        !place.isEmpty &&
        place.isMyShop &&
        status.balance >= place.nextBid;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: place.isMyShop
            ? (isDark
                  ? const Color(0xfffffbe6).withOpacity(0.1)
                  : const Color(0xfffffbe6))
            : Colors.transparent,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : const Color(0xfff1f3f5),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Text(place.placeEmoji, style: const TextStyle(fontSize: 16)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              place.shopName,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: place.isMyShop ? FontWeight.w700 : FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              place.isEmpty ? '—' : '${place.bidPrice.toInt()} ₽',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: place.isEmpty
                ? Text(
                    'Свободно',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  )
                : ElevatedButton(
                    onPressed: canBid && !isBidding
                        ? () => onBid(place.place)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canBid
                          ? const Color(0xFF2ecc71)
                          : const Color(0xFFe0e0e0),
                      foregroundColor: canBid ? Colors.white : Colors.grey,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: const Size(0, 32),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
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
                            '${place.nextBid.toInt()}₽',
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
          ),
        ],
      ),
    );
  }
}
