import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/auction_status.dart';

class AuctionAutoMode extends StatefulWidget {
  final AuctionStatus status;
  final Function(bool enabled, double limit, int interval) onSave;

  const AuctionAutoMode({Key? key, required this.status, required this.onSave})
    : super(key: key);

  @override
  State<AuctionAutoMode> createState() => _AuctionAutoModeState();
}

class _AuctionAutoModeState extends State<AuctionAutoMode> {
  bool _isEnabled = false;
  double _dailyLimit = 500;
  int _intervalMinutes = 60;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadFromSettings();
  }

  @override
  void didUpdateWidget(AuctionAutoMode oldWidget) {
    super.didUpdateWidget(oldWidget);

    // ✅ СИНХРОНИЗАЦИЯ С СЕРВЕРОМ
    final newSettings = widget.status.autoSettings;

    if (newSettings != null) {
      final newEnabled = newSettings.isEnabled;

      if (_isEnabled != newEnabled) {
        print('🔄 [AuctionAutoMode] Sync isEnabled: $_isEnabled → $newEnabled');
        setState(() {
          _isEnabled = newEnabled;
        });
      }

      // Если автопилот выключен — синхронизируем ползунки
      if (!newEnabled) {
        if (_dailyLimit != newSettings.dailyLimit) {
          setState(() => _dailyLimit = newSettings.dailyLimit);
        }
        if (_intervalMinutes != newSettings.bidIntervalMinutes) {
          setState(() => _intervalMinutes = newSettings.bidIntervalMinutes);
        }
      }
    }
  }

  void _loadFromSettings() {
    final settings = widget.status.autoSettings;
    if (settings != null) {
      _isEnabled = settings.isEnabled;
      _dailyLimit = settings.dailyLimit;
      _intervalMinutes = settings.bidIntervalMinutes;
    }
    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!_initialized) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Пояснение
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFfff3cd),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '💡 Как это работает?',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: const Color(0xFF856404),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Робот будет проверять аукцион и перебивать ставки согласно расписанию, пока не исчерпает дневной лимит.',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: const Color(0xFF856404),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Частота ставок
        Text(
          '⏱ Как часто поднимать ставку?',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        ..._buildIntervalOptions(),

        const SizedBox(height: 16),

        // Дневной лимит
        Text(
          '💰 Суточный лимит расходов:',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _dailyLimit,
                min: 100,
                max: 5000,
                divisions: 98,
                activeColor: const Color(0xFF8956FF),
                label: '${_dailyLimit.toInt()} ₽',
                onChanged: (v) => setState(() => _dailyLimit = v),
              ),
            ),
            SizedBox(
              width: 80,
              child: Text(
                '${_dailyLimit.toInt()} ₽',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: const Color(0xFF8956FF),
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Статус
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: _isEnabled ? Colors.green : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              _isEnabled ? 'Автопилот активен' : 'Автопилот выключен',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Кнопка
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final newEnabled = !_isEnabled;
              setState(() => _isEnabled = newEnabled);
              widget.onSave(newEnabled, _dailyLimit, _intervalMinutes);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _isEnabled
                  ? const Color(0xFFe74c3c)
                  : const Color(0xFF2ecc71),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Text(
              _isEnabled ? '⏹ Остановить автопилот' : '▶️ Сохранить и включить',
              style: GoogleFonts.montserrat(
                fontWeight: FontWeight.w700,
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Потрачено сегодня
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff2a2a3e) : const Color(0xFFf8f9fa),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '💸 Потрачено сегодня:',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              Text(
                '${widget.status.totalSpentToday.toStringAsFixed(2)} ₽',
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: const Color(0xFFe74c3c),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildIntervalOptions() {
    final intervals = [
      {'value': 4320, 'label': 'Раз в 3 дня (экономия)'},
      {'value': 1440, 'label': 'Раз в день (стандарт)'},
      {'value': 60, 'label': 'Каждый час (активная защита)'},
      {'value': 10, 'label': '⚡ Тест: раз в 10 минут'},
    ];

    return intervals.map((item) {
      final value = item['value'] as int;
      final label = item['label'] as String;
      final isSelected = _intervalMinutes == value;

      return GestureDetector(
        onTap: () => setState(() => _intervalMinutes = value),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFf0f0ff) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1a1a2e)
                  : const Color(0xFFe0e0e0),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1a1a2e)
                        : const Color(0xFFadb5bd),
                    width: 2,
                  ),
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1a1a2e),
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: const Color(0xFF333333),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }
}
