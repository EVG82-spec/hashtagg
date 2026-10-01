import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/auction_place.dart';

class AuctionBidModal extends StatefulWidget {
  final AuctionPlace place;
  final double userBalance;
  final Function(double bidPrice) onConfirm;

  const AuctionBidModal({
    Key? key,
    required this.place,
    required this.userBalance,
    required this.onConfirm,
  }) : super(key: key);

  static Future<void> show({
    required BuildContext context,
    required AuctionPlace place,
    required double userBalance,
    required Function(double bidPrice) onConfirm,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AuctionBidModal(
        place: place,
        userBalance: userBalance,
        onConfirm: onConfirm,
      ),
    );
  }

  @override
  State<AuctionBidModal> createState() => _AuctionBidModalState();
}

class _AuctionBidModalState extends State<AuctionBidModal> {
  late double _bidPrice;
  late final TextEditingController _priceController;

  static const double _maxBid = 100000;

  @override
  void initState() {
    super.initState();
    _bidPrice = widget.place.minimumBid;
    _priceController = TextEditingController(
      text: _bidPrice.toInt().toString(),
    );
  }

  @override
  void dispose() {
    _priceController.dispose();
    super.dispose();
  }

  void _onSliderChanged(double value) {
    setState(() {
      _bidPrice = value;
      _priceController.text = value.toInt().toString();
    });
  }

  void _onTextChanged(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      setState(() {
        _bidPrice = parsed.clamp(widget.place.minimumBid, _maxBid);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff1a1a2e) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    final hasEnoughBalance = widget.userBalance >= _bidPrice;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Индикатор
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Заголовок
          Text(
            'Выкуп места ${widget.place.placeEmoji}',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 16),

          // Текущий владелец
          if (!widget.place.isEmpty) ...[
            Row(
              children: [
                Text(
                  'Текущий владелец:',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  widget.place.shopName,
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Text(
                  'Текущая цена:',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: textColor.withOpacity(0.7),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${widget.place.bidPrice.toInt()} ₽',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF2ecc71),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          // Минимум
          Text(
            'Минимальная ставка: ${widget.place.minimumBid.toInt()} ₽',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: textColor.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),

          // Поле ввода
          TextField(
            controller: _priceController,
            keyboardType: TextInputType.number,
            onChanged: _onTextChanged,
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: isDark
                  ? const Color(0xff2a2a3e)
                  : const Color(0xFFf8f9fa),
              suffixText: '₽',
              suffixStyle: GoogleFonts.montserrat(
                fontSize: 16,
                color: textColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Ползунок
          Slider(
            value: _bidPrice.clamp(widget.place.minimumBid, _maxBid),
            min: widget.place.minimumBid,
            max: _maxBid,
            divisions: ((_maxBid - widget.place.minimumBid) ~/ 100).clamp(
              1,
              1000,
            ),
            activeColor: const Color(0xFF8956FF),
            label: '${_bidPrice.toInt()} ₽',
            onChanged: _onSliderChanged,
          ),

          // Подписи min/max
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.place.minimumBid.toInt()} ₽',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: textColor.withOpacity(0.6),
                ),
              ),
              Text(
                'до 100 000 ₽',
                style: GoogleFonts.montserrat(
                  fontSize: 11,
                  color: textColor.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Инфо о шаге
          Text(
            'Минимальный шаг: 100 ₽',
            style: GoogleFonts.montserrat(
              fontSize: 11,
              color: textColor.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 16),

          // Баланс
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: hasEnoughBalance
                  ? const Color(0xFFe8f5e9)
                  : const Color(0xFFffebee),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  hasEnoughBalance ? Icons.check_circle : Icons.error,
                  color: hasEnoughBalance
                      ? const Color(0xFF2e7d32)
                      : const Color(0xFFc62828),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  hasEnoughBalance
                      ? 'Ваш баланс: ${widget.userBalance.toInt()} ₽'
                      : 'Недостаточно средств. Нужно: ${_bidPrice.toInt()} ₽',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: hasEnoughBalance
                        ? const Color(0xFF2e7d32)
                        : const Color(0xFFc62828),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Кнопки
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Отмена',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: hasEnoughBalance
                      ? () {
                          Navigator.pop(context);
                          widget.onConfirm(_bidPrice);
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ecc71),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Купить за ${_bidPrice.toInt()} ₽',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
