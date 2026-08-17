import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:hashtagg/core/network/api_config.dart';

class ArticleScreen extends StatefulWidget {
  final int articleId;
  final String? catAlias;
  final String? articleAlias;
  
  const ArticleScreen({
    super.key,
    required this.articleId,
    this.catAlias,
    this.articleAlias,
  });

  @override
  State<ArticleScreen> createState() => _ArticleScreenState();
}

class _ArticleScreenState extends State<ArticleScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    
    // Строим URL для статьи
    String articleUrl;
    if (widget.catAlias != null && widget.articleAlias != null) {
      // Полный путь с алиасами: blog/pomoshch/kak-bystro-4
      articleUrl = ApiConfig.buildWebUrl(
        'blog/${widget.catAlias}/${widget.articleAlias}-${widget.articleId}',
      );
    } else {
      // Fallback на простой путь с ID
      articleUrl = ApiConfig.buildWebUrl('blog/${widget.articleId}');
    }
    
    print('🔵 [ArticleScreen] Loading article URL: $articleUrl');
    
    // Инициализация WebView контроллера
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() => _isLoading = true);
          },
          onPageFinished: (String url) {
            setState(() => _isLoading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse(articleUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back, color: Colors.black, size: 20),
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(
                color: Color(0xff917dfa),
              ),
            ),
        ],
      ),
    );
  }
}
