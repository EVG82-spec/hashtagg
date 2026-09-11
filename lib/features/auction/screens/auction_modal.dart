import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../bloc/auction_bloc.dart';
import '../bloc/auction_event.dart';
import '../bloc/auction_state.dart';
import '../widgets/auction_balance_block.dart';
import '../widgets/auction_participant_status.dart';
import '../widgets/auction_mode_switcher.dart';
import '../widgets/auction_manual_mode.dart';
import '../widgets/auction_auto_mode.dart';
import '../repository/auction_api_repository.dart';

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
  String _mode = 'manual';

  @override
  void initState() {
    super.initState();
    // Запускаем автообновление
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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      child: Container(
        width: double.infinity,
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? Colors.white12 : Colors.grey.shade200,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    const Text('⚡', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Битва за ТОП',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Контент (скроллится)
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
                                size: 64,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                state.message,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(fontSize: 14),
                              ),
                              const SizedBox(height: 20),
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
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Баланс
                            AuctionBalanceBlock(
                              balance: state.status.balance,
                              onTopUp: () => _showTopUpInfo(context),
                            ),

                            const SizedBox(height: 16),

                            // Статус участия
                            AuctionParticipantStatus(
                              isParticipant: state.status.isParticipant,
                              expireDate: state.status.expireDate,
                              onActivate: () => _onActivate(context),
                            ),

                            const SizedBox(height: 16),

                            // Переключатель режимов
                            AuctionModeSwitcher(
                              mode: _mode,
                              onModeChanged: (m) => setState(() => _mode = m),
                            ),

                            const SizedBox(height: 16),

                            // Ручной режим
                            if (_mode == 'manual')
                              AuctionManualMode(
                                status: state.status,
                                isBidding: state.isBidding,
                                onBid: (place) => _onBid(context, place),
                              ),

                            // Авто режим
                            if (_mode == 'auto')
                              AuctionAutoMode(
                                status: state.status,
                                onSave: (enabled, limit, interval) =>
                                    _onSaveAuto(
                                      context,
                                      enabled,
                                      limit,
                                      interval,
                                    ),
                              ),

                            const SizedBox(height: 16),

                            // Ошибка
                            if (state.errorMessage != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  state.errorMessage!,
                                  style: GoogleFonts.montserrat(
                                    color: Colors.red.shade800,
                                    fontSize: 13,
                                  ),
                                ),
                              ),

                            // 👇 ИСТОРИЯ ОПЕРАЦИЙ
                            _buildHistoryBlock(state),
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

  /// Блок истории операций
  /// Блок истории операций
  Widget _buildHistoryBlock(AuctionLoaded state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final history = state.status.balanceLog;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📊 История операций',
          style: GoogleFonts.montserrat(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff2a2a3e) : const Color(0xFFf8f9fa),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200,
            ),
          ),
          child: history.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'История пуста',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                )
              : Column(
                  children: history.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    final isLast = index == history.length - 1;
                    final isNegative = item.summa < 0;

                    // Форматируем дату
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
                        horizontal: 14,
                        vertical: 12,
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
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$date $time',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 11,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${isNegative ? '' : '+'}${item.summa.toStringAsFixed(2)} ₽',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
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
    );
  }

  void _onBid(BuildContext context, int place) {
    context.read<AuctionBloc>().add(
      PlaceBid(shopId: widget.shopId, targetPlace: place),
    );
  }

  void _onActivate(BuildContext context) {
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

  void _onSaveAuto(
    BuildContext context,
    bool enabled,
    double limit,
    int interval,
  ) {
    context.read<AuctionBloc>().add(
      SaveAutoSettings(
        shopId: widget.shopId,
        isEnabled: enabled,
        dailyLimit: limit,
        bidIntervalMinutes: interval,
      ),
    );
  }

  void _showTopUpInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Пополнение баланса'),
        content: const Text(
          'Для пополнения баланса перейдите в раздел "Кошелёк" в профиле.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }
}
