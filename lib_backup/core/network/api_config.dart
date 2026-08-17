class ApiConfig {
  // static const String baseUrl = 'http://192.168.1.3:8000';
  static const String baseUrl = 'https://hashtagg.ru';
  
  // static const String mediaUrl = 'http://192.168.1.3:8000';
  static const String mediaUrl = 'https://hashtagg.ru';
  
  // static const String webUrl = 'http://192.168.1.3:80';
  static const String webUrl = 'https://hashtagg.ru';

  static const String oauthUrl = 'https://hashtagg.ru';
  
  // static const String reverbUrl = '192.168.1.3';
  static const String reverbUrl = '62.181.44.143';
  
  // static const int reverbPort = 8080;
  static const int reverbPort = 8092;

  static const String reverbKey = 'isqj88lps6rcq2etmdb2';
  static const String reverbScheme = 'http';
  // static const String reverbScheme = 'https';
  
  static const String apiKey = '3090379067';
  
  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  static const String loginEndpoint = 'profile/auth/auth';
  static const String tokenAuthEndpoint = 'profile/auth/authToken';
  static const String recoveryEndpoint = 'profile/auth/recovery';
  static const String registrationEndpoint = 'profile/auth/reg';
  static const String profileDataEndpoint = 'profile/card/getData';
  
  static String replaceMediaUrl(String url) {
    url = url.replaceAll(RegExp(r'https?://localhost(:\d+)?'), mediaUrl);
    
    if (url.startsWith('localhost')) {
      url = url.replaceFirst(RegExp(r'localhost(:\d+)?'), mediaUrl);
    }
    
    return url;
  }
  
  static String buildWebUrl(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$webUrl/$cleanPath';
  }
}
