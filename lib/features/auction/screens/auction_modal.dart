import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/features/auction/models/auction_place.dart';
import '../bloc/auction_bloc.dart';
import '../bloc/auction_event.dart';
import '../bloc/auction_state.dart';
import '../widgets/auction_manual_mode.dart';
import '../repository/auction_api_repository.dart';
import 'package:go_router/go_router.dart';
import '../widgets/auction_bid_modal.dart';
import '../models/auction_place.dart';

class AuctionModal extends StatefulWidget {
  final int shopId;

  const AuctionModal({Key? key, required this.shopId}) : super(key: key);

  static Future<void> show(BuildContext context, int shopId) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => BlocProvider(
        create: (ctx) =>
            AuctionBloc(repository: ctx.read<AuctionApiRepository>())
              ..add(LoadAuctionStatus(shopId: shopId, forceRefresh: true)),
        child: AuctionModal(shopId: shopId),
      ),
    );
  }

  @override
  State<AuctionModal> createState() => _AuctionModalState();
}

class _AuctionModalState extends State<AuctionModal> {
  bool _showHistory = false;
  bool _agreementChecked = false;

  @override
  void initState() {
    super.initState();
    context.read<AuctionBloc>().add(StartAutoUpdate(shopId: widget.shopId));
  }

  @override
  void dispose() {
    context.read<AuctionBloc>().add(const StopAutoUpdate());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff1a1a2e) : Colors.white;
    final headerColor = const Color(0xff1a1a2e);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 40),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Заголовок ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                color: headerColor,
                child: Row(
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Битва за ТОП',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Контент ──
              Flexible(
                child: BlocBuilder<AuctionBloc, AuctionState>(
                  builder: (context, state) {
                    if (state is AuctionLoading || state is AuctionInitial) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(
                            color: Color(0xFF8956FF),
                          ),
                        ),
                      );
                    }

                    if (state is AuctionError) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.error_outline,
                                size: 56,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                state.message,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () {
                                  context.read<AuctionBloc>().add(
                                    LoadAuctionStatus(
                                      shopId: widget.shopId,
                                      forceRefresh: true,
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8956FF),
                                ),
                                child: const Text('Повторить'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (state is AuctionLoaded) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Баланс + Пополнить (одна строка) ──
                            _buildBalanceRow(context, state.status.balance),

                            const SizedBox(height: 10),

                            // ── Статус участия (одна строка) ──
                            _buildStatusRow(context, state.status),

                            const SizedBox(height: 12),

                            // ── Жёлтый блок для очереди ──
                            if (state.status.isOutsideTop &&
                                state.status.myPlace != null &&
                                state.status.myPlace! > 5) ...[
                              _buildQueueBanner(context, state.status.myPlace!),
                              const SizedBox(height: 10),
                            ],

                            // ── Таблица ──
                            AuctionManualMode(
                              status: state.status,
                              isBidding: state.isBidding,
                              onBid: (place) => _onBid(context, place),
                            ),

                            const SizedBox(height: 10),

                            // ── Ошибка ──
                            if (state.errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  state.errorMessage!,
                                  style: GoogleFonts.montserrat(
                                    color: Colors.red.shade800,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                            // ── История (свёрнутая) ──
                            _buildHistoryToggle(context, state),
                          ],
                        ),
                      );
                    }

                    return const SizedBox.shrink();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // Баланс (компактно)
  // ─────────────────────────────────────────────────
  Widget _buildBalanceRow(BuildContext context, double balance) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff2a2a3e) : const Color(0xFFf8f9fa),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          const Text('💰', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${balance.toStringAsFixed(2)} ₽',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2ecc71),
              ),
            ),
          ),
          // 👇 Компактная кнопка [+] без текста
          GestureDetector(
            onTap: () => _showTopUpSheet(context),
            child: Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF3498db),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // Статус участия (компактно)
  // ─────────────────────────────────────────────────
  // ─────────────────────────────────────────────────
  // Статус участия (компактно)
  // ─────────────────────────────────────────────────
  Widget _buildStatusRow(BuildContext context, dynamic status) {
    if (status.isParticipant) {
      // Форматируем дату
      String expireText = '—';
      if (status.expireDate != null) {
        final parts = status.expireDate.toString().split(' ');
        if (parts.isNotEmpty) {
          final dateParts = parts[0].split('-');
          if (dateParts.length == 3) {
            expireText = '${dateParts[2]}.${dateParts[1]}.${dateParts[0]}';
          }
        }
      }

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFe8f5e9),
          borderRadius: BorderRadius.circular(8),
          border: const Border(
            left: BorderSide(color: Color(0xFF4caf50), width: 3),
          ),
        ),
        child: Row(
          children: [
            const Text('✅', style: TextStyle(fontSize: 14)),
            const SizedBox(width: 6),
            Text(
              'Участие активно',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF2e7d32),
              ),
            ),
            const Spacer(),
            Text(
              'до $expireText',
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: Colors.grey.shade700,
              ),
            ),
          ],
        ),
      );
    }

    // ── Не активировано: чекбокс + кнопка ──
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFfff3cd),
        borderRadius: BorderRadius.circular(8),
        border: const Border(
          left: BorderSide(color: Color(0xFFffc107), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Заголовок ──
          Row(
            children: [
              const Text('🔒', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                'Участие не активировано',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF856404),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Чекбокс + ссылка ──
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: _agreementChecked,
                  onChanged: (v) {
                    setState(() {
                      _agreementChecked = v ?? false;
                    });
                  },
                  activeColor: const Color(0xFF2ecc71),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'Я согласен с ',
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        color: const Color(0xFF856404),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _showAgreementModal(context),
                      child: Text(
                        'условиями аукциона',
                        style: GoogleFonts.montserrat(
                          fontSize: 11,
                          color: const Color(0xFF3498db),
                          decoration: TextDecoration.underline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Кнопка "Активировать" ──
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _agreementChecked ? () => _onActivate(context) : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFf7971e),
                disabledBackgroundColor: const Color(0xFFe0e0e0),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
              child: Text(
                'Активировать за 500 ₽',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _agreementChecked
                      ? const Color(0xFF1a1a2e)
                      : Colors.grey.shade500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  } // ─────────────────────────────────────────────────

  // Жёлтый блок очереди
  // ─────────────────────────────────────────────────
  Widget _buildQueueBanner(BuildContext context, int position) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFfff3cd),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFffc107)),
      ),
      child: Row(
        children: [
          const Text('⏳', style: TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Все места ТОП-5 заняты. Ваша позиция: $position',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF856404),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────
  // История (свёрнутая)
  // ─────────────────────────────────────────────────
  Widget _buildHistoryToggle(BuildContext context, AuctionLoaded state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Потрачено сегодня
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff2a2a3e) : const Color(0xFFf8f9fa),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Text('💸', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              Text(
                'Потрачено сегодня:',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: textColor.withOpacity(0.7),
                ),
              ),
              const Spacer(),
              Text(
                '${state.status.totalSpentToday.toStringAsFixed(2)} ₽',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFe74c3c),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // Кнопка "История"
        GestureDetector(
          onTap: () => setState(() => _showHistory = !_showHistory),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff2a2a3e) : const Color(0xFFf8f9fa),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Text('📊', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 6),
                Text(
                  'История операций',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                Icon(
                  _showHistory
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: textColor,
                  size: 20,
                ),
              ],
            ),
          ),
        ),

        // Развёрнутая история
        if (_showHistory) ...[
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xff2a2a3e) : const Color(0xFFf8f9fa),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? Colors.white12 : Colors.grey.shade200,
              ),
            ),
            child: state.status.balanceLog.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Text(
                        'История пуста',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: state.status.balanceLog.asMap().entries.map((
                      entry,
                    ) {
                      final index = entry.key;
                      final item = entry.value;
                      final isLast =
                          index == state.status.balanceLog.length - 1;
                      final isNegative = item.summa < 0;

                      String date = item.datetime;
                      String time = '';
                      if (item.datetime.contains(' ')) {
                        final parts = item.datetime.split(' ');
                        date = parts[0];
                        if (parts.length > 1) {
                          time = parts[1].length >= 5
                              ? parts[1].substring(0, 5)
                              : parts[1];
                        }
                      }

                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: isLast
                              ? null
                              : Border(
                                  bottom: BorderSide(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.grey.shade100,
                                  ),
                                ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.name,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    '$date $time',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${isNegative ? '' : '+'}${item.summa.toStringAsFixed(0)} ₽',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isNegative
                                    ? const Color(0xFFe74c3c)
                                    : const Color(0xFF2ecc71),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ],
    );
  }

  // ─────────────────────────────────────────────────
  // Действия
  // ─────────────────────────────────────────────────
  void _onBid(BuildContext context, AuctionPlace place) {
    // Если пустое — сразу "Занять за стартовую"
    if (place.isEmpty) {
      context.read<AuctionBloc>().add(
        PlaceBid(
          shopId: widget.shopId,
          targetPlace: place.place,
          bidPrice: place.startPrice,
        ),
      );
      return;
    }

    // Если чужое — открываем мини-модалку
    if (!place.isMyShop) {
      _showBidModal(context, place);
    }
  }

  void _showBidModal(BuildContext context, AuctionPlace place) {
    final state = context.read<AuctionBloc>().state;
    if (state is! AuctionLoaded) return;

    AuctionBidModal.show(
      context: context,
      place: place,
      userBalance: state.status.balance,
      onConfirm: (bidPrice) {
        context.read<AuctionBloc>().add(
          PlaceBid(
            shopId: widget.shopId,
            targetPlace: place.place,
            bidPrice: bidPrice,
          ),
        );
      },
    );
  }

  void _onActivate(BuildContext context) {
    // Проверка чекбокса
    if (!_agreementChecked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Необходимо согласиться с условиями аукциона'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    // Подтверждение
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Активация участия'),
        content: const Text('Активировать участие в аукционе за 500 ₽?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<AuctionBloc>().add(
                ActivateParticipation(shopId: widget.shopId),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8956FF),
            ),
            child: const Text('Активировать'),
          ),
        ],
      ),
    );
  }

  /// BottomSheet с выбором суммы пополнения
  void _showTopUpSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff1a1a2e) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Row(
              children: [
                const Text('💳', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Пополнение баланса',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(sheetContext),
                  child: Icon(Icons.close, color: textColor, size: 22),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Плитки с суммами ──
            Row(
              children: [
                _buildAmountTile(sheetContext, 500),
                const SizedBox(width: 8),
                _buildAmountTile(sheetContext, 1000, isPopular: true),
                const SizedBox(width: 8),
                _buildAmountTile(sheetContext, 1500),
              ],
            ),

            const SizedBox(height: 16),

            // ── Переход в кошелёк ──
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  Navigator.pop(context); // Закрыть модалку аукциона

                  // 👇 Переход в кошелёк
                  context.push('/wallet');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3498db),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Перейти в кошелёк',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Полное пополнение доступно в разделе "Кошелёк"',
              style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Плитка с суммой
  Widget _buildAmountTile(
    BuildContext context,
    double amount, {
    bool isPopular = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          Navigator.pop(context);
          // 👇 Открыть кошелёк с предзаполненной суммой
          // Пока просто открываем кошелёк
          context.push('/wallet');
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff2a2a3e) : const Color(0xFFf8f9fa),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPopular ? const Color(0xFF2ecc71) : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            children: [
              Text(
                '${amount.toInt()} ₽',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              if (isPopular) ...[
                const SizedBox(height: 4),
                Text(
                  'Популярное',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2ecc71),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showAgreementModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff1a1a2e) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
        child: Container(
          constraints: BoxConstraints(
            maxWidth: 600,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Заголовок ──
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF1a1a2e),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Условия участия в аукционе',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(dialogContext),
                      child: const Icon(
                        Icons.close,
                        color: Colors.white70,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),

              // ── Тело ──
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _agreementSection(
                        '1. Общие положения',
                        'Участие в аукционе даёт право выкупить любое место в ТОП-5 '
                            'или встать в очередь. Активация участия не гарантирует место в ТОП-5.',
                        textColor,
                      ),
                      _agreementSection(
                        '2. Стоимость участия',
                        'Стоимость активации — 500 ₽. Срок действия участия — 30 дней '
                            'с момента активации. По истечении срока участие нужно активировать заново.',
                        textColor,
                      ),
                      _agreementSection(
                        '3. Правила ставок',
                        'Шаг аукциона — 100 ₽. Минимальная ставка = текущая цена места + 100 ₽. '
                            'Максимальная ставка — 100 000 ₽. Свободное место = стартовая цена слота.',
                        textColor,
                      ),
                      _agreementSection(
                        '4. Каскадное смещение',
                        'При выкупе места все магазины ниже сдвигаются на +1 позицию. '
                            'Магазин с 5-го места вылетает в очередь. Цены упавших магазинов не меняются.',
                        textColor,
                      ),
                      _agreementSection(
                        '5. Возврат средств',
                        'Средства, потраченные на активацию и ставки, не возвращаются. '
                            'Даже если магазин вылетел из ТОП-5, деньги не возвращаются.',
                        textColor,
                      ),
                    ],
                  ),
                ),
              ),

              // ── Кнопка "Понятно" ──
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1a1a2e),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Понятно',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _agreementSection(String title, String text, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            text,
            style: GoogleFonts.montserrat(
              fontSize: 13,
              height: 1.5,
              color: textColor.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}
