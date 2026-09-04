// lib/shared/presentation/widgets/app_footer.dart
import 'package:flutter/material.dart';
import 'package:hashtagg/shared/presentation/screens/webview_screen.dart';

class AppFooter extends StatelessWidget {
  const AppFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          // Копирайт
          Text(
            '© 2026 Хештег',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          // Ссылки
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              _FooterLink(
                text: 'Правила сервиса',
                onTap: () => _openLink(context, '/rules'),
              ),
              _FooterLink(
                text: 'Пользовательское соглашение',
                onTap: () => _openLink(context, '/polzovatelskoe-soglashenie'),
              ),
              _FooterLink(
                text: 'Служба поддержки',
                onTap: () => _openLink(context, '/feedback'),
              ),
              _FooterLink(
                text: 'Политика обработки данных',
                onTap: () => _openLink(
                  context,
                  '/politika-v-otnoshenii-obrabotki-personalnyh-dannyh',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openLink(BuildContext context, String path) {
    final url = 'https://hashtagg.ru$path';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WebViewScreen(url: url, title: _getTitle(path)),
      ),
    );
  }

  String _getTitle(String path) {
    switch (path) {
      case '/rules':
        return 'Правила сервиса';
      case '/polzovatelskoe-soglashenie':
        return 'Пользовательское соглашение';
      case '/feedback':
        return 'Служба поддержки';
      case '/politika-v-otnoshenii-obrabotki-personalnyh-dannyh':
        return 'Политика обработки данных';
      default:
        return 'Информация';
    }
  }
}

class _FooterLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;

  const _FooterLink({required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
