import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

/// Сервис для управления разрешениями приложения
class PermissionService {
  /// Запрос разрешения на камеру
  /// 
  /// [showMessages] - показывать ли уведомления при отказе (по умолчанию true)
  static Future<bool> requestCameraPermission(BuildContext context, {bool showMessages = true}) async {
    final status = await Permission.camera.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      final result = await Permission.camera.request();
      if (result.isGranted) {
        return true;
      }
      if (showMessages) {
        if (result.isPermanentlyDenied) {
          _showPermissionDeniedDialog(
            context,
            'Доступ к камере',
            'Для продолжения необходимо предоставить права доступа к камере в настройках приложения',
          );
        } else {
          _showPermissionRequiredSnackbar(context, 'Для продолжения необходимо предоставить права доступа к камере');
        }
      }
      return false;
    }
    
    if (status.isPermanentlyDenied) {
      if (showMessages) {
        _showPermissionDeniedDialog(
          context,
          'Доступ к камере',
          'Для продолжения необходимо предоставить права доступа к камере в настройках приложения',
        );
      }
      return false;
    }
    
    return false;
  }
  
  /// Запрос разрешения на галерею/файлы
  /// 
  /// [showMessages] - показывать ли уведомления при отказе (по умолчанию true)
  static Future<bool> requestStoragePermission(BuildContext context, {bool showMessages = true}) async {
    Permission permission;
    
    if (Platform.isAndroid) {
      // Определяем версию Android
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      if (sdkInt >= 33) {
        // Android 13+ (API 33+) - используем photos/videos
        permission = Permission.photos;
      } else {
        // Android 12 и ниже (включая Android 10) - используем storage
        permission = Permission.storage;
      }
    } else {
      // iOS всегда использует photos
      permission = Permission.photos;
    }
    
    final status = await permission.status;
    
    if (status.isGranted || status.isLimited) {
      return true;
    }
    
    if (status.isDenied) {
      final result = await permission.request();
      if (result.isGranted || result.isLimited) {
        return true;
      }
      if (showMessages) {
        if (result.isPermanentlyDenied) {
          _showPermissionDeniedDialog(
            context,
            'Доступ к файлам',
            'Для продолжения необходимо предоставить права доступа к файлам в настройках приложения',
          );
        } else {
          _showPermissionRequiredSnackbar(context, 'Для продолжения необходимо предоставить права доступа к файлам');
        }
      }
      return false;
    }
    
    if (status.isPermanentlyDenied) {
      if (showMessages) {
        _showPermissionDeniedDialog(
          context,
          'Доступ к файлам',
          'Для продолжения необходимо предоставить права доступа к файлам в настройках приложения',
        );
      }
      return false;
    }
    
    return false;
  }
  
  /// Запрос разрешения на геолокацию
  /// 
  /// [showMessages] - показывать ли уведомления при отказе (по умолчанию true)
  static Future<bool> requestLocationPermission(BuildContext context, {bool showMessages = true}) async {
    final status = await Permission.locationWhenInUse.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      final result = await Permission.locationWhenInUse.request();
      if (result.isGranted) {
        return true;
      }
      if (showMessages) {
        if (result.isPermanentlyDenied) {
          _showPermissionDeniedDialog(
            context,
            'Доступ к геолокации',
            'Для продолжения необходимо предоставить права доступа к геолокации в настройках приложения',
          );
        } else {
          _showPermissionRequiredSnackbar(context, 'Для продолжения необходимо предоставить права доступа к геолокации');
        }
      }
      return false;
    }
    
    if (status.isPermanentlyDenied) {
      if (showMessages) {
        _showPermissionDeniedDialog(
          context,
          'Доступ к геолокации',
          'Для продолжения необходимо предоставить права доступа к геолокации в настройках приложения',
        );
      }
      return false;
    }
    
    return false;
  }
  
  /// Показать уведомление о необходимости разрешения
  static void _showPermissionRequiredSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.montserrat(color: Colors.white),
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
  
  /// Показать диалог с предложением открыть настройки
  static void _showPermissionDeniedDialog(
    BuildContext context,
    String title,
    String message,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Отмена',
              style: GoogleFonts.montserrat(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              openAppSettings();
            },
            child: Text(
              'Настройки',
              style: GoogleFonts.montserrat(color: Color(0xff917dfa)),
            ),
          ),
        ],
      ),
    );
  }
}
