import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/domain/entities/ad_service.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

/// Утилита для показа модалки покупки услуг для объявления
class AdServicesModal {
  static Future<bool?> show(BuildContext context, int adId) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AdServicesModalContent(
        adId: adId,
        isDark: isDark,
      ),
    );
  }
}

class _AdServicesModalContent extends StatefulWidget {
  final int adId;
  final bool isDark;

  const _AdServicesModalContent({
    required this.adId,
    required this.isDark,
  });

  @override
  State<_AdServicesModalContent> createState() => _AdServicesModalContentState();
}

class _AdServicesModalContentState extends State<_AdServicesModalContent> {
  bool _isLoading = true;
  AdServicesResponse? _servicesData;
  String? _error;
  int? _selectedServiceId;
  int _selectedDays = 1;
  bool _isPurchasing = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState.user == null) {
        throw Exception('Необходимо авторизоваться');
      }

      final dio = DioClient.createDio();
      final params = {
        'key': ApiConfig.apiKey,
        'route': 'card_ad/getServices',
        'id_ad': widget.adId,
        'id_user': authState.user!.id,
        'token': authState.user!.token,
      };

      print('🔵 [AdServicesModal] Loading services...');
      print('🔵 [AdServicesModal] Full URL: ${ApiConfig.baseUrl}/systems/api/controller.php?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}');
      print('🔵 [AdServicesModal] Params: $params');

      final response = await dio.get(
        '/systems/api/controller.php',
        queryParameters: params,
      );

      print('🔵 [AdServicesModal] Response status: ${response.statusCode}');
      print('🔵 [AdServicesModal] Response data type: ${response.data.runtimeType}');
      print('🔵 [AdServicesModal] Response data: ${response.data}');

      if (response.statusCode == 200) {
        // Проверяем тип данных
        dynamic responseData = response.data;
        
        // Если пришла строка, декодируем её
        if (responseData is String) {
          print('🔵 [AdServicesModal] Decoding JSON string...');
          responseData = jsonDecode(responseData);
        }
        
        // Проверяем что это Map
        if (responseData is! Map<String, dynamic>) {
          throw Exception('Неверный формат ответа: ожидается Map, получен ${responseData.runtimeType}');
        }
        
        print('🔵 [AdServicesModal] Parsing response...');
        setState(() {
          _servicesData = AdServicesResponse.fromJson(responseData);
          _isLoading = false;
        });
        print('✅ [AdServicesModal] Services loaded successfully: ${_servicesData!.services.length} services');
      } else {
        throw Exception('Ошибка загрузки услуг: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [AdServicesModal] Error loading services: $e');
      if (e is DioException) {
        print('❌ [AdServicesModal] DioException type: ${e.type}');
        print('❌ [AdServicesModal] DioException message: ${e.message}');
        print('❌ [AdServicesModal] DioException response: ${e.response?.data}');
        print('❌ [AdServicesModal] DioException statusCode: ${e.response?.statusCode}');
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _buyService(AdService service) async {
    if (_isPurchasing) return;

    setState(() => _isPurchasing = true);

    try {
      final authState = context.read<AuthBloc>().state;
      if (authState.user == null) {
        throw Exception('Необходимо авторизоваться');
      }

      final dio = DioClient.createDio();
      final params = {
        'key': ApiConfig.apiKey,
        'route': 'card_ad/buyService',
      };
      final data = {
        'id_ad': widget.adId,
        'id_service': service.id,
        'days': _selectedDays,
        'id_user': authState.user!.id,
        'token': authState.user!.token,
      };

      print('🔵 [AdServicesModal] Buying service...');
      print('🔵 [AdServicesModal] Full URL: ${ApiConfig.baseUrl}/systems/api/controller.php?${params.entries.map((e) => '${e.key}=${e.value}').join('&')}');
      print('🔵 [AdServicesModal] Params: $params');
      print('🔵 [AdServicesModal] Data: $data');

      final response = await dio.post(
        '/systems/api/controller.php',
        queryParameters: params,
        data: data,
      );

      print('🔵 [AdServicesModal] Response status: ${response.statusCode}');
      print('🔵 [AdServicesModal] Response data type: ${response.data.runtimeType}');
      print('🔵 [AdServicesModal] Response data: ${response.data}');

      if (response.statusCode == 200) {
        // Проверяем тип данных
        dynamic result = response.data;
        
        // Если пришла строка, декодируем её
        if (result is String) {
          print('🔵 [AdServicesModal] Decoding JSON string...');
          result = jsonDecode(result);
        }
        
        // Проверяем что это Map
        if (result is! Map<String, dynamic>) {
          throw Exception('Неверный формат ответа: ожидается Map, получен ${result.runtimeType}');
        }
        
        print('🔵 [AdServicesModal] Purchase result: $result');
        
        if (result['status'] == true) {
          print('✅ [AdServicesModal] Service purchased successfully');
          if (!mounted) return;
          
          // Показываем диалог успеха
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogContext) => AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Color(0xff917dfa),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Успешно!',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              content: Text(
                result['message'] ?? 'Услуга успешно подключена',
                style: GoogleFonts.montserrat(),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff917dfa),
                  ),
                  child: Text(
                    'Отлично',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          );
          
          // Закрываем модалку
          if (mounted) {
            Navigator.of(context).pop(true);
          }
        } else {
          // Обработка ошибки от API
          print('❌ [AdServicesModal] Purchase failed: ${result['error']}');
          if (!mounted) return;
          
          // Формируем сообщение об ошибке
          String errorMessage = result['error'] ?? 'Ошибка покупки услуги';
          
          // Показываем диалог ошибки
          await showDialog(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xff917dfa),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Ошибка',
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    errorMessage,
                    style: GoogleFonts.montserrat(),
                  ),
                  // Если недостаточно средств, добавляем информацию о балансе
                  if (result['balance'] != null && result['required'] != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xff917dfa).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: const Color(0xff917dfa).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ваш баланс:',
                                style: GoogleFonts.montserrat(fontSize: 14),
                              ),
                              Text(
                                result['balance'],
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Требуется:',
                                style: GoogleFonts.montserrat(fontSize: 14),
                              ),
                              Text(
                                result['required'],
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff917dfa),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Закрыть',
                    style: GoogleFonts.montserrat(
                      color: const Color(0xff917dfa),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
          
          return; // Не выбрасываем исключение, просто выходим
        }
      } else {
        throw Exception('Ошибка покупки услуги: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [AdServicesModal] Error buying service: $e');
      if (e is DioException) {
        print('❌ [AdServicesModal] DioException type: ${e.type}');
        print('❌ [AdServicesModal] DioException message: ${e.message}');
        print('❌ [AdServicesModal] DioException response: ${e.response?.data}');
        print('❌ [AdServicesModal] DioException statusCode: ${e.response?.statusCode}');
      }
      
      if (!mounted) return;
      
      // Формируем понятное сообщение об ошибке
      String errorMessage = 'Ошибка при покупке услуги';
      
      if (e is DioException) {
        if (e.response?.statusCode == 401) {
          errorMessage = 'Ошибка авторизации. Войдите заново';
        } else if (e.response?.statusCode == 404) {
          errorMessage = 'Услуга не найдена';
        } else if (e.response?.statusCode == 500) {
          errorMessage = 'Ошибка сервера. Попробуйте позже';
        } else if (e.type == DioExceptionType.connectionTimeout) {
          errorMessage = 'Превышено время ожидания';
        } else if (e.type == DioExceptionType.connectionError) {
          errorMessage = 'Ошибка подключения к серверу';
        }
      } else {
        errorMessage = e.toString().replaceAll('Exception: ', '');
      }
      
      // Показываем диалог ошибки
      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Row(
            children: [
              const Icon(
                Icons.error_outline,
                color: Color(0xff917dfa),
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Ошибка',
                  style: GoogleFonts.montserrat(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            errorMessage,
            style: GoogleFonts.montserrat(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Закрыть',
                style: GoogleFonts.montserrat(
                  color: const Color(0xff917dfa),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xff233040) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Хэндл
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Заголовок
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Продать быстрее',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: widget.isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: widget.isDark ? Colors.white : Colors.black87,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Контент
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Ошибка загрузки',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      style: GoogleFonts.montserrat(fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadServices,
                      child: Text('Повторить', style: GoogleFonts.montserrat()),
                    ),
                  ],
                ),
              )
            else if (_servicesData != null)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Баланс
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: widget.isDark
                              ? const Color(0xff1a2332)
                              : const Color(0xffF5F5F5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              color: const Color(0xff917dfa),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Баланс: ${_servicesData!.balance}',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: widget.isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Список услуг
                      for (var service in _servicesData!.services)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _ServiceCard(
                            service: service,
                            isSelected: _selectedServiceId == service.id,
                            isDark: widget.isDark,
                            selectedDays: _selectedDays,
                            onTap: service.available
                                ? () {
                                    setState(() {
                                      _selectedServiceId = service.id;
                                      _selectedDays = service.days;
                                    });
                                  }
                                : null,
                            onDaysChanged: service.canChangeDays && _selectedServiceId == service.id
                                ? (days) {
                                    setState(() => _selectedDays = days);
                                  }
                                : null,
                          ),
                        ),

                      const SizedBox(height: 20),

                      // Кнопка покупки
                      if (_selectedServiceId != null)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isPurchasing
                                ? null
                                : () async {
                                    final service = _servicesData!.services
                                        .firstWhere((s) => s.id == _selectedServiceId);
                                    
                                    // Проверяем баланс перед покупкой
                                    final totalPrice = service.priceRaw * _selectedDays;
                                    if (_servicesData!.balanceRaw < totalPrice) {
                                      print('❌ [AdServicesModal] Insufficient balance: ${_servicesData!.balanceRaw} < $totalPrice');
                                      
                                      // Показываем диалог о недостаточном балансе
                                      await showDialog(
                                        context: context,
                                        builder: (dialogContext) => AlertDialog(
                                          title: Text(
                                            'Недостаточно средств',
                                            style: GoogleFonts.montserrat(
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'Для подключения услуги необходимо пополнить баланс.',
                                                style: GoogleFonts.montserrat(),
                                              ),
                                              const SizedBox(height: 16),
                                              Container(
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xff917dfa).withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: const Color(0xff917dfa).withValues(alpha: 0.3),
                                                  ),
                                                ),
                                                child: Column(
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          'Ваш баланс:',
                                                          style: GoogleFonts.montserrat(
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        Text(
                                                          _servicesData!.balance,
                                                          style: GoogleFonts.montserrat(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 8),
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          'Требуется:',
                                                          style: GoogleFonts.montserrat(
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                        Text(
                                                          '${totalPrice.toStringAsFixed(0)} ₽',
                                                          style: GoogleFonts.montserrat(
                                                            fontSize: 14,
                                                            fontWeight: FontWeight.w600,
                                                            color: const Color(0xff917dfa),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(dialogContext).pop(),
                                              child: Text(
                                                'Закрыть',
                                                style: GoogleFonts.montserrat(
                                                  color: const Color(0xff917dfa),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    _buyService(service);
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff917dfa),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _isPurchasing
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : Text(
                                    'Подключить',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                          ),
                        ),

                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final AdService service;
  final bool isSelected;
  final bool isDark;
  final int selectedDays;
  final VoidCallback? onTap;
  final ValueChanged<int>? onDaysChanged;

  const _ServiceCard({
    required this.service,
    required this.isSelected,
    required this.isDark,
    required this.selectedDays,
    this.onTap,
    this.onDaysChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = !service.available;
    
    return GestureDetector(
      onTap: isDisabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDisabled
              ? (isDark ? const Color(0xff1a2332) : const Color(0xffF5F5F5))
              : (isSelected
                  ? Color(service.color).withValues(alpha: 0.1)
                  : (isDark ? const Color(0xff1a2332) : Colors.white)),
          border: Border.all(
            color: isSelected
                ? Color(service.color)
                : (isDark ? const Color(0xff2a3a4a) : const Color(0xffE0E0E0)),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Иконка
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Color(service.color).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      service.icon,
                      style: const TextStyle(fontSize: 24),
                    ),
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Название и цена
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              service.name,
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDisabled
                                    ? Colors.grey
                                    : (isDark ? Colors.white : Colors.black87),
                              ),
                            ),
                          ),
                          if (service.recommended && !isDisabled)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xffFF6B6B),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'ХИТ',
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            service.price,
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isDisabled
                                  ? Colors.grey
                                  : Color(service.color),
                            ),
                          ),
                          if (service.oldPrice != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              service.oldPrice!,
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                decoration: TextDecoration.lineThrough,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Чекбокс
                if (!isDisabled)
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? Color(service.color)
                            : Colors.grey,
                        width: 2,
                      ),
                      color: isSelected ? Color(service.color) : Colors.transparent,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            size: 16,
                            color: Colors.white,
                          )
                        : null,
                  ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Описание
            Text(
              service.description,
              style: GoogleFonts.montserrat(
                fontSize: 13,
                color: isDisabled
                    ? Colors.grey
                    : (isDark ? Colors.white70 : Colors.black54),
              ),
            ),
            
            // Сообщение о недоступности
            if (isDisabled && service.message.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        service.message,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: Colors.orange,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            // Выбор количества дней
            if (isSelected && onDaysChanged != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Text(
                    'Количество дней:',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: selectedDays > 1
                        ? () => onDaysChanged!(selectedDays - 1)
                        : null,
                    color: Color(service.color),
                  ),
                  Text(
                    '$selectedDays',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: selectedDays < 30
                        ? () => onDaysChanged!(selectedDays + 1)
                        : null,
                    color: Color(service.color),
                  ),
                ],
              ),
              Text(
                'Итого: ${(service.priceRaw * selectedDays).toStringAsFixed(0)} ₽',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(service.color),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
