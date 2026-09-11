import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuctionBalanceBlock extends StatelessWidget {
  final double balance;
  final VoidCallback onTopUp;

  const AuctionBalanceBlock({
    Key? key,
    required this.balance,
    required this.onTopUp,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff2a2a3e) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xffe9ecef),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '💰 Доступный баланс:',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${balance.toStringAsFixed(2)} ₽',
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2ecc71),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTopUp,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3498db),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(
              '➕ Пополнить',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
