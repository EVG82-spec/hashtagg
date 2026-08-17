import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/core/services/autostart_service.dart';

class AutostartDialog extends StatefulWidget {
  const AutostartDialog({super.key});

  @override
  State<AutostartDialog> createState() => _AutostartDialogState();
}

class _AutostartDialogState extends State<AutostartDialog> {
  String _instructions = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInstructions();
  }

  Future<void> _loadInstructions() async {
    final instructions = await AutostartService.getInstructions();
    setState(() {
      _instructions = instructions;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff1a1a1a) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey[600];

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Stack(
        children: [
          // Прокручиваемый контент
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
              maxWidth: MediaQuery.of(context).size.width - 32,
            ),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок (без кнопки закрытия)
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_active,
                          color: const Color(0xff917dfa),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        // Добавлен правый отступ, чтобы текст не наезжал на кнопку закрытия
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(right: 40),
                            child: Text(
                              'Настройка уведомлений',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Описание
                    Text(
                      'Для корректной работы уведомлений необходимо разрешить автозапуск приложения в настройках вашего устройства.',
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: subtitleColor,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Инструкция
                    if (_isLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Инструкция:',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _instructions,
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                color: subtitleColor,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 24),

                    // Кнопки (вертикально)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final success =
                              await AutostartService.openAutostartSettings();
                          if (success && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff917dfa),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Перейти в настройки',
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () async {
                          await AutostartService.setDontShowAgain();
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Больше не показывать',
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: subtitleColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Закреплённая кнопка закрытия (всегда видна, даже при прокрутке)
          Positioned(
            top: 28,   // выравнивание с заголовком
            right: 24,
            child: GestureDetector(
              onTap: () async {
                await AutostartService.markAsShown();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isDark
                      ? Color(0xffd3d3d3).withOpacity(0.675)
                      : Color(0xffd3d3d3).withOpacity(0.675),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Icons.close,
                  color: isDark ? Colors.white : Colors.black54,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Показать диалог настройки автозапуска (один раз)
Future<void> showAutostartDialogIfNeeded(BuildContext context) async {
  final shouldShow = await AutostartService.shouldShowPopup();

  if (shouldShow && context.mounted) {
    await AutostartService.markAsShown();
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => const AutostartDialog(),
    );
  }
}