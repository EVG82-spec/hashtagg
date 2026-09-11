import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuctionParticipantStatus extends StatelessWidget {
  final bool isParticipant;
  final String? expireDate;
  final VoidCallback onActivate;

  const AuctionParticipantStatus({
    Key? key,
    required this.isParticipant,
    this.expireDate,
    required this.onActivate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (isParticipant) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFe8f5e9),
          borderRadius: BorderRadius.circular(12),
          border: const Border(
            left: BorderSide(color: Color(0xFF4caf50), width: 4),
          ),
        ),
        child: Row(
          children: [
            const Text('✅', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Участие активно',
                    style: GoogleFonts.montserrat(
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2e7d32),
                    ),
                  ),
                  if (expireDate != null)
                    Text(
                      'Действует до: $expireDate',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFfff3cd),
        borderRadius: BorderRadius.circular(12),
        border: const Border(
          left: BorderSide(color: Color(0xFFffc107), width: 4),
        ),
      ),
      child: Row(
        children: [
          const Text('🔒', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Участие не активировано',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF856404),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: onActivate,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFf7971e),
              foregroundColor: const Color(0xFF1a1a2e),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            ),
            child: Text(
              'Активировать 500₽',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
