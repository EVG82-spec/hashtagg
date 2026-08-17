import 'package:dio/dio.dart';
import 'dart:convert';
import 'api_config.dart';

class SettingsApiRepository {
  final Dio _dio;

  SettingsApiRepository({Dio? dio}) : _dio = dio ?? Dio(BaseOptions(
    baseUrl: ApiConfig.baseUrl,
    headers: {
      'Content-Type': 'application/x-www-form-urlencoded',
    },
  ));

  /// Получение настроек приложения (включая баннеры)
  Future<Map<String, dynamic>> getSettings() async {
    try {
      print('🔵 [SettingsApi] Getting app settings');
      
      final response = await _dio.get(
        '/systems/api/controller.php',
        queryParameters: {
          'key': '3090379067',
          'route': 'getSettings',
        },
        options: Options(
          validateStatus: (status) => true,
        ),
      );

      print('🔵 [SettingsApi] Settings response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        var data = response.data is String 
            ? json.decode(response.data) 
            : response.data;
        
        print('📥 [SettingsApi] Raw response: ${json.encode(data)}');
        
        // Заменяем localhost на правильный URL во всех изображениях
        final dataString = json.encode(data);
        final fixedDataString = ApiConfig.replaceMediaUrl(dataString);
        data = json.decode(fixedDataString);
        
        print('✅ [SettingsApi] Settings loaded');
        print('🔵 [SettingsApi] Banner status: ${data['data']?['home_adv_header_status']}');
        print('🔵 [SettingsApi] Banner data: ${data['data']?['home_adv_header']}');
        print('🔵 [SettingsApi] Promo slider status: ${data['data']?['home_promo_slider_status']}');
        print('🔵 [SettingsApi] Promo slider list: ${data['data']?['home_promo_slider_list']}');
        print('🔵 [SettingsApi] Promo banner list: ${data['data']?['home_promo_banner_list']}');
        
        return {'status': true, 'data': data['data']};
      } else {
        print('🔴 [SettingsApi] Server error ${response.statusCode}: ${response.data}');
        return {'status': false, 'error': 'Server error: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      print('🔴 [SettingsApi] Settings exception: $e');
      return {'status': false, 'error': e.message ?? 'Network error'};
    } catch (e) {
      print('🔴 [SettingsApi] Settings error: $e');
      return {'status': false, 'error': e.toString()};
    }
  }
}
