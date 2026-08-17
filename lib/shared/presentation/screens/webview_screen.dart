import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:hashtagg/shared/presentation/bloc/loading_notifier.dart';
import 'package:hashtagg/core/services/deep_link_service.dart';

class WebViewScreen extends StatefulWidget {
  final String url;
  final String? title;

  const WebViewScreen({
    super.key,
    required this.url,
    this.title,
  });

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String _pageTitle = '';

  @override
  void initState() {
    super.initState();
    print('🔵 [WebView] Screen initialized');
    print('🔵 [WebView] Loading URL: ${widget.url}');
    _pageTitle = widget.title ?? '';

    print('🔵 [WebView] Creating controller...');
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
          'Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36'
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) async {
            final url = request.url;
            print('🔴 [WebView] Navigation: $url');

            // ===== ПЕРЕХВАТ 3DS СТРАНИЦ =====
            if (url.contains('3ds') || url.contains('acs') || url.contains('verify')) {
              print('✅ [WebView] 3DS page detected, opening in browser');
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }

            // ===== DEEP LINK =====
            if (url.startsWith('hashtagg://')) {
              print('✅ [WebView] Deep link intercepted: $url');
              DeepLinkService().handleDeepLink(url);
              Navigator.pop(context);
              return NavigationDecision.prevent;
            }

            // ===== ОБЫЧНЫЕ HTTP/HTTPS =====
            if (url.startsWith('http://') || url.startsWith('https://')) {
              return NavigationDecision.navigate;
            }

            // ===== НЕСТАНДАРТНЫЕ =====
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
          onPageStarted: (String url) {
            print('🟢 [WebView] Page started: $url');
            setState(() => _isLoading = true);

            // ===== ПЕРЕХВАТ 3DS СТРАНИЦ =====
            if (url.toLowerCase().contains('3ds') ||
                url.toLowerCase().contains('acs') ||
                url.toLowerCase().contains('card-auth')) {
              print('✅ [WebView] 3DS page detected! Opening in browser...');
              // Открываем во внешнем браузере
              launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              // Закрываем WebView
              Navigator.pop(context);
            }
          },
          onPageFinished: (String url) {
            print('🟢 [WebView] Page finished: $url');
            setState(() => _isLoading = false);

            // ===== ПРОВЕРКА НА DEEP LINK =====
            if (url.startsWith('hashtagg://')) {
              print('✅ [WebView] Deep link in page finished!');
              DeepLinkService().handleDeepLink(url);
              Navigator.pop(context);
            }
          },
          onWebResourceError: (WebResourceError error) {
            print('🔴 [WebView] Resource error: ${error.description}');
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));

    print('🔵 [WebView] Controller created, loadRequest called');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Theme.of(context).appBarTheme.backgroundColor,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _pageTitle,
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: isDark ? Colors.white : Colors.black),
            onPressed: () => _controller.reload(),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(
                color: Color(0xff917dfa),
              ),
            ),
        ],
      ),
    );
  }
}
