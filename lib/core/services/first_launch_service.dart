import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hashtagg/core/services/permission_service.dart';
import 'package:hashtagg/core/network/geo_api_repository.dart';
import 'package:google_fonts/google_fonts.dart';

/// Сервис для обработки первого запуска приложения
class FirstLaunchService {
  static const String _firstLaunchKey = 'is_first_launch';
  static const String _permissionsRequestedKey = 'permissions_requested';
  
  /// Проверить, является ли это первым запуском
  static Future<bool> isFirstLaunch() async {
    final box = await Hive.openBox('settings');
    final isFirst = box.get(_firstLaunchKey, defaultValue: true) as bool;
    return isFirst;
  }
  
  /// Отметить, что первый запуск завершен
  static Future<void> markFirstLaunchComplete() async {
    final box = await Hive.openBox('settings');
    await box.put(_firstLaunchKey, false);
  }
  
  /// Проверить, были ли запрошены разрешения
  static Future<bool> werePermissionsRequested() async {
    final box = await Hive.openBox('settings');
    final requested = box.get(_permissionsRequestedKey, defaultValue: false) as bool;
    return requested;
  }
  
  /// Отметить, что разрешения были запрошены
  static Future<void> markPermissionsRequested() async {
    final box = await Hive.openBox('settings');
    await box.put(_permissionsRequestedKey, true);
  }
  
  /// Показать диалог запроса разрешений при первом запуске
  static Future<void> showFirstLaunchPermissionsDialog(BuildContext context) async {
    final isFirst = await isFirstLaunch();
    final permissionsRequested = await werePermissionsRequested();
    
    print('🔵 [FirstLaunch] isFirstLaunch: $isFirst, permissionsRequested: $permissionsRequested');
    
    if (!isFirst || permissionsRequested) {
      print('⏭️ [FirstLaunch] Skipping permissions dialog');
      return;
    }
    
    print('✅ [FirstLaunch] Showing permissions dialog');
    
    // Показываем диалог с объяснением
    final shouldRequest = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Добро пожаловать!',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Для полноценной работы приложению требуется доступ к:\n\n'
          '📷 Камере - для создания фото объявлений и историй\n'
          '📁 Файлам - для выбора фото и видео\n'
          '📍 Геолокации - для показа объявлений рядом с вами',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Позже',
              style: GoogleFonts.montserrat(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Предоставить',
              style: GoogleFonts.montserrat(color: Color(0xff917dfa)),
            ),
          ),
        ],
      ),
    );
    
    await markPermissionsRequested();
    
    if (shouldRequest == true) {
      print('✅ [FirstLaunch] User accepted, requesting permissions');
      await _requestAllPermissions(context);
    } else {
      print('⚠️ [FirstLaunch] User declined, setting Vladivostok as default');
      // Если пользователь отказался, всё равно устанавливаем Владивосток
      await _setVladivostokAsDefault(context);
    }
    
    await markFirstLaunchComplete();
  }
  
  /// Запросить все разрешения
  static Future<void> _requestAllPermissions(BuildContext context) async {
    print('🔵 [FirstLaunch] Requesting all permissions...');
    
    // Сначала устанавливаем Владивосток по умолчанию
    await _setVladivostokAsDefault(context);
    
    // Запрашиваем разрешения последовательно (без уведомлений при отказе)
    print('📷 [FirstLaunch] Requesting camera permission...');
    await PermissionService.requestCameraPermission(context, showMessages: false);
    
    print('📁 [FirstLaunch] Requesting storage permission...');
    await PermissionService.requestStoragePermission(context, showMessages: false);
    
    print('📍 [FirstLaunch] Requesting location permission...');
    final locationGranted = await PermissionService.requestLocationPermission(context, showMessages: false);
    
    print('✅ [FirstLaunch] Location granted: $locationGranted');
    
    // Если геолокация предоставлена, пытаемся определить текущий город
    if (locationGranted) {
      print('🌍 [FirstLaunch] Trying to detect current city...');
      await _trySetCurrentLocation(context);
    }
  }
  
  /// Попытаться определить текущую геолокацию и установить город
  static Future<void> _trySetCurrentLocation(BuildContext context) async {
    try {
      // Проверяем, включена ли служба геолокации
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        print('⚠️ [FirstLaunch] Location service is disabled, keeping Vladivostok');
        return;
      }
      
      // Получаем текущую позицию
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 10),
      );
      
      print('📍 [FirstLaunch] Current position: ${position.latitude}, ${position.longitude}');
      
      // Ищем ближайший город через API
      print('🔵 [FirstLaunch] Calling GeoApiRepository.getCityByCoordinates...');
      final geoApi = GeoApiRepository();
      final result = await geoApi.getCityByCoordinates(
        lat: position.latitude,
        lon: position.longitude,
      );
      
      print('🔵 [FirstLaunch] API result: ${result['status']}, data: ${result['data']}');
      
      if (result['status'] == true && result['data'] != null) {
        final cityData = result['data'];
        // API возвращает city_id как строку, нужно конвертировать
        final cityIdRaw = cityData['city_id'];
        final cityId = cityIdRaw is int ? cityIdRaw : int.tryParse(cityIdRaw.toString());
        final cityName = cityData['city_name'] as String?;
        final declination = cityData['declination'] as String?;
        // lat и lon тоже могут быть строками
        final latRaw = cityData['lat'];
        final lonRaw = cityData['lon'];
        final lat = latRaw is double ? latRaw : double.tryParse(latRaw.toString());
        final lon = lonRaw is double ? lonRaw : double.tryParse(lonRaw.toString());
        
        print('🔵 [FirstLaunch] Parsed city data: ID=$cityId, Name=$cityName, Declination=$declination');
        
        if (cityId != null && cityName != null) {
          // Перезаписываем Владивосток на текущий город
          final box = await Hive.openBox('settings');
          await box.put('selectedCityId', cityId);
          await box.put('selectedCityName', cityName);
          await box.put('selectedCityDeclination', declination ?? '');
          await box.put('selectedCityLat', lat);
          await box.put('selectedCityLon', lon);
          
          print('✅ [FirstLaunch] Updated city to current location: $cityName (ID: $cityId)');
        } else {
          print('⚠️ [FirstLaunch] City ID or Name is null, re-setting Vladivostok');
          await _setVladivostokAsDefault(context);
        }
      } else {
        print('⚠️ [FirstLaunch] Failed to get city: status=${result['status']}, error=${result['error']}, re-setting Vladivostok');
        await _setVladivostokAsDefault(context);
      }
    } catch (e) {
      print('⚠️ [FirstLaunch] Error getting location: $e, re-setting Vladivostok');
      await _setVladivostokAsDefault(context);
    }
  }
  
  /// Установить Владивосток как город по умолчанию
  static Future<void> _setVladivostokAsDefault(BuildContext context) async {
    try {
      print('🔵 [FirstLaunch] Setting Vladivostok as default (hardcoded)...');
      
      // Захардкоженные данные Владивостока
      const cityId = 732;
      const cityName = 'Владивосток';
      const declination = 'во Владивостоке';
      const lat = 43.115542;
      const lon = 131.885494;
      
      final box = await Hive.openBox('settings');
      await box.put('selectedCityId', cityId);
      await box.put('selectedCityName', cityName);
      await box.put('selectedCityDeclination', declination);
      await box.put('selectedCityLat', lat);
      await box.put('selectedCityLon', lon);
      
      // Проверяем, что данные действительно записались
      final savedId = box.get('selectedCityId');
      final savedName = box.get('selectedCityName');
      print('✅ [FirstLaunch] Set Vladivostok as default: $cityName (ID: $cityId)');
      print('✅ [FirstLaunch] Verified saved values: ID=$savedId, Name=$savedName');
    } catch (e) {
      print('🔴 [FirstLaunch] Error setting Vladivostok as default: $e');
    }
  }
}
