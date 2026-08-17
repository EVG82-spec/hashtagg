import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:hashtagg/features/search/screens/category_picker_screen.dart';
import 'package:hashtagg/features/search/screens/city_picker_screen.dart';
import 'package:hashtagg/features/listing/screens/address_picker_screen.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hashtagg/shared/presentation/utils.dart';
import 'package:hashtagg/core/network/ads_api_repository.dart';
import 'package:hashtagg/core/services/permission_service.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/presentation/screens/gallery_picker_screen.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});

  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final AdsApiRepository _adsApi = AdsApiRepository();
  final ImagePicker _imagePicker = ImagePicker();
  
  // ── Данные формы ────────────────────────────────────────────────────────────
  int? _categoryId;
  String? _categoryName;
  bool _categorySelected = false;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _videoController = TextEditingController();
  final _priceController = TextEditingController();
  final _phoneController = TextEditingController();

  int? _cityId;
  String? _cityName;
  String? _address;
  double? _latitude;
  double? _longitude;

  final List<File> _photoFiles = []; // Локальные файлы фото
  
  // Опции категории
  Map<String, dynamic>? _categoryOptions;
  bool _isLoadingOptions = false;
  
  // Режим редактирования телефона
  bool _isEditingPhone = false;
  
  // Выбранные фильтры: {filterId: [selectedItemIds]}
  Map<String, List<String>> _selectedFilters = {};
  
  // Период публикации
  int _selectedPeriod = 30; // по умолчанию 30 дней
  final List<int> _periodOptions = [7, 14, 30, 60];

  static const int _maxTitleLength = 90;
  static const int _maxDescriptionLength = 8000;

  // ── Прогресс ────────────────────────────────────────────────────────────────
  double get _progress {
    int filled = 0;
    if (_categoryId != null) filled++;
    if (_titleController.text.trim().isNotEmpty) filled++;
    if (_descriptionController.text.trim().isNotEmpty) filled++;
    if (_photoFiles.isNotEmpty) filled++;
    if (_cityId != null) filled++;
    return filled / 5;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _pickCategory());
    _titleController.addListener(() => setState(() {}));
    _descriptionController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _videoController.dispose();
    _priceController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ── Загрузка опций категории ────────────────────────────────────────────────
  Future<void> _loadCategoryOptions() async {
    if (_categoryId == null) return;
    
    setState(() => _isLoadingOptions = true);
    
    try {
      final box = Hive.box('user');
      final userData = box.get('user') as Map?;
      
      if (userData == null) {
        throw Exception('User not found');
      }
      
      final userId = userData['id'] is int 
          ? userData['id'] as int
          : int.parse(userData['id'].toString());
      
      final result = await _adsApi.getCreateOptions(
        userId: userId,
        categoryId: _categoryId!,
      );
      
      if (result['status'] == true) {
        setState(() {
          _categoryOptions = result['data'];
          _isLoadingOptions = false;
        });
        
        // Загружаем телефон пользователя, если он есть
        if (userData['phone'] != null && userData['phone'].toString().isNotEmpty) {
          _phoneController.text = userData['phone'].toString();
        }
        
        print('✅ [AddListing] Category options loaded');
      } else {
        throw Exception(result['error'] ?? 'Failed to load options');
      }
    } catch (e) {
      print('🔴 [AddListing] Error loading options: $e');
      setState(() => _isLoadingOptions = false);
      if (mounted) {
        showSwipeDownNotification(context, message: 'Ошибка загрузки настроек категории');
      }
    }
  }

  // ── Выбор категории ─────────────────────────────────────────────────────────
  Future<void> _pickCategory() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      createSwipeableRoute(
        builder: (_) => CategoryPickerScreen(
          selectedCategoryId: _categoryId,
          selectedCategory: _categoryName,
          returnId: true,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _categoryId = result['id'] as int;
        _categoryName = result['name'] as String;
        _categorySelected = true;
      });
      await _loadCategoryOptions();
    } else if (!_categorySelected) {
      // Используем Navigator.pop вместо context.pop для GoRouter routes
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      } else if (mounted) {
        context.go('/');
      }
    }
  }

  // ── Выбор города ────────────────────────────────────────────────────────────
  Future<void> _pickCity() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      createSwipeableRoute(
        builder: (_) => CityPickerScreen(
          selectedCityId: _cityId,
          selectedCity: _cityName,
          returnId: true,
        ),
      ),
    );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _cityId = result['id'] as int;
        _cityName = result['name'] as String;
        _address = null;
        // Устанавливаем координаты города, если они есть
        if (result['lat'] != null && result['lon'] != null) {
          _latitude = result['lat'] is double 
              ? result['lat'] 
              : double.tryParse(result['lat'].toString());
          _longitude = result['lon'] is double 
              ? result['lon'] 
              : double.tryParse(result['lon'].toString());
          print('🔵 [AddListing] City coordinates: lat=$_latitude, lon=$_longitude');
        }
      });
      // Сохраняем город в историю
      await _saveLocationToHistory(_cityName!, _cityId!);
    }
  }
  
  // ── Сохранение локации в историю ────────────────────────────────────────────
  Future<void> _saveLocationToHistory(String cityName, int cityId, {String? address, double? lat, double? lon}) async {
    try {
      final box = Hive.box('user');
      List<dynamic> history = box.get('location_history', defaultValue: []);
      
      // Создаем запись
      final location = {
        'city_name': cityName,
        'city_id': cityId,
        if (address != null) 'address': address,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      // Удаляем дубликаты (по city_id и address)
      history.removeWhere((item) => 
        item['city_id'] == cityId && 
        (address == null || item['address'] == address)
      );
      
      // Добавляем в начало
      history.insert(0, location);
      
      // Ограничиваем до 10 последних
      if (history.length > 10) {
        history = history.sublist(0, 10);
      }
      
      await box.put('location_history', history);
      print('✅ [AddListing] Location saved to history: $cityName${address != null ? ", $address" : ""}');
    } catch (e) {
      print('🔴 [AddListing] Error saving location to history: $e');
    }
  }
  
  // ── Загрузка истории локаций ────────────────────────────────────────────────
  List<Map<String, dynamic>> _getLocationHistory() {
  try {
    final box = Hive.box('user');
    final raw = box.get('location_history');
    if (raw == null || raw is! List) return [];
    
    return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  } catch (e) {
    print('🔴 [AddListing] Error loading location history: $e');
    return [];
  }
}

  // ── Выбор адреса ─────────────────────────────────────────────────────────────
  Future<void> _pickAddress() async {
    if (_cityName == null || _cityId == null) {
      showSwipeDownNotification(context, message: 'Сначала выберите город');
      return;
    }
    final result = await Navigator.push<Map<String, dynamic>>(
    context,
    createSwipeableRoute(
      builder: (_) => AddressPickerScreen(
        city: _cityName!,
        cityId: _cityId!,
        initialLat: _latitude,   // <-- передаём координаты города
        initialLon: _longitude,
      ),
    ),
  );
    if (!mounted) return;
    if (result != null) {
      setState(() {
        _address = result['address'];
        _latitude = result['lat'];
        _longitude = result['lon'];
      });
      print('🔵 [AddListing] Address selected: $_address (lat: $_latitude, lon: $_longitude)');
      // Сохраняем адрес в историю
      await _saveLocationToHistory(
        _cityName!,
        _cityId!,
        address: _address,
        lat: _latitude,
        lon: _longitude,
      );
    }
  }
  
  // ── Показать историю адресов ─────────────────────────────────────────────────
  Future<void> _showLocationHistory() async {
    final history = _getLocationHistory();
    
    if (history.isEmpty) {
      showSwipeDownNotification(context, message: 'История адресов пуста');
      return;
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff233040) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    
    final selected = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      'История адресов',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Список адресов
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final location = history[index];
                    final cityName = location['city_name'] as String;
                    final address = location['address'] as String?;
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        address != null ? Icons.location_on : Icons.location_city,
                        color: const Color(0xff917dfa),
                      ),
                      title: Text(
                        cityName,
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      subtitle: address != null
                          ? Text(
                              address,
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                color: isDark ? Colors.white70 : Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () => Navigator.pop(context, location),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    if (selected != null) {
      setState(() {
        _cityId = selected['city_id'] as int;
        _cityName = selected['city_name'] as String;
        _address = selected['address'] as String?;
        _latitude = selected['lat'] as double?;
        _longitude = selected['lon'] as double?;
      });
      print('✅ [AddListing] Location selected from history: $_cityName${_address != null ? ", $_address" : ""}');
    }
  }
  
  // ── Показать селектор фильтра ────────────────────────────────────────────────
  Future<void> _showFilterSelector(Map<String, dynamic> filter) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff233040) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Заголовок
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      filter['name'],
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: textColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              
              // Список опций
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: (filter['items'] as List).length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = filter['items'][index];
                    final itemId = item['id'].toString();
                    final isSelected = _selectedFilters[filter['id'].toString()]?.contains(itemId) ?? false;
                    
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        item['name'],
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          color: isSelected ? const Color(0xff917dfa) : textColor,
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Color(0xff917dfa))
                          : null,
                      onTap: () => Navigator.pop(context, itemId),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    if (selected != null) {
      setState(() {
        _selectedFilters[filter['id'].toString()] = [selected];
      });
      print('✅ [AddListing] Filter selected: ${filter['name']} = $selected');
    }
  }
  
  // ── Получить название выбранного фильтра ─────────────────────────────────────
  String? _getFilterSelectedName(Map<String, dynamic> filter) {
    final filterId = filter['id'].toString();
    final selectedId = _selectedFilters[filterId]?.firstOrNull;
    
    if (selectedId == null) return null;
    
    final items = filter['items'] as List;
    final selectedItem = items.firstWhere(
      (item) => item['id'].toString() == selectedId,
      orElse: () => null,
    );
    
    return selectedItem?['name'];
  }

  // ── Добавить фото ────────────────────────────────────────────────────────────
  Future<void> _addPhoto() async {
  if (_photoFiles.length >= 30) {
    showSwipeDownNotification(context, message: 'Максимум 30 фотографий');
    return;
  }

  // Проверяем разрешения через ваш существующий сервис
  final hasPermission = await PermissionService.requestStoragePermission(context);
  if (!hasPermission) return;

  // Открываем наш кастомный пикер
  final selectedFiles = await Navigator.push<List<File>>(
    context,
    MaterialPageRoute(
      builder: (_) => GalleryPickerScreen(
        maxCount: 30 - _photoFiles.length, // оставшееся доступное количество
      ),
    ),
  );

  if (selectedFiles != null && selectedFiles.isNotEmpty) {
    setState(() {
      _photoFiles.addAll(selectedFiles);
    });
    print('✅ [AddListing] Added ${selectedFiles.length} photos');
  }
}


  // ── Удалить фото ─────────────────────────────────────────────────────────────
  void _removePhoto(int index) {
    setState(() {
      _photoFiles.removeAt(index);
    });
    print('🔵 [AddListing] Photo removed at index $index');
  }

  // ── Сохранить телефон ────────────────────────────────────────────────────────
  Future<void> _savePhone() async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      showSwipeDownNotification(context, message: 'Введите номер телефона');
      return;
    }
    
    // Показываем загрузку
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xff917dfa)),
      ),
    );
    
    try {
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user') as Map?;
      
      if (token == null || userData == null) {
        throw Exception('Not authorized');
      }
      
      final userId = userData['id'] is int 
          ? userData['id'] as int
          : int.parse(userData['id'].toString());
      
      // Вызываем API для сохранения телефона
      final result = await _adsApi.savePhone(
        userId: userId,
        token: token,
        phone: phone,
      );
      
      if (result['status'] == true) {
        // Проверяем нужна ли верификация по SMS
        final needsVerification = result['verify'] == true;
        
        if (!mounted) return;
        Navigator.pop(context); // Закрываем диалог загрузки
        
        if (needsVerification) {
          // Показываем диалог для ввода кода
          final verificationTitle = result['title'] ?? 'Укажите код из SMS';
          await _showVerificationDialog(phone, verificationTitle, userId, token);
        } else {
          // Телефон сохранен без верификации
          // Обновляем userData в Hive
          final updatedUserData = Map<String, dynamic>.from(userData);
          updatedUserData['phone'] = phone;
          await box.put('user', updatedUserData);
          print('✅ [AddListing] Phone saved to Hive: $phone');
          
          // Обновляем в AuthBloc
          var authBloc = context.read<AuthBloc>();
          var currentUser = authBloc.state.user;
          if (currentUser != null) {
            currentUser.phone = phone;
            authBloc.add(UserUpdated(currentUser));
          }
          
          // Перезагружаем опции категории чтобы обновить added_phone
          await _loadCategoryOptions();
          
          // Выключаем режим редактирования
          setState(() {
            _isEditingPhone = false;
          });
          
          print('✅ [AddListing] Phone saved successfully, editing mode disabled');
          
          showSwipeDownNotification(
            context,
            message: 'Телефон сохранен',
          );
        }
      } else {
        // Показываем ошибку от API
        if (!mounted) return;
        Navigator.pop(context);
        showSwipeDownNotification(
          context, 
          message: result['error'] ?? 'Ошибка сохранения телефона'
        );
      }
    } catch (e) {
      print('🔴 [AddListing] Error saving phone: $e');
      if (mounted) {
        Navigator.pop(context);
        showSwipeDownNotification(
          context, 
          message: 'Ошибка сохранения телефона'
        );
      }
    }
  }
  
  // ── Показать диалог верификации телефона ─────────────────────────────────────
  Future<void> _showVerificationDialog(String phone, String title, int userId, String token) async {
    final codeController = TextEditingController();
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          autofocus: true,
          style: GoogleFonts.montserrat(fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Введите код',
            filled: true,
            fillColor: const Color(0xff917dfa).withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Отмена',
              style: GoogleFonts.montserrat(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) {
                showSwipeDownNotification(context, message: 'Введите код');
                return;
              }
              
              // Показываем загрузку
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(color: Color(0xff917dfa)),
                ),
              );
              
              try {
                final verifyResult = await _adsApi.verifyPhone(
                  userId: userId,
                  token: token,
                  phone: phone,
                  code: code,
                );
                
                if (!mounted) return;
                Navigator.pop(context); // Закрываем загрузку
                
                if (verifyResult['status'] == true) {
                  // Обновляем userData в Hive
                  final box = Hive.box('user');
                  final userData = box.get('user') as Map?;
                  if (userData != null) {
                    final updatedUserData = Map<String, dynamic>.from(userData);
                    updatedUserData['phone'] = phone;
                    await box.put('user', updatedUserData);
                    print('✅ [AddListing] Phone verified and saved to Hive: $phone');
                  }
                  
                  // Обновляем в AuthBloc
                  var authBloc = context.read<AuthBloc>();
                  var currentUser = authBloc.state.user;
                  if (currentUser != null) {
                    currentUser.phone = phone;
                    authBloc.add(UserUpdated(currentUser));
                  }
                  
                  // Перезагружаем опции категории
                  await _loadCategoryOptions();
                  
                  // Выключаем режим редактирования
                  setState(() {
                    _isEditingPhone = false;
                  });
                  
                  Navigator.pop(context, true); // Закрываем диалог верификации
                  
                  showSwipeDownNotification(
                    context,
                    message: 'Телефон подтвержден',
                  );
                } else {
                  showSwipeDownNotification(
                    context,
                    message: verifyResult['error'] ?? 'Ошибка верификации',
                  );
                }
              } catch (e) {
                print('🔴 [AddListing] Error verifying phone: $e');
                if (mounted) {
                  Navigator.pop(context);
                  showSwipeDownNotification(
                    context,
                    message: 'Ошибка верификации',
                  );
                }
              }
            },
            style: ButtonStyle(
              backgroundColor: const WidgetStatePropertyAll(Color(0xff917dfa)),
            ),
            child: Text(
              'Подтвердить',
              style: GoogleFonts.montserrat(color: Colors.white),
            ),
          ),
        ],
      ),
    );
    
    codeController.dispose();
  }

  // ── Создание объявления ──────────────────────────────────────────────────────
  Future<void> _createAd() async {
    // Валидация
    if (_titleController.text.trim().isEmpty) {
      showSwipeDownNotification(context, message: 'Введите название объявления');
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      showSwipeDownNotification(context, message: 'Введите описание объявления');
      return;
    }
    if (_cityId == null) {
      showSwipeDownNotification(context, message: 'Выберите город');
      return;
    }
    if (_photoFiles.isEmpty) {
      showSwipeDownNotification(context, message: 'Добавьте хотя бы одну фотографию');
      return;
    }
    // Проверка цены - обязательна, если поле цены доступно для категории
    if (_categoryOptions?['price'] != null && _priceController.text.trim().isEmpty) {
      showSwipeDownNotification(context, message: 'Укажите цену');
      return;
    }
    // Проверка телефона - всегда обязателен
    if (_phoneController.text.trim().isEmpty) {
      showSwipeDownNotification(context, message: 'Укажите номер телефона');
      return;
    }
    
    // Показываем загрузку
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xff917dfa)),
      ),
    );
    
    try {
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user') as Map?;
      
      if (token == null || userData == null) {
        throw Exception('Not authorized');
      }
      
      final userId = userData['id'] is int 
          ? userData['id'] as int
          : int.parse(userData['id'].toString());
      
      // Загружаем фото на сервер
      print('🔵 [AddListing] Uploading ${_photoFiles.length} photos...');
      final uploadedPhotos = <Map<String, String>>[];
      
      for (int i = 0; i < _photoFiles.length; i++) {
        final file = _photoFiles[i];
        print('🔵 [AddListing] Uploading photo ${i + 1}/${_photoFiles.length}');
        
        // Читаем файл и конвертируем в base64
        final bytes = await file.readAsBytes();
        final base64Image = base64Encode(bytes);
        
        // Загружаем на сервер
        final uploadResult = await _adsApi.uploadPhoto(
          userId: userId,
          token: token,
          imageBase64: base64Image,
        );
        
        if (uploadResult['status'] == true) {
          uploadedPhotos.add({
            'name': uploadResult['name'],
          });
          print('✅ [AddListing] Photo ${i + 1} uploaded: ${uploadResult['name']}');
        } else {
          throw Exception('Ошибка загрузки фото ${i + 1}: ${uploadResult['error']}');
        }
      }
      
      print('✅ [AddListing] All photos uploaded: ${uploadedPhotos.length}');
      
      // Подготовка данных
      List<Map<String, String>> filtersList = [];
        _selectedFilters.forEach((filterId, items) {
          for (final item in items) {
            if (item.isNotEmpty) {
              filtersList.add({'filterId': filterId, 'item': item});
            }
          }
      });

      final adData = {
        'cat_id': _categoryId!,
        'title': _titleController.text.trim(),
        'text': _descriptionController.text.trim(),
        'city_id': _cityId!,
        'period': _selectedPeriod,
        'images': jsonEncode(uploadedPhotos),
        if (_priceController.text.isNotEmpty) 
          'price': double.tryParse(_priceController.text) ?? 0,
        if (_videoController.text.isNotEmpty) 
          'video': _videoController.text.trim(),
        if (_address != null) 'address': _address!,
        if (_latitude != null) 'lat': _latitude.toString(),
        if (_longitude != null) 'lon': _longitude.toString(),
        if (_phoneController.text.isNotEmpty) 
          'phone': _phoneController.text.trim(),
        'filters': jsonEncode(filtersList),
      };
      
      // Создаем объявление
      final result = await _adsApi.createAd(
        userId: userId,
        token: token,
        adData: adData,
      );
      
      if (!mounted) return;
      Navigator.pop(context); // Закрываем диалог загрузки
      
      if (result['status'] == true) {
        final adId = result['id'];
        final adStatus = result['ad_status'];
        
        // Если статус 6 (Ждет оплаты), перенаправляем на профиль в архивные
        if (adStatus == 6) {
          showSwipeDownNotification(
            context,
            message: 'Необходимо внести оплату для публикации. Нажмите на меню управления объявлением, чтобы произвести оплату.',
            duration: Duration(seconds: 15),
          );
          // Переходим на профиль с сортировкой "archive"
          context.go('/profile?sorting=archive');
        } else {
          showSwipeDownNotification(
            context,
            message: 'Объявление создано успешно!',
          );
          // Переходим к просмотру объявления
          context.go('/listing/$adId');
        }
      } else {
        showSwipeDownNotification(
          context,
          message: result['error'] ?? 'Ошибка создания объявления',
        );
      }
    } catch (e) {
      print('🔴 [AddListing] Error creating ad: $e');
      if (mounted) {
        Navigator.pop(context);
        showSwipeDownNotification(context, message: 'Ошибка: $e');
      }
    }
  }

  // ── Виджет селектора ─────────────────────────────────────────────────────────
  Widget _buildSelector({
    required String label,
    required String? value,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inputBgColor = isDark ? const Color(0xff233040) : const Color(0xFFF0F4F8);
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white54 : const Color(0xff999999);
    final iconColor = isDark ? Colors.white54 : const Color(0xff999999);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: inputBgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? label,
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  color: value != null ? textColor : hintColor,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: iconColor),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff151e27) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputBgColor = isDark ? const Color(0xff233040) : const Color(0xFFF0F4F8);
    
    if (!_categorySelected || _isLoadingOptions) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: _isLoadingOptions
              ? const CircularProgressIndicator(color: Color(0xff917dfa))
              : const SizedBox(),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        // При нажатии кнопки назад переходим на Home
        context.go('/');
        return false; // Предотвращаем стандартное поведение
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: bgColor,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => context.go('/'),
        ),
        title: Text(
          _categoryName ?? 'Новое объявление',
          style: GoogleFonts.montserrat(
            color: textColor,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _progress,
                    strokeWidth: 3,
                    backgroundColor: isDark ? Colors.white24 : Colors.grey[200],
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xff917dfa),
                    ),
                  ),
                  Text(
                    '${(_progress * 100).round()}%',
                    style: GoogleFonts.montserrat(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Название ──────────────────────────────────────────
                  if (_categoryOptions?['auto_title'] != true) ...[
                    _SectionTitle(title: 'Название'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _titleController,
                      maxLength: _maxTitleLength,
                      maxLines: 1,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              'Символов $currentLength из $maxLength',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : const Color(0xff999999),
                              ),
                            ),
                          ),
                      style: GoogleFonts.montserrat(fontSize: 15, color: textColor),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBgColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Описание ──────────────────────────────────────────
                  _SectionTitle(title: 'Описание'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _descriptionController,
                    maxLength: _maxDescriptionLength,
                    maxLines: 5,
                    buildCounter: (context, {required currentLength, required isFocused, maxLength}) =>
                        Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            'Символов $currentLength из $maxLength',
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : const Color(0xff999999),
                            ),
                          ),
                        ),
                    style: GoogleFonts.montserrat(fontSize: 15, color: textColor),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputBgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── Цена ──────────────────────────────────────────────
                  if (_categoryOptions?['price'] != null) ...[
                    _SectionTitle(title: '${_categoryOptions!['price']['title'] ?? 'Цена'} *'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      style: GoogleFonts.montserrat(fontSize: 15, color: textColor),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBgColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        suffixText: '₽',
                        suffixStyle: GoogleFonts.montserrat(color: textColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Номер телефона ────────────────────────────────────
                  if (_categoryOptions?['added_phone'] != null) ...[
                    _SectionTitle(title: 'Номер телефона *'),
                    const SizedBox(height: 4),
                    Text(
                      'Для публикации объявления необходимо указать номер телефона. Скрыть его или изменить Вы сможете в настройках профиля.',
                      style: GoogleFonts.montserrat(
                        fontSize: 13,
                        color: isDark ? Colors.white70 : const Color(0xff999999),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    
                    // Если телефона нет ИЛИ режим редактирования - показываем поле ввода
                    if (_categoryOptions!['added_phone'] == true || _isEditingPhone) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.montserrat(fontSize: 15, color: textColor),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: inputBgColor,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              hintText: '+7 (___) ___-__-__',
                              hintStyle: GoogleFonts.montserrat(
                                color: isDark ? Colors.white54 : const Color(0xff999999),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _savePhone,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xff917dfa),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'Сохранить',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Если телефон уже есть - показываем его с кнопкой "Изменить"
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: inputBgColor,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                _phoneController.text.isNotEmpty 
                                    ? _phoneController.text 
                                    : 'Телефон не указан',
                                style: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  color: textColor,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                // Включаем режим редактирования
                                setState(() {
                                  _isEditingPhone = true;
                                });
                              },
                              child: Text(
                                'Изменить',
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xff917dfa),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],

                  // ── Фильтры ───────────────────────────────────────────
                  if (_categoryOptions?['filters'] != null) ...[
                    for (var filter in _categoryOptions!['filters']) ...[
                      _SectionTitle(
                        title: filter['name'] + (filter['required'] == true ? ' *' : ''),
                      ),
                      const SizedBox(height: 10),
                      
                      if (filter['view'] == 'select') ...[
                        // Селектор для одиночного выбора
                        GestureDetector(
                          onTap: () => _showFilterSelector(filter),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: inputBgColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _getFilterSelectedName(filter) ?? 'Выберите ${filter['name'].toLowerCase()}',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      color: _getFilterSelectedName(filter) != null 
                                          ? textColor 
                                          : (isDark ? Colors.white54 : const Color(0xff999999)),
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right,
                                  color: isDark ? Colors.white54 : const Color(0xff999999),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (filter['view'] == 'checkbox') ...[
                        // Чекбоксы для множественного выбора
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (filter['items'] as List).map<Widget>((item) {
                            final filterId = filter['id'].toString();
                            final itemId = item['id'].toString();
                            final isSelected = _selectedFilters[filterId]?.contains(itemId) ?? false;
                            
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (!_selectedFilters.containsKey(filterId)) {
                                    _selectedFilters[filterId] = [];
                                  }
                                  if (isSelected) {
                                    _selectedFilters[filterId]!.remove(itemId);
                                  } else {
                                    _selectedFilters[filterId]!.add(itemId);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xff917dfa)
                                      : const Color(0xFFF0F4F8),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  item['name'],
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ] else if (filter['view'] == 'input') ...[
                        // Текстовое поле для ввода
                        TextField(
                          onChanged: (value) {
                            setState(() {
                              _selectedFilters[filter['id'].toString()] = [value];
                            });
                          },
                          style: GoogleFonts.montserrat(fontSize: 15, color: textColor),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: inputBgColor,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            hintText: 'Введите ${filter['name'].toLowerCase()}',
                            hintStyle: GoogleFonts.montserrat(
                              color: isDark ? Colors.white54 : const Color(0xff999999),
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 8),
                    ],
                  ],

                  // ── Фото ──────────────────────────────────────────────
                  _SectionTitle(title: 'Фото'),
                  const SizedBox(height: 4),
                  Text(
                    'Первое фото будет отображаться в результатах поиска. Можно загрузить до 30 фотографий',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xff999999),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_photoFiles.isNotEmpty) ...[
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _photoFiles.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          return SizedBox(
                            width: 90,
                            height: 90,
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    _photoFiles[index],
                                    width: 90,
                                    height: 90,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                // Водяной знак – точно по центру
                                Positioned.fill(
                                  child: Center(
                                    child: Opacity(
                                      opacity: 0.29,
                                      child: Image.asset(
                                        'assets/logo.png',
                                        width: 50,
                                        height: 50,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removePhoto(index),
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  GestureDetector(
                    onTap: _photoFiles.length < 30 ? _addPhoto : null,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xff917dfa),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.image_outlined,
                            color: Colors.white,
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'Добавить фото',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Видео ─────────────────────────────────────────────
                  _SectionTitle(title: 'Видео'),
                  const SizedBox(height: 4),
                  Text(
                    'Укажите ссылку на видео (YouTube, Rutube)',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : const Color(0xff999999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _videoController,
                    style: GoogleFonts.montserrat(fontSize: 15, color: textColor),
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputBgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Местоположение ────────────────────────────────────
                  _SectionTitle(title: 'Местоположение'),
                  const SizedBox(height: 10),
                  
                  // Кнопка истории адресов
                  if (_getLocationHistory().isNotEmpty) ...[
                    GestureDetector(
                      onTap: _showLocationHistory,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xff917dfa).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xff917dfa).withOpacity(0.29),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.history,
                              color: Color(0xff917dfa),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Выбрать из истории',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xff917dfa),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  _buildSelector(
                    label: 'Город',
                    value: _cityName,
                    onTap: _pickCity,
                  ),

                  const SizedBox(height: 10),

                  _buildSelector(
                    label: 'Указать адрес',
                    value: _address,
                    onTap: _pickAddress,
                  ),

                  const SizedBox(height: 20),

                  // ── Срок публикации ───────────────────────────────────
                  _SectionTitle(title: 'Срок публикации'),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _periodOptions.map((days) {
                      final isSelected = _selectedPeriod == days;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedPeriod = days),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xff917dfa)
                                : inputBgColor,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$days дней',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: isSelected ? Colors.white : textColor,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          // ── Кнопка «Опубликовать» ─────────────────────────────────────
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              top: 8,
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createAd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff917dfa),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Опубликовать',
                  style: GoogleFonts.montserrat(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

// ── Заголовок секции ─────────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      title,
      style: GoogleFonts.montserrat(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: isDark ? Colors.white : Colors.black,
      ),
    );
  }
}