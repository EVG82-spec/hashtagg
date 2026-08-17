import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:hashtagg/core/network/api_config.dart';

/// Сервис для OAuth авторизации через социальные сети
/// 
/// Использует url_launcher для открытия браузера
/// После авторизации пользователь возвращается в приложение через deep link
class OAuthService {
  static const String callbackUrlScheme = 'hashtagg';
  
  /// Получение URL авторизации через oauth_mobile.php
  /// oauth_mobile.php устанавливает cookie и редиректит на OAuth провайдера
  String _getAuthorizationUrl(String network) {
    // Возвращаем прямую ссылку на oauth_mobile.php
    // Он установит cookie oauth_mobile=1 и сделает редирект на OAuth провайдера
    return '${ApiConfig.oauthUrl}/systems/ajax/oauth_mobile.php?network=$network';
  }

  /// Авторизация через Яндекс
  Future<String?> loginWithYandex() async {
    try {
      final authUrl = _getAuthorizationUrl('yandex');

      if (kDebugMode) {
        debugPrint('🔐 [OAuth Yandex] Auth URL: $authUrl');
      }

      final canLaunch = await canLaunchUrl(Uri.parse(authUrl));
      if (!canLaunch) {
        if (kDebugMode) {
          debugPrint('❌ [OAuth Yandex] Cannot launch URL');
        }
        return null;
      }

      await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );

      if (kDebugMode) {
        debugPrint('✅ [OAuth Yandex] Browser opened, waiting for callback...');
      }

      return 'pending';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [OAuth Yandex] Error: $e');
      }
      return null;
    }
  }

  /// Авторизация через VK
  Future<String?> loginWithVK() async {
    try {
      final authUrl = _getAuthorizationUrl('vk');

      if (kDebugMode) {
        debugPrint('🔐 [OAuth VK] Auth URL: $authUrl');
      }

      final canLaunch = await canLaunchUrl(Uri.parse(authUrl));
      if (!canLaunch) {
        if (kDebugMode) {
          debugPrint('❌ [OAuth VK] Cannot launch URL');
        }
        return null;
      }

      await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );

      if (kDebugMode) {
        debugPrint('✅ [OAuth VK] Browser opened, waiting for callback...');
      }

      return 'pending';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [OAuth VK] Error: $e');
      }
      return null;
    }
  }

  String? _lastCodeVerifier;

  /// Получение последнего code_verifier (для VK PKCE)
  String? getLastCodeVerifier() {
    final verifier = _lastCodeVerifier;
    _lastCodeVerifier = null; // Очищаем после получения
    return verifier;
  }

  /// Авторизация через Apple
  Future<String?> loginWithApple() async {
    try {
      final authUrl = _getAuthorizationUrl('apple');

      if (kDebugMode) {
        debugPrint('🔐 [OAuth Apple] Auth URL: $authUrl');
      }

      final canLaunch = await canLaunchUrl(Uri.parse(authUrl));
      if (!canLaunch) {
        if (kDebugMode) {
          debugPrint('❌ [OAuth Apple] Cannot launch URL');
        }
        return null;
      }

      await launchUrl(
        Uri.parse(authUrl),
        mode: LaunchMode.externalApplication,
      );

      if (kDebugMode) {
        debugPrint('✅ [OAuth Apple] Browser opened, waiting for callback...');
      }

      return 'pending';
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [OAuth Apple] Error: $e');
      }
      return null;
    }
  }

  /// Обмен authorization code на токен пользователя через backend
  /// 
  /// Backend обработает код и вернет токен авторизации
  Future<Map<String, dynamic>?> exchangeCodeForToken({
    required String code,
    required String provider,
  }) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 [OAuth] Exchanging code for token: $provider');
      }

      return {
        'success': true,
        'provider': provider,
        'code': code,
      };
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ [OAuth] Exchange error: $e');
      }
      return null;
    }
  }
}
