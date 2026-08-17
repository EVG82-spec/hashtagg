import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/core/services/oauth_service.dart';

// Стиль для белого status bar с темными иконками
const SystemUiOverlayStyle whiteStatusBar = SystemUiOverlayStyle(
  statusBarColor: Colors.white,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
);

OverlayEntry? _activeNotificationEntry;

void showSwipeDownNotification(
    BuildContext context, {
      String message = 'Уведомление',
      Duration duration = const Duration(seconds: 2),
    }) {
  if (_activeNotificationEntry != null) return;

  late OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) => _NotificationOverlay(
      message: message,
      duration: duration,
      onDismiss: () {
        entry.remove();
        if (_activeNotificationEntry == entry) {
          _activeNotificationEntry = null;
        }
      },
    ),
  );

  Overlay.of(context).insert(entry);
  _activeNotificationEntry = entry;
}

class _NotificationOverlay extends StatefulWidget {
  final String message;
  final Duration duration;
  final VoidCallback onDismiss;

  const _NotificationOverlay({
    required this.message,
    required this.duration,
    required this.onDismiss,
  });

  @override
  __NotificationOverlayState createState() => __NotificationOverlayState();
}

class __NotificationOverlayState extends State<_NotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offset;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _offset = Tween<Offset>(
      begin: Offset(0, -1),
      end: Offset(0, 0),
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.bounceOut));
    _controller.forward();

    _hideTimer = Timer(widget.duration, _hideNotification);
  }

  void _hideNotification() {
    if (mounted) {
      _controller.reverse().then((_) {
        widget.onDismiss();
      });
    }
  }

  void _handleSwipeUp(DragEndDetails details) {
    if (details.primaryVelocity! < 0) {
      _hideTimer?.cancel();
      _hideTimer = null;
      _hideNotification();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _offset,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onVerticalDragEnd: _handleSwipeUp,
            child: Container(
              margin: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 20,
                left: 20,
                right: 20,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Text(
                  widget.message,
                  style: GoogleFonts.montserrat(color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void showAuthModal(BuildContext context) {
  final oauthService = OAuthService();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext context) {
      return SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16.0,
            right: 16.0,
            top: 16.0,
            bottom: 16.0 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "Ручка" для свайпа
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Войдите в аккаунт',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Выберите способ авторизации',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),

              // ===== КНОПКА "ПОЧТА" =====
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/login');
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Color(0xff917dfa)),
                  padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                child: Text(
                  "Войти через почту",
                  style: GoogleFonts.montserrat(color: Colors.white),
                ),
              ),
              const SizedBox(height: 8),

              // ===== КНОПКА "РЕГИСТРАЦИЯ" =====
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/registration');
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(Colors.white),
                  padding: WidgetStatePropertyAll(EdgeInsets.all(12)),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Color(0xff917dfa), width: 1),
                    ),
                  ),
                ),
                child: Text(
                  'Зарегистрироваться',
                  style: GoogleFonts.montserrat(color: Color(0xff917dfa)),
                ),
              ),
              const SizedBox(height: 16),

              // ===== РАЗДЕЛИТЕЛЬ =====
              Row(
                children: [
                  Expanded(child: Divider(color: Colors.grey[300])),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'или через соцсети',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  Expanded(child: Divider(color: Colors.grey[300])),
                ],
              ),
              const SizedBox(height: 16),

              // ===== КНОПКИ VK И ЯНДЕКС =====
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // ---- ЯНДЕКС ----
                  _buildSocialButton(
                    context: context,
                    onTap: () {
                      Navigator.pop(context);
                      oauthService.loginWithYandex(context);
                    },
                    imageUrl: 'https://hashtagg.ru/public/media/others/media_social_yandex_61627.png',
                    label: 'Яндекс',
                  ),
                  const SizedBox(width: 20),

                  // ---- VK ----
                  _buildSocialButton(
                    context: context,
                    onTap: () {
                      Navigator.pop(context);
                      oauthService.loginWithVK(context);
                    },
                    imageUrl: 'https://hashtagg.ru/public/media/others/media_social_vk_vkontakte_icon_124252.png',
                    label: 'VK',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

// ===== ВСПОМОГАТЕЛЬНЫЙ ВИДЖЕТ ДЛЯ КНОПКИ СОЦСЕТИ =====
Widget _buildSocialButton({
  required BuildContext context,
  required VoidCallback onTap,
  required String imageUrl,
  required String label,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.network(
            imageUrl,
            width: 32,
            height: 32,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return Icon(Icons.error_outline, color: Colors.grey);
            },
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    ),
  );
}
