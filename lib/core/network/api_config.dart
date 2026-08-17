class ApiConfig {
  static const String baseUrl = 'https://hashtagg.ru';
  static const String mediaUrl = 'https://hashtagg.ru';
  static const String webUrl = 'https://hashtagg.ru';
  static const String oauthUrl = 'https://hashtagg.ru';
  static const String reverbUrl = '62.181.44.143';
  static const int reverbPort = 8092;
  static const String reverbKey = 'isqj88lps6rcq2etmdb2';
  static const String reverbScheme = 'http';
  static const String apiKey = '3090379067';
  static const String yandexGeocoderKey = '88617fda-cf4b-45ad-9ce2-3e2f71baf2d0';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const String loginEndpoint = 'profile/auth/auth';
  static const String tokenAuthEndpoint = 'profile/auth/authToken';
  static const String recoveryEndpoint = 'profile/auth/recovery';
  static const String registrationEndpoint = 'profile/auth/reg';
  static const String profileDataEndpoint = 'profile/card/getData';

  static String replaceMediaUrl(String url) {
    // Если уже полный URL - возвращаем как есть
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }

    // Если начинается с /media/ - добавляем базовый URL
    if (url.startsWith('/media/')) {
      return '$mediaUrl$url';
    }

    // Если начинается с media/ - добавляем базовый URL
    if (url.startsWith('media/')) {
      return '$mediaUrl/$url';
    }

    // Если просто имя файла - формируем путь к ads
    if (url.isNotEmpty) {
      return '$mediaUrl/media/ads/$url';
    }

    return url;
  }

  static String buildWebUrl(String path) {
    final cleanPath = path.startsWith('/') ? path.substring(1) : path;
    return '$webUrl/$cleanPath';
  }
}