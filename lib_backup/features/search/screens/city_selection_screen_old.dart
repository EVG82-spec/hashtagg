import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/core/network/geo_api_repository.dart';

/// Экран выбора города или региона
/// Структура:
/// 1. Надпись "Город или Регион"
/// 2. Селект города или региона
/// 3. Кнопка "Применить" в стиле настроек
class CitySelectionScreen extends StatefulWidget {
  final int? selectedCityId;
  final String? selectedCity;

  const CitySelectionScreen({
    super.key,
    this.selectedCityId,
    this.selectedCity,
  });

  @override
  State<CitySelectionScreen> createState() => _CitySelectionScreenState();
}

class _CitySelectionScreenState extends State<CitySelectionScreen> {
  final GeoApiRepository _geoApi = GeoApiRepository();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _cities = [];
  bool _isLoading = true;
  int? _selectedCityId;
  String? _selectedCityName;
  String? _selectedDeclination;
  double? _selectedLat;
  double? _selectedLon;

  @override
  void initState() {
    super.initState();
    _selectedCityId = widget.selectedCityId;
    _selectedCityName = widget.selectedCity;
    _loadCities();
  }

  Future<void> _loadCities() async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _geoApi.searchCities(
        query: '',
        onlyCity: true,
        allCities: true,
      );
      
      if (result['status'] == true) {
        final data = result['data'] as List;
        setState(() {
          _cities = data.cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      } else {
        throw Exception(result['error'] ?? 'Failed to load cities');
      }
    } catch (e) {
      print('🔴 [CitySelection] Error loading cities: $e');
      setState(() => _isLoading = false);
    }
  }

  void _apply() {
    Navigator.pop(context, {
      'id': _selectedCityId,
      'name': _selectedCityName,
      'declination': _selectedDeclination,
      'lat': _selectedLat,
      'lon': _selectedLon,
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff151e27) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Выбор города',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: bgColor,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xff917dfa)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Надпись "Город или Регион"
                  Text(
                    'Город или Регион',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // 2. Селект города или региона
                  GestureDetector(
                    onTap: () => _showCityPicker(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? const Color(0xff233040) 
                            : const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _selectedCityName ?? 'Все города',
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: textColor,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down,
                            color: isDark ? Colors.white54 : Colors.black54,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // 3. Кнопка "Применить" с таким же отступом
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _apply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xff917dfa),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        'Применить',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _showCityPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff233040) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputBgColor = isDark ? const Color(0xff151e27) : const Color(0xFFF5F7FA);
    
    // Локальный контроллер для поиска в модалке
    final searchController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Фильтруем города по поисковому запросу
            final filteredCities = _cities.where((city) {
              final cityName = (city['city_name'] ?? city['geo_name'] ?? '').toString().toLowerCase();
              final query = searchController.text.toLowerCase();
              return query.isEmpty || cityName.contains(query);
            }).toList();
            
            return DraggableScrollableSheet(
              initialChildSize: 0.7,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollController) {
                return SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Выберите город',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Поле поиска
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          controller: searchController,
                          onChanged: (value) {
                            setModalState(() {}); // Обновляем список при вводе
                          },
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: textColor,
                          ),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: inputBgColor,
                            hintText: 'Поиск города',
                            hintStyle: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: isDark ? Colors.white54 : const Color(0xff999999),
                            ),
                            prefixIcon: Icon(
                              Icons.search,
                              color: isDark ? Colors.white54 : const Color(0xff999999),
                              size: 20,
                            ),
                            suffixIcon: searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: isDark ? Colors.white54 : const Color(0xff999999),
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      searchController.clear();
                                      setModalState(() {});
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      Expanded(
                        child: ListView(
                          controller: scrollController,
                          children: [
                            // "Все города"
                            ListTile(
                              title: Text(
                                'Все города',
                                style: GoogleFonts.montserrat(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                            trailing: _selectedCityId == null
                                ? const Icon(Icons.check, color: Color(0xff917dfa))
                                : null,
                            onTap: () {
                              setState(() {
                                _selectedCityId = null;
                                _selectedCityName = null;
                                _selectedDeclination = null;
                                _selectedLat = null;
                                _selectedLon = null;
                              });
                              Navigator.pop(ctx);
                            },
                          ),
                          const Divider(height: 1),
                          
                          // Отфильтрованные города
                          if (filteredCities.isEmpty && searchController.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Center(
                                child: Text(
                                  'Ничего не найдено',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            )
                          else
                            ...filteredCities.map((city) {
                              final cityId = _parseInt(city['city_id']);
                              final cityName = city['city_name'] ?? city['geo_name'] ?? '';
                              final declination = city['declination'] ?? '';
                              final region = city['region_name'] ?? '';
                              final country = city['country_name'] ?? '';
                              final lat = _parseDouble(city['lat']);
                              final lon = _parseDouble(city['lon']);
                              
                              return ListTile(
                                title: Text(
                                  cityName,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: textColor,
                                  ),
                                ),
                                subtitle: region.isNotEmpty
                                    ? Text(
                                        '$region, $country',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          color: isDark ? Colors.white70 : const Color(0xff808080),
                                        ),
                                      )
                                    : null,
                                trailing: _selectedCityId == cityId
                                    ? const Icon(Icons.check, color: Color(0xff917dfa))
                                    : null,
                                onTap: () {
                                  setState(() {
                                    _selectedCityId = cityId;
                                    _selectedCityName = cityName;
                                    _selectedDeclination = declination;
                                    _selectedLat = lat;
                                    _selectedLon = lon;
                                  });
                                  Navigator.pop(ctx);
                                },
                              );
                            }),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
