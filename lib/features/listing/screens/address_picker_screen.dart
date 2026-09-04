import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:hashtagg/core/network/geo_api_repository.dart';
import 'package:hashtagg/core/services/permission_service.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'dart:typed_data';
import 'dart:ui' as ui;

/// Экран выбора точного адреса на карте Яндекс.
/// Возвращает Map с адресом и координатами через Navigator.pop.
class AddressPickerScreen extends StatefulWidget {
  final String city;
  final int? cityId;
  final double? initialLat;
  final double? initialLon;

  const AddressPickerScreen({
    super.key,
    required this.city,
    this.cityId,
    this.initialLat,
    this.initialLon,
  });

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  late YandexMapController _mapController;
  final GeoApiRepository _geoApi = GeoApiRepository();
  final TextEditingController _searchController = TextEditingController();

  // Координаты выбранной точки
  Point? _selectedPoint;
  String? _selectedAddress;
  bool _isLoading = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  Uint8List? _markerIconBytes;

  // Дефолтные центры городов (заглушка, в реальности — геокодинг по городу)
  static const _cityCoords = <String, Point>{
    'Москва': Point(latitude: 55.7558, longitude: 37.6173),
    'Санкт-Петербург': Point(latitude: 59.9343, longitude: 30.3351),
    'Казань': Point(latitude: 55.7963, longitude: 49.1088),
    'Екатеринбург': Point(latitude: 56.8389, longitude: 60.6057),
    'Новосибирск': Point(latitude: 54.9884, longitude: 82.9357),
    'Краснодар': Point(latitude: 45.0353, longitude: 38.9754),
    'Воронеж': Point(latitude: 51.6720, longitude: 39.1843),
    'Нижний Новгород': Point(latitude: 56.2965, longitude: 43.9361),
    'Калининград': Point(latitude: 54.7104, longitude: 20.4522),
    'Омск': Point(latitude: 54.9885, longitude: 73.3242),
    'Самара': Point(latitude: 53.2001, longitude: 50.1500),
    'Ростов-на-Дону': Point(latitude: 47.2357, longitude: 39.7015),
    'Пермь': Point(latitude: 58.0105, longitude: 56.2502),
    'Пенза': Point(latitude: 53.2007, longitude: 45.0046),
    'Иркутск': Point(latitude: 52.2855, longitude: 104.2890),
    'Челябинск': Point(latitude: 55.1644, longitude: 61.4368),
    'Уфа': Point(latitude: 54.7388, longitude: 55.9721),
    'Красноярск': Point(latitude: 56.0184, longitude: 92.8672),
    'Тюмень': Point(latitude: 57.1522, longitude: 65.5272),
    'Барнаул': Point(latitude: 53.3606, longitude: 83.7636),
    'Хабаровск': Point(latitude: 48.4827, longitude: 135.0840),
    'Алматы': Point(latitude: 43.2220, longitude: 76.8512),
    'Астана': Point(latitude: 51.1801, longitude: 71.4460),
    'Тбилиси': Point(latitude: 41.6938, longitude: 44.8015),
    'Минск': Point(latitude: 53.9045, longitude: 27.5615),
  };

  static const _defaultPoint = Point(latitude: 55.7558, longitude: 37.6173);

  Point get _cityCenter {
    if (widget.initialLat != null && widget.initialLon != null) {
      return Point(latitude: widget.initialLat!, longitude: widget.initialLon!);
    }
    // Оставляем статический словарь как fallback (можно и вовсе убрать)
    return _cityCoords[widget.city] ?? _defaultPoint;
  }

  // Список объектов карты (маркер выбранной точки)
  List<MapObject> get _mapObjects {
    if (_selectedPoint == null) return [];
    return [
      PlacemarkMapObject(
        mapId: const MapObjectId('selected_point'),
        point: _selectedPoint!,
        opacity: 1,
        icon: PlacemarkIcon.single(
          PlacemarkIconStyle(
            image: _markerIconBytes != null
                ? BitmapDescriptor.fromBytes(_markerIconBytes!)
                : BitmapDescriptor.fromAssetImage(
                    'assets/location.png',
                  ), // fallback
            scale: 1.0,
            anchor: const Offset(0.5, 1.0),
          ),
        ),
      ),
    ];
  }

  Future<void> _loadMarkerIcon() async {
    _markerIconBytes = await _svgToPngBytes(
      'assets/location.svg',
      color: const Color(0xff917dfa),
    );
    if (mounted) setState(() {});
  }

  Future<Uint8List> _svgToPngBytes(
    String assetPath, {
    double width = 96,
    double height = 96,
    Color? color,
  }) async {
    final String rawSvg = await rootBundle.loadString(assetPath);
    final PictureInfo pictureInfo = await vg.loadPicture(
      SvgStringLoader(rawSvg),
      null,
    );

    final double svgWidth = pictureInfo.size.width;
    final double svgHeight = pictureInfo.size.height;

    final double scaleX = width / svgWidth;
    final double scaleY = height / svgHeight;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    final double renderWidth = svgWidth * scale;
    final double renderHeight = svgHeight * scale;

    final double offsetX = (width - renderWidth) / 2.0;
    final double offsetY = (height - renderHeight) / 2.0;

    // 1. Рендерим SVG в ui.Image без цвета
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.translate(offsetX, offsetY);
    canvas.scale(scale);
    canvas.drawPicture(pictureInfo.picture);
    final ui.Image svgImage = await recorder.endRecording().toImage(
      width.toInt(),
      height.toInt(),
    );

    // 2. Если задан цвет – накладываем его через ColorFilter
    if (color != null) {
      final coloredRecorder = ui.PictureRecorder();
      final coloredCanvas = Canvas(
        coloredRecorder,
        Rect.fromLTWH(0, 0, width, height),
      );
      final paint = Paint()
        ..colorFilter = ColorFilter.mode(color, BlendMode.srcIn);
      coloredCanvas.drawImage(svgImage, Offset.zero, paint);
      svgImage.dispose(); // освободим оригинал
      final coloredImage = await coloredRecorder.endRecording().toImage(
        width.toInt(),
        height.toInt(),
      );
      final byteData = await coloredImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      coloredImage.dispose();
      pictureInfo.picture.dispose();
      return byteData!.buffer.asUint8List();
    } else {
      final byteData = await svgImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      svgImage.dispose();
      pictureInfo.picture.dispose();
      return byteData!.buffer.asUint8List();
    }
  }

  Future<void> _searchAddress(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      final result = await _geoApi.searchAddress(
        query: query,
        cityId: widget.cityId,
      );

      if (result['status'] == true) {
        setState(() {
          _searchResults = List<Map<String, dynamic>>.from(result['data']);
          _isSearching = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    } catch (e) {
      print('🔴 [AddressPicker] Search error: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final lat = double.tryParse(result['lat'].toString());
    final lon = double.tryParse(result['lon'].toString());

    if (lat != null && lon != null) {
      final point = Point(latitude: lat, longitude: lon);

      setState(() {
        _selectedPoint = point;
        _selectedAddress = result['address'];
        _searchResults = [];
        _searchController.clear();
      });

      // Перемещаем камеру к выбранной точке
      _mapController.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: point, zoom: 17.0),
        ),
      );
    }
  }

  Future<void> _onMapTap(Point point) async {
    setState(() {
      _selectedPoint = point;
      _isLoading = true;
      _selectedAddress = null;
    });

    try {
      final result = await _geoApi.reverseGeocode(
        lat: point.latitude,
        lon: point.longitude,
      );

      if (result['status'] == true && result['address'] != null) {
        setState(() {
          _selectedAddress = result['address'] as String;
          _isLoading = false;
        });
      } else {
        // Адрес не получен – подставляем координаты
        setState(() {
          _selectedAddress =
              '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
          _isLoading = false;
        });
      }
    } catch (e) {
      print('🔴 [AddressPicker] Reverse geocode error: $e');
      setState(() {
        _selectedAddress =
            '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';
        _isLoading = false;
      });
    }
  }

  void _confirm() {
    if (_selectedAddress != null && _selectedPoint != null) {
      Navigator.pop(context, {
        'address': _selectedAddress!,
        'lat': _selectedPoint!.latitude,
        'lon': _selectedPoint!.longitude,
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadMarkerIcon();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.city,
          style: GoogleFonts.montserrat(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        actions: [
          if (_selectedAddress != null && !_isLoading)
            TextButton(
              onPressed: _confirm,
              child: Text(
                'Готово',
                style: GoogleFonts.montserrat(
                  color: const Color(0xff917dfa),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Яндекс карта ────────────────────────────────────────────────
          Positioned.fill(
            child: YandexMap(
              mapObjects: _mapObjects,
              nightModeEnabled: false,
              onMapCreated: (controller) async {
                _mapController = controller;
                await _mapController.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: _cityCenter, zoom: 13.0),
                  ),
                );
              },
              onMapTap: _onMapTap,
            ),
          ),

          // ── Поиск адреса ─────────────────────────────────────────────────
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.hardEdge,
                  child: TextField(
                    controller: _searchController,
                    onChanged: _searchAddress,
                    style: GoogleFonts.montserrat(fontSize: 15),
                    decoration: InputDecoration(
                      hintText: 'Поиск адреса...',
                      hintStyle: GoogleFonts.montserrat(
                        color: const Color(0xff999999),
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Color(0xff917dfa),
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 20),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {
                                  _searchResults = [];
                                });
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),

                // Результаты поиска
                if (_searchResults.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 300),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _searchResults.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final result = _searchResults[index];
                        return ListTile(
                          leading: const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xff917dfa),
                          ),
                          title: Text(
                            result['address'],
                            style: GoogleFonts.montserrat(fontSize: 14),
                          ),
                          onTap: () => _selectSearchResult(result),
                        );
                      },
                    ),
                  ),
                ],

                if (_isSearching)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xff917dfa),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Подсказка ─────────────────────────────────────────────────────
          if (_selectedPoint == null && _searchResults.isEmpty && !_isSearching)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.touch_app_outlined,
                      color: Color(0xff917dfa),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Найдите адрес или нажмите на карту',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Карточка выбранного адреса снизу ─────────────────────────────
          if (_selectedPoint != null)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          color: Color(0xff917dfa),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Выбранное место',
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: const Color(0xff999999),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (_isLoading)
                      const SizedBox(
                        height: 20,
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xff917dfa),
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        _selectedAddress ?? '',
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.black,
                        ),
                      ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _confirm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff917dfa),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          'Выбрать это место',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
