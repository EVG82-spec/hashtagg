import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/features/auth/screens/oauth_webview_screen.dart';

class OAuthService {
  // ===== VK =====
  void loginWithVK(BuildContext context) {
    final url = '${ApiConfig.oauthUrl}/systems/ajax/oauth/vk.php?source=mobile';
    print('🔵 [1] loginWithVK() вызван, URL: $url');
    _openWebView(context, url);
  }

  // ===== ЯНДЕКС =====
  void loginWithYandex(BuildContext context) {
    final url = '${ApiConfig.oauthUrl}/systems/ajax/oauth.php?network=yandex&app=1';
    print('🔵 [1] loginWithYandex() вызван, URL: $url');
    _openWebView(context, url);
  }

  // ===== ОБЩИЙ МЕТОД ДЛЯ ОТКРЫТИЯ WEBVIEW =====
  void _openWebView(BuildContext context, String url) {
    print('🟢 [2] _openWebView() открывает WebView: $url');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OAuthWebViewScreen(url: url),
      ),
    );
  }
}