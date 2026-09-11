import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AuctionModeSwitcher extends StatelessWidget {
  final String mode;
  final ValueChanged<String> onModeChanged;

  const AuctionModeSwitcher({
    Key? key,
    required this.mode,
    required this.onModeChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildButton(
            context,
            label: 'Ручной',
            icon: '🎯',
            isActive: mode == 'manual',
            onTap: () => onModeChanged('manual'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildButton(
            context,
            label: 'Автопилот',
            icon: '🤖',
            isActive: mode == 'auto',
            onTap: () => onModeChanged('auto'),
          ),
        ),
      ],
    );
  }

  Widget _buildButton(
    BuildContext context, {
    required String label,
    required String icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1a1a2e) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isActive ? const Color(0xFF1a1a2e) : const Color(0xFFdee2e6),
            width: 2,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                color: isActive ? Colors.white : const Color(0xFF495057),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
