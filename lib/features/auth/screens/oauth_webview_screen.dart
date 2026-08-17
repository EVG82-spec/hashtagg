import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hashtagg/core/services/deep_link_service.dart';

class OAuthWebViewScreen extends StatefulWidget {
  final String url;

  const OAuthWebViewScreen({super.key, required this.url});

  @override
  State<OAuthWebViewScreen> createState() => _OAuthWebViewScreenState();
}

class _OAuthWebViewScreenState extends State<OAuthWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    print('🟣 [3] OAuthWebViewScreen initState, URL: ${widget.url}');

    _controller = WebViewController()
    // Важно: нормальный User-Agent
      ..setUserAgent(
          "Mozilla/5.0 (Linux; Android 14; Pixel 8 Pro) AppleWebKit/537.36 "
              "(KHTML, like Gecko) Chrome/128.0.0.0 Mobile Safari/537.36")

      ..setJavaScriptMode(JavaScriptMode.unrestricted)

    // Рекомендуется для Android
      ..setBackgroundColor(Colors.transparent)

      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            print('🟡 [4] onPageStarted: $url');
          },
          onPageFinished: (url) {
            print('🟢 [5] onPageFinished: $url');
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
          onNavigationRequest: (NavigationRequest request) {
            print('🔴 [6] onNavigationRequest: ${request.url}');

            if (request.url.startsWith('hashtagg://')) {
              print('✅ [7] ПЕРЕХВАТЧЕН DEEP LINK: ${request.url}');
              DeepLinkService().handleDeepLink(request.url);
              if (mounted) Navigator.pop(context);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            print('❌ [8] WebView ERROR: ${error.description}');
            print('   Error Code: ${error.errorCode}');
            print('   URL: ${error.url}');
            print('   Is For Main Frame: ${error.isForMainFrame}');

            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Авторизация через социальные сети'),
        backgroundColor: const Color(0xff917dfa),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => _controller.reload(),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
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