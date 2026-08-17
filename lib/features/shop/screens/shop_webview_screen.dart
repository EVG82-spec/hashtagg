import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// WebView для магазинов (без навигации браузера)
// Ваш существующий ShopWebViewScreen можно использовать для HTML
class ShopWebViewScreen extends StatefulWidget {
  final String url;      // ← Для обычных URL
  final String? html;    // ← Добавляем для HTML-контента
  final String? title;

  const ShopWebViewScreen({
    super.key,
    required this.url,
    this.html,
    this.title,
  });

  @override
  State<ShopWebViewScreen> createState() => _ShopWebViewScreenState();
}

class _ShopWebViewScreenState extends State<ShopWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent('Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36')
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final url = request.url;
            if (url.contains('hashtagg.ru') || url.startsWith('/')) {
              return NavigationDecision.navigate;
            }
            return NavigationDecision.prevent;
          },
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
          onWebResourceError: (WebResourceError error) {
            print('🔴 [ShopWebView] Error: ${error.description}');
          },
        ),
      );

    // ✅ Загружаем HTML или URL
    if (widget.html != null && widget.html!.isNotEmpty) {
      _controller.loadHtmlString(widget.html!);
    } else {
      _controller.loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Stack(
          children: [
            WebViewWidget(controller: _controller),
            if (_isLoading)
              const Center(
                child: CircularProgressIndicator(
                  color: Color(0xff917dfa),
                ),
              ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}