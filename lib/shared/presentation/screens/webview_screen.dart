import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hashtagg/core/services/deep_link_service.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String? title;

  const WebViewScreen({super.key, required this.url, this.title});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  String _pageTitle = '';

  @override
  void initState() {
    super.initState();
    print('🔵 [WebView] Loading URL: ${widget.url}');
    _pageTitle = widget.title ?? '';

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            print('🔴 [WebView] Navigation: $url');

            // ===== 3DS СТРАНИЦЫ → внешний браузер =====
            if (url.contains('3ds') ||
                url.contains('acs') ||
                url.contains('verify') ||
                url.toLowerCase().contains('card-auth')) {
              print('✅ [WebView] 3DS detected, opening in browser');
              await launchUrl(
                Uri.parse(url),
                mode: LaunchMode.externalApplication,
              );
              return NavigationDecision.prevent;
            }

            // ===== DEEP LINK hashtagg:// =====
            if (url.startsWith('hashtagg://')) {
              print('✅ [WebView] Deep link: $url');
              DeepLinkService().handleDeepLink(url);
              if (mounted) Navigator.pop(context);
              return NavigationDecision.prevent;
            }

            // ===== HTTP/HTTPS → остаётся в WebView =====
            if (url.startsWith('http://') || url.startsWith('https://')) {
              return NavigationDecision.navigate;
            }

            // ===== НЕСТАНДАРТНЫЕ СХЕМЫ (tel:, mailto:, whatsapp:, tg:) → внешний браузер =====
            try {
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }
            } catch (e) {
              print('🔴 [WebView] Error: $e');
            }
            return NavigationDecision.prevent;
          },
          onPageFinished: (String url) async {
            print('🟢 [WebView] Page finished: $url');

            // Обновляем заголовок из страницы, если не задан
            if (widget.title == null || widget.title!.isEmpty) {
              final title = await _controller.getTitle();
              if (title != null && title.isNotEmpty && mounted) {
                setState(() => _pageTitle = title);
              }
            }

            // Deep link внутри страницы
            if (url.startsWith('hashtagg://')) {
              DeepLinkService().handleDeepLink(url);
              if (mounted) Navigator.pop(context);
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('🔴 [WebView] Resource error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  /// Кастомная обработка кнопки "Назад":
  /// Сначала пытаемся вернуться назад по истории WebView,
  /// если не можем — закрываем экран
  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false; // остаться в WebView
    }
    return true; // закрыть экран
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final shouldPop = await _handleBack();
        if (shouldPop && mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Theme.of(context).appBarTheme.backgroundColor,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          ),
          leadingWidth: 110,
          leading: TextButton.icon(
            onPressed: () async {
              final shouldPop = await _handleBack();
              if (shouldPop && mounted) {
                Navigator.pop(context);
              }
            },
            icon: Icon(Icons.arrow_back, size: 20, color: textColor),
            label: Text(
              'Назад',
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
          title: Text(
            _pageTitle,
            style: GoogleFonts.montserrat(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: true,
        ),
        body: WebViewWidget(controller: _controller),
      ),
    );
  }
}
