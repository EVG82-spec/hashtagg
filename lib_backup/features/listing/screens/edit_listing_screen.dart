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
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hashtagg/shared/presentation/utils.dart';
import 'package:hashtagg/core/network/ads_api_repository.dart';
import 'package:hashtagg/core/services/permission_service.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/presentation/screens/gallery_picker_screen.dart';

class EditListingScreen extends StatefulWidget {
  final int adId;

  const EditListingScreen({
    super.key,
    required this.adId,
  });

  @override
  State<EditListingScreen> createState() => _EditListingScreenState();
}

class _EditListingScreenState extends State<EditListingScreen> {
  final AdsApiRepository _adsApi = AdsApiRepository();

  // ── Данные формы ────────────────────────────────────────────────────────────
  int? _categoryId;
  String? _categoryName;
  bool _isLoading = true;

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

  final List<File> _newPhotoFiles = []; // Новые локальные файлы
  final List<Map<String, String>> _existingPhotos = []; // Существующие фото с сервера

  // Опции категории
  Map<String, dynamic>? _categoryOptions;
  Map<String, dynamic>? _adData;

  // Выбранные фильтры: {filterId: [selectedItemIds]}
  Map<String, List<String>> _selectedFilters = {};

  // Период публикации
  int _selectedPeriod = 30;
  final List<int> _periodOptions = [7, 14, 30, 60, 90];

  // Режим редактирования телефона
  bool _isEditingPhone = false;

  static const int _maxTitleLength = 90;
  static const int _maxDescriptionLength = 8000;

  // ── Прогресс ────────────────────────────────────────────────────────────────
  double get _progress {
    int filled = 0;
    if (_categoryId != null) filled++;
    if (_titleController.text.trim().isNotEmpty) filled++;
    if (_descriptionController.text.trim().isNotEmpty) filled++;
    if (_existingPhotos.isNotEmpty || _newPhotoFiles.isNotEmpty) filled++;
    if (_cityId != null) filled++;
    return filled / 5;
  }

  @override
  void initState() {
    super.initState();
    _loadAdData();
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

  // ── Сохранение локации в историю ────────────────────────────────────────────
  Future<void> _saveLocationToHistory(String cityName, int cityId, {String? address, double? lat, double? lon}) async {
    try {
      final box = Hive.box('user');
      List<dynamic> history = box.get('location_history', defaultValue: []);

      final Map<String, dynamic> location = {
        'city_name': cityName,
        'city_id': cityId,
        if (address != null) 'address': address,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      history.removeWhere((item) =>
          item['city_id'] == cityId && (address == null || item['address'] == address));

      history.insert(0, location);
      if (history.length > 10) history = history.sublist(0, 10);
      await box.put('location_history', history);
      print('✅ [EditListing] Location saved to history: $cityName${address != null ? ", $address" : ""}');
    } catch (e) {
      print('🔴 [EditListing] Error saving location to history: $e');
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
      print('🔴 [EditListing] Error loading location history: $e');
      return [];
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
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text('История адресов',
                        style: GoogleFonts.montserrat(
                            fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const Spacer(),
                    IconButton(
                        icon: Icon(Icons.close, color: textColor),
                        onPressed: () => Navigator.pop(context)),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, index) {
                    final loc = history[index];
                    final city = loc['city_name'] as String;
                    final addr = loc['address'] as String?;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                          addr != null ? Icons.location_on : Icons.location_city,
                          color: const Color(0xff917dfa)),
                      title: Text(city,
                          style: GoogleFonts.montserrat(
                              fontSize: 15, fontWeight: FontWeight.w600, color: textColor)),
                      subtitle: addr != null
                          ? Text(addr,
                              style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.grey[600]),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis)
                          : null,
                      onTap: () => Navigator.pop(context, loc),
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
      print('✅ [EditListing] Location selected from history: $_cityName${_address != null ? ", $_address" : ""}');
    }
  }

  // ── Загрузка данных объявления ───────────────────────────────────────────────
  Future<void> _loadAdData() async {
    setState(() => _isLoading = true);
    try {
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user') as Map?;
      if (token == null || userData == null) throw Exception('Not authorized');
      final userId = userData['id'] is int ? userData['id'] as int : int.parse(userData['id'].toString());
      final result = await _adsApi.loadAdForEdit(userId: userId, token: token, adId: widget.adId);
      if (result['status'] == true) {
        final data = result['data'];
        _adData = data['data'];
        _categoryOptions = data;
        setState(() {
          _categoryId = _adData!['id_cat'] is int ? _adData!['id_cat'] as int : int.tryParse(_adData!['id_cat'].toString());
          _categoryName = _adData!['category_name'];
          _titleController.text = _adData!['title'] ?? '';
          _descriptionController.text = _adData!['text'] ?? '';
          _videoController.text = _adData!['video_link'] ?? '';
          if (_adData!['price'] != null) _priceController.text = _adData!['price'].toString();
          if (userData['phone'] != null && userData['phone'].toString().isNotEmpty) {
            _phoneController.text = userData['phone'].toString();
          }
          _cityId = _adData!['city_id'] is int ? _adData!['city_id'] as int : int.tryParse(_adData!['city_id'].toString());
          _cityName = _adData!['city_name'];
          _address = _adData!['address'];
          if (_adData!['latitude'] != null && _adData!['latitude'].toString().isNotEmpty) {
            _latitude = double.tryParse(_adData!['latitude'].toString());
          }
          if (_adData!['longitude'] != null && _adData!['longitude'].toString().isNotEmpty) {
            _longitude = double.tryParse(_adData!['longitude'].toString());
          }
          if (_adData!['images'] != null) {
            final images = _adData!['images'] as List;
            _existingPhotos.clear();
            for (var img in images) {
              final url = img['link'] ?? '';
              _existingPhotos.add({
                'name': img['name'] ?? '',
                'url': ApiConfig.replaceMediaUrl(url),
              });
            }
          }
          _selectedPeriod = _adData!['period_day'] is int
              ? _adData!['period_day'] as int
              : int.tryParse(_adData!['period_day'].toString()) ?? 30;
          if (_adData!['filters'] != null) {
            final filters = _adData!['filters'] as Map<String, dynamic>;
            _selectedFilters = filters.map((key, value) {
              if (value is List) {
                return MapEntry(key, value.map((e) => e.toString()).toList());
              } else {
                return MapEntry(key, [value.toString()]);
              }
            });
          }
          _isLoading = false;
        });
        print('✅ [EditListing] Ad data loaded');
      } else {
        throw Exception(result['error'] ?? 'Failed to load ad');
      }
    } catch (e) {
      print('🔴 [EditListing] Error loading ad: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        showSwipeDownNotification(context, message: 'Ошибка загрузки объявления');
        context.pop();
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
      });
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
        if (result['lat'] != null && result['lon'] != null) {
          _latitude = result['lat'] is double ? result['lat'] : double.tryParse(result['lat'].toString());
          _longitude = result['lon'] is double ? result['lon'] : double.tryParse(result['lon'].toString());
        }
      });
      await _saveLocationToHistory(_cityName!, _cityId!);
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
          initialLat: _latitude,
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
      await _saveLocationToHistory(_cityName!, _cityId!, address: _address, lat: _latitude, lon: _longitude);
    }
  }

  // ── Добавить фото (интеграция с кастомной галереей) ─────────────────────────
  Future<void> _addPhoto() async {
    final totalPhotos = _existingPhotos.length + _newPhotoFiles.length;
    if (totalPhotos >= 30) {
      showSwipeDownNotification(context, message: 'Максимум 30 фотографий');
      return;
    }

    final hasPermission = await PermissionService.requestStoragePermission(context);
    if (!hasPermission) return;

    final selectedFiles = await Navigator.push<List<File>>(
      context,
      MaterialPageRoute(
        builder: (_) => GalleryPickerScreen(
          maxCount: 30 - totalPhotos,
        ),
      ),
    );

    if (selectedFiles != null && selectedFiles.isNotEmpty) {
      setState(() {
        _newPhotoFiles.addAll(selectedFiles);
      });
      print('✅ [EditListing] Added ${selectedFiles.length} new photos');
    }
  }

  // ── Удалить существующее фото ────────────────────────────────────────────────
  void _removeExistingPhoto(int index) {
    setState(() {
      _existingPhotos.removeAt(index);
    });
    print('🔵 [EditListing] Existing photo removed at index $index');
  }

  // ── Удалить новое фото ───────────────────────────────────────────────────────
  void _removeNewPhoto(int index) {
    setState(() {
      _newPhotoFiles.removeAt(index);
    });
    print('🔵 [EditListing] New photo removed at index $index');
  }

  // ── Сохранить телефон ────────────────────────────────────────────────────────
  Future<void> _savePhone() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      showSwipeDownNotification(context, message: 'Введите номер телефона');
      return;
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xff917dfa))),
    );
    try {
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user') as Map?;
      if (token == null || userData == null) throw Exception('Not authorized');
      final userId = userData['id'] is int ? userData['id'] as int : int.parse(userData['id'].toString());
      final result = await _adsApi.savePhone(userId: userId, token: token, phone: phone);
      if (result['status'] == true) {
        final needsVerification = result['verify'] == true;
        if (!mounted) return;
        Navigator.pop(context);
        if (needsVerification) {
          final verificationTitle = result['title'] ?? 'Укажите код из SMS';
          await _showVerificationDialog(phone, verificationTitle, userId, token);
        } else {
          final updatedUserData = Map<String, dynamic>.from(userData);
          updatedUserData['phone'] = phone;
          await box.put('user', updatedUserData);
          var authBloc = context.read<AuthBloc>();
          var currentUser = authBloc.state.user;
          if (currentUser != null) {
            currentUser.phone = phone;
            authBloc.add(UserUpdated(currentUser));
          }
          setState(() => _isEditingPhone = false);
          showSwipeDownNotification(context, message: 'Телефон сохранен');
        }
      } else {
        if (!mounted) return;
        Navigator.pop(context);
        showSwipeDownNotification(context, message: result['error'] ?? 'Ошибка сохранения телефона');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      showSwipeDownNotification(context, message: 'Ошибка сохранения телефона');
    }
  }

  // ── Верификация телефона ─────────────────────────────────────────────────────
  Future<void> _showVerificationDialog(String phone, String title, int userId, String token) async {
    final codeController = TextEditingController();
    await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: GoogleFonts.montserrat(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Введите код',
            filled: true,
            fillColor: const Color(0xff917dfa).withOpacity(0.1),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Отмена', style: GoogleFonts.montserrat(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xff917dfa)),
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.isEmpty) {
                showSwipeDownNotification(context, message: 'Введите код');
                return;
              }
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xff917dfa))),
              );
              try {
                final verifyResult = await _adsApi.verifyPhone(
                  userId: userId, token: token, phone: phone, code: code,
                );
                if (!mounted) return;
                Navigator.pop(ctx); // close progress
                if (verifyResult['status'] == true) {
                  final box = Hive.box('user');
                  final userData = box.get('user') as Map?;
                  if (userData != null) {
                    final updated = Map<String, dynamic>.from(userData);
                    updated['phone'] = phone;
                    await box.put('user', updated);
                  }
                  var authBloc = context.read<AuthBloc>();
                  var user = authBloc.state.user;
                  if (user != null) {
                    user.phone = phone;
                    authBloc.add(UserUpdated(user));
                  }
                  setState(() => _isEditingPhone = false);
                  Navigator.pop(ctx, true);
                  showSwipeDownNotification(context, message: 'Телефон подтвержден');
                } else {
                  showSwipeDownNotification(context, message: verifyResult['error'] ?? 'Ошибка верификации');
                }
              } catch (e) {
                if (mounted) Navigator.pop(ctx);
                showSwipeDownNotification(context, message: 'Ошибка верификации');
              }
            },
            child: Text('Подтвердить', style: GoogleFonts.montserrat(color: Colors.white)),
          ),
        ],
      ),
    );
    codeController.dispose();
  }

  // ── Сохранение изменений ─────────────────────────────────────────────────────
  Future<void> _saveChanges() async {
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
    if (_existingPhotos.isEmpty && _newPhotoFiles.isEmpty) {
      showSwipeDownNotification(context, message: 'Добавьте хотя бы одну фотографию');
      return;
    }
    if (_categoryOptions?['price'] != null && _priceController.text.trim().isEmpty) {
      showSwipeDownNotification(context, message: 'Укажите цену');
      return;
    }
    if (_phoneController.text.trim().isEmpty) {
      showSwipeDownNotification(context, message: 'Укажите номер телефона');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xff917dfa))),
    );

    try {
      final box = Hive.box('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user') as Map?;
      if (token == null || userData == null) throw Exception('Not authorized');
      final userId = userData['id'] is int ? userData['id'] as int : int.parse(userData['id'].toString());

      final allPhotos = <Map<String, String>>[];
      for (var photo in _existingPhotos) {
        allPhotos.add({'name': photo['name']!});
      }

      if (_newPhotoFiles.isNotEmpty) {
        for (int i = 0; i < _newPhotoFiles.length; i++) {
          final file = _newPhotoFiles[i];
          final bytes = await file.readAsBytes();
          final base64Image = base64Encode(bytes);
          final uploadResult = await _adsApi.uploadPhoto(
            userId: userId, token: token, imageBase64: base64Image,
          );
          if (uploadResult['status'] == true) {
            allPhotos.add({'name': uploadResult['name']});
          } else {
            throw Exception('Ошибка загрузки фото ${i + 1}: ${uploadResult['error']}');
          }
        }
      }

      final adData = {
        'cat_id': _categoryId!,
        'title': _titleController.text.trim(),
        'text': _descriptionController.text.trim(),
        'city_id': _cityId!,
        'period': _selectedPeriod,
        'images': jsonEncode(allPhotos),
        if (_priceController.text.isNotEmpty) 'price': double.tryParse(_priceController.text) ?? 0,
        if (_videoController.text.isNotEmpty) 'video': _videoController.text.trim(),
        if (_address != null) 'address': _address!,
        if (_latitude != null) 'lat': _latitude.toString(),
        if (_longitude != null) 'lon': _longitude.toString(),
        if (_phoneController.text.isNotEmpty) 'phone': _phoneController.text.trim(),
        'filters': jsonEncode(_selectedFilters),
      };

      final result = await _adsApi.editAd(
        userId: userId, token: token, adId: widget.adId, adData: adData,
      );

      if (!mounted) return;
      Navigator.pop(context);

      if (result['status'] == true) {
        showSwipeDownNotification(context, message: 'Изменения сохранены!');
        context.pop(true);
      } else {
        showSwipeDownNotification(context, message: result['error'] ?? 'Ошибка сохранения изменений');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      showSwipeDownNotification(context, message: 'Ошибка: $e');
    }
  }

  // ── Виджет селектора ─────────────────────────────────────────────────────────
  Widget _buildSelector({required String label, required String? value, required VoidCallback onTap}) {
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
        decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Expanded(
              child: Text(
                value ?? label,
                style: GoogleFonts.montserrat(fontSize: 15, color: value != null ? textColor : hintColor),
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

    if (_isLoading) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const Center(child: CircularProgressIndicator(color: Color(0xff917dfa))),
      );
    }

    return Scaffold(
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
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Редактирование',
          style: GoogleFonts.montserrat(color: textColor, fontWeight: FontWeight.w600, fontSize: 17),
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
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xff917dfa)),
                  ),
                  Text(
                    '${(_progress * 100).round()}%',
                    style: GoogleFonts.montserrat(fontSize: 10, fontWeight: FontWeight.w700, color: textColor),
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
                  // ── Категория (только для просмотра) ──────────────────
                  _SectionTitle(title: 'Категория'),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      _categoryName ?? '',
                      style: GoogleFonts.montserrat(fontSize: 15, color: textColor),
                    ),
                  ),
                  const SizedBox(height: 8),

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
                                  fontSize: 12, color: isDark ? Colors.white70 : const Color(0xff999999)),
                            ),
                          ),
                      style: GoogleFonts.montserrat(fontSize: 15, color: textColor),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: inputBgColor,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                                fontSize: 12, color: isDark ? Colors.white70 : const Color(0xff999999)),
                          ),
                        ),
                    style: GoogleFonts.montserrat(fontSize: 15, color: textColor),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputBgColor,
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                        border:
                            OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        suffixText: '₽',
                        suffixStyle: GoogleFonts.montserrat(color: textColor),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // ── Номер телефона ────────────────────────────────────
                  _SectionTitle(title: 'Номер телефона *'),
                  const SizedBox(height: 4),
                  Text(
                    'Для публикации объявления необходимо указать номер телефона. Скрыть его или изменить Вы сможете в настройках профиля.',
                    style: GoogleFonts.montserrat(
                        fontSize: 13, color: isDark ? Colors.white70 : const Color(0xff999999), height: 1.4),
                  ),
                  const SizedBox(height: 8),
                  if (_phoneController.text.isEmpty || _isEditingPhone) ...[
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
                                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            hintText: '+7 (___) ___-__-__',
                            hintStyle: GoogleFonts.montserrat(
                                color: isDark ? Colors.white54 : const Color(0xff999999)),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _savePhone,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xff917dfa),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text('Сохранить',
                              style: GoogleFonts.montserrat(
                                  fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ],
                    ),
                  ] else ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(12)),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _phoneController.text.isNotEmpty ? _phoneController.text : 'Телефон не указан',
                              style: GoogleFonts.montserrat(fontSize: 15, color: textColor),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(() => _isEditingPhone = true),
                            child: Text('Изменить',
                                style: GoogleFonts.montserrat(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xff917dfa))),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),

                  // ── Фильтры ───────────────────────────────────────────
                  if (_categoryOptions?['filters'] != null) ...[
                    for (var filter in _categoryOptions!['filters']) ...[
                      _SectionTitle(title: filter['name'] + (filter['required'] == true ? ' *' : '')),
                      const SizedBox(height: 10),
                      if (filter['view'] == 'select') ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(12)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedFilters[filter['id'].toString()]?.firstOrNull,
                              hint: Text('Выберите ${filter['name'].toLowerCase()}',
                                  style: GoogleFonts.montserrat(
                                      fontSize: 15, color: isDark ? Colors.white54 : const Color(0xff999999))),
                              isExpanded: true,
                              dropdownColor: inputBgColor,
                              style: GoogleFonts.montserrat(fontSize: 15, color: textColor),
                              items: (filter['items'] as List).map<DropdownMenuItem<String>>((item) {
                                return DropdownMenuItem<String>(
                                  value: item['id'].toString(),
                                  child: Text(item['name'],
                                      style: GoogleFonts.montserrat(fontSize: 15, color: textColor)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedFilters[filter['id'].toString()] = [value]);
                                }
                              },
                            ),
                          ),
                        ),
                      ] else if (filter['view'] == 'checkbox') ...[
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
                                  if (!_selectedFilters.containsKey(filterId)) _selectedFilters[filterId] = [];
                                  if (isSelected) {
                                    _selectedFilters[filterId]!.remove(itemId);
                                  } else {
                                    _selectedFilters[filterId]!.add(itemId);
                                  }
                                });
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xff917dfa) : const Color(0xFFF0F4F8),
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
                        TextField(
                          controller: TextEditingController(
                              text: _selectedFilters[filter['id'].toString()]?.firstOrNull ?? ''),
                          onChanged: (value) =>
                              setState(() => _selectedFilters[filter['id'].toString()] = [value]),
                          style: GoogleFonts.montserrat(fontSize: 15, color: textColor),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: inputBgColor,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            hintText: 'Введите ${filter['name'].toLowerCase()}',
                            hintStyle: GoogleFonts.montserrat(
                                color: isDark ? Colors.white54 : const Color(0xff999999)),
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
                    'Первое фото будет отображаться в результатах поиска',
                    style: GoogleFonts.montserrat(
                        fontSize: 13, color: isDark ? Colors.white70 : const Color(0xff999999), height: 1.4),
                  ),
                  const SizedBox(height: 10),

                  if (_existingPhotos.isNotEmpty || _newPhotoFiles.isNotEmpty) ...[
                    SizedBox(
                      height: 90,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _existingPhotos.length + _newPhotoFiles.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final isExisting = index < _existingPhotos.length;
                          return SizedBox(
                            width: 90,
                            height: 90,
                            child: Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: isExisting
                                      ? Image.network(
                                          ApiConfig.replaceMediaUrl(_existingPhotos[index]['url']!),
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                        )
                                      : Image.file(
                                          _newPhotoFiles[index - _existingPhotos.length],
                                          width: 90,
                                          height: 90,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                                // Водяной знак на всех фото (прозрачность 0.29)
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
                                    onTap: () {
                                      if (isExisting) {
                                        _removeExistingPhoto(index);
                                      } else {
                                        _removeNewPhoto(index - _existingPhotos.length);
                                      }
                                    },
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 14),
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
                    onTap: (_existingPhotos.length + _newPhotoFiles.length) < 30 ? _addPhoto : null,
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
                          const Icon(Icons.image_outlined, color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          Text(
                            'Добавить фото',
                            style: GoogleFonts.montserrat(
                                fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white),
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
                        fontSize: 13, color: isDark ? Colors.white70 : const Color(0xff999999)),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _videoController,
                    style: GoogleFonts.montserrat(fontSize: 15, color: textColor),
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: inputBgColor,
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Местоположение ────────────────────────────────────
                  _SectionTitle(title: 'Местоположение'),
                  const SizedBox(height: 10),

                  if (_getLocationHistory().isNotEmpty) ...[
                    GestureDetector(
                      onTap: _showLocationHistory,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xff917dfa).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xff917dfa).withOpacity(0.3), width: 1),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.history, color: Color(0xff917dfa), size: 20),
                            const SizedBox(width: 10),
                            Text('Выбрать из истории',
                                style: GoogleFonts.montserrat(
                                    fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xff917dfa))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  _buildSelector(label: 'Город', value: _cityName, onTap: _pickCity),
                  const SizedBox(height: 10),
                  _buildSelector(
                    label: 'Указать адрес',
                    value: _address ??
                        (_latitude != null && _longitude != null
                            ? '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
                            : null),
                    onTap: _pickAddress,
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── Кнопка «Сохранить изменения» ────────────────────────────
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
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xff917dfa),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  elevation: 0,
                ),
                child: Text(
                  'Сохранить изменения',
                  style: GoogleFonts.montserrat(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
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