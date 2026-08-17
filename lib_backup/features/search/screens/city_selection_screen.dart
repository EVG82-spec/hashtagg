import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/core/network/geo_api_repository.dart';

/// Двухуровневый экран выбора города
/// Уровень 1: Выбор края/региона
/// Уровень 2: Выбор города в выбранном крае
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
  
  // Уровень 1: Регионы
  List<Map<String, dynamic>> _regions = [];
  bool _isLoadingRegions = true;
  
  // Уровень 2: Города
  List<Map<String, dynamic>> _cities = [];
  bool _isLoadingCities = false;
  int? _selectedRegionId;
  String? _selectedRegionName;
  
  // Выбранный город
  int? _selectedCityId;
  String? _selectedCityName;
  String? _selectedDeclination;
  double? _selectedLat;
  double? _selectedLon;
  
  // Поиск
  final TextEditingController _searchController = TextEditingController();
  
  // Текущий уровень: 'regions' или 'cities'
  String _currentLevel = 'regions';

  @override
  void initState() {
    super.initState();
    _selectedCityId = widget.selectedCityId;
    _selectedCityName = widget.selectedCity;
    _loadRegions();
  }

  Future<void> _loadRegions() async {
    setState(() => _isLoadingRegions = true);
    
    try {
      final result = await _geoApi.getRegions();
      
      if (result['status'] == true) {
        final data = result['data'] as List;
        setState(() {
          _regions = data.cast<Map<String, dynamic>>();
          _isLoadingRegions = false;
        });
      } else {
        throw Exception(result['error'] ?? 'Failed to load regions');
      }
    } catch (e) {
      print('🔴 [CitySelection] Error loading regions: $e');
      setState(() => _isLoadingRegions = false);
    }
  }

  Future<void> _loadCitiesByRegion(int regionId) async {
    setState(() {
      _isLoadingCities = true;
      _currentLevel = 'cities';
    });
    
    try {
      final result = await _geoApi.getCitiesByRegion(regionId: regionId);
      
      if (result['status'] == true) {
        final data = result['data'] as List;
        setState(() {
          _cities = data.cast<Map<String, dynamic>>();
          _isLoadingCities = false;
        });
      } else {
        throw Exception(result['error'] ?? 'Failed to load cities');
      }
    } catch (e) {
      print('🔴 [CitySelection] Error loading cities: $e');
      setState(() => _isLoadingCities = false);
    }
  }

  Future<void> _loadAllCities() async {
    setState(() {
      _isLoadingCities = true;
      _currentLevel = 'cities';
      _selectedRegionId = null;
      _selectedRegionName = 'Все города';
    });
    
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
          _isLoadingCities = false;
        });
      } else {
        throw Exception(result['error'] ?? 'Failed to load cities');
      }
    } catch (e) {
      print('🔴 [CitySelection] Error loading all cities: $e');
      setState(() => _isLoadingCities = false);
    }
  }

  void _goBackToRegions() {
    setState(() {
      _currentLevel = 'regions';
      _selectedRegionId = null;
      _selectedRegionName = null;
      _cities.clear();
      _searchController.clear();
    });
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
          onPressed: () {
            if (_currentLevel == 'cities') {
              _goBackToRegions();
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Text(
          _currentLevel == 'regions' ? 'Выбор края' : 'Выбор города',
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
      body: _currentLevel == 'regions' 
          ? _buildRegionsList()
          : _buildCitiesList(),
    );
  }

  Widget _buildRegionsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputBgColor = isDark ? const Color(0xff233040) : const Color(0xFFF5F7FA);
    
    if (_isLoadingRegions) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xff917dfa)),
      );
    }
    
    // Фильтруем регионы по поиску
    final filteredRegions = _regions.where((region) {
      final regionName = (region['region_name'] ?? '').toString().toLowerCase();
      final query = _searchController.text.toLowerCase();
      return query.isEmpty || regionName.contains(query);
    }).toList();
    
    return Column(
      children: [
        // Поле поиска
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {}); // Обновляем список при вводе
            },
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: textColor,
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: inputBgColor,
              hintText: 'Поиск края',
              hintStyle: GoogleFonts.montserrat(
                fontSize: 14,
                color: isDark ? Colors.white54 : const Color(0xff999999),
              ),
              prefixIcon: Icon(
                Icons.search,
                color: isDark ? Colors.white54 : const Color(0xff999999),
                size: 20,
              ),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white54 : const Color(0xff999999),
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
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
        
        // Список регионов
        Expanded(
          child: ListView.builder(
            itemCount: filteredRegions.length,
            itemBuilder: (context, index) {
              final region = filteredRegions[index];
              final regionId = region['region_id'];
              final regionName = region['region_name'] ?? '';
              final isAllCities = regionId == 'all';
              
              return ListTile(
                title: Text(
                  regionName,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                trailing: Icon(
                  Icons.chevron_right,
                  color: isDark ? Colors.white54 : Colors.black54,
                ),
                onTap: () {
                  setState(() {
                    _selectedRegionId = isAllCities ? null : _parseInt(regionId);
                    _selectedRegionName = regionName;
                  });
                  
                  if (isAllCities) {
                    _loadAllCities();
                  } else {
                    _loadCitiesByRegion(_parseInt(regionId));
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCitiesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputBgColor = isDark ? const Color(0xff233040) : const Color(0xFFF5F7FA);
    
    if (_isLoadingCities) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xff917dfa)),
      );
    }
    
    // Фильтруем города по поиску
    final filteredCities = _cities.where((city) {
      final cityName = (city['city_name'] ?? city['geo_name'] ?? '').toString().toLowerCase();
      final query = _searchController.text.toLowerCase();
      return query.isEmpty || cityName.contains(query);
    }).toList();
    
    return Column(
      children: [
        // Поле поиска
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {}); // Обновляем список при вводе
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
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white54 : const Color(0xff999999),
                        size: 18,
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {});
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
        
        // Список городов
        Expanded(
          child: filteredCities.isEmpty
              ? Center(
                  child: Text(
                    'Ничего не найдено',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredCities.length,
                  itemBuilder: (context, index) {
                    final city = filteredCities[index];
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
                        _apply();
                      },
                    );
                  },
                ),
        ),
      ],
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
