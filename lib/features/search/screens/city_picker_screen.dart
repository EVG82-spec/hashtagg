// G:\hashtagg_app\lib\features\search\screens\city_picker_screen.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/core/network/geo_api_repository.dart';
import 'package:hashtagg/core/network/categories_api_repository.dart';

class CityModel {
  final int id;
  final String name;
  final String region;
  final String country;
  final double? lat;
  final double? lon;
  final String? declination;

  const CityModel({
    required this.id,
    required this.name,
    required this.region,
    required this.country,
    this.lat,
    this.lon,
    this.declination,
  });

  factory CityModel.fromJson(Map<String, dynamic> json) {
    return CityModel(
      id: _parseInt(json['city_id']),
      name: json['city_name'] ?? json['geo_name'] ?? '',
      region: json['region_name'] ?? '',
      country: json['country_name'] ?? '',
      lat: _parseDouble(json['lat']),
      lon: _parseDouble(json['lon']),
      declination: json['declination'] as String?,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double? _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

/// Режим работы экрана выбора города
enum CityPickerMode {
  /// Режим поиска/фильтра - плоский список всех городов с фильтром по стране
  search,

  /// Режим выбора города (для объявлений) - двухуровневый (Край → Город)
  picker,
}

class CityPickerScreen extends StatefulWidget {
  final int? selectedCityId;
  final String? selectedCity;
  final bool returnId;
  final CityPickerMode mode;

  const CityPickerScreen({
    super.key,
    this.selectedCityId,
    this.selectedCity,
    this.returnId = false,
    this.mode = CityPickerMode.search,
  });

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  final GeoApiRepository _geoApi = GeoApiRepository();
  final TextEditingController _searchController = TextEditingController();

  // ---- Режим поиска (search) ----
  List<CityModel> _cities = [];
  List<CityModel> _allCities = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedCountry;

  // ---- Режим выбора города (picker) ----
  List<Map<String, dynamic>> _regions = [];
  List<Map<String, dynamic>> _citiesByRegion = [];
  int? _selectedRegionId;
  String? _selectedRegionName;
  bool _isLoadingRegions = true;
  bool _isLoadingCities = false;
  String _currentLevel = 'regions'; // 'regions' или 'cities'

  // ---- Общее ----
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  final CategoriesApiRepository _categoriesApi = CategoriesApiRepository();

  // Выбранный город
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

    if (widget.mode == CityPickerMode.search) {
      _loadCities();
    } else {
      _loadRegions();
    }
  }

  // ============================================================
  // РЕЖИМ ПОИСКА (search)
  // ============================================================

  Future<void> _loadCities({String query = ''}) async {
    setState(() => _isLoading = true);

    try {
      final result = await _geoApi.searchCities(
        query: query,
        onlyCity: true,
        allCities: query.isEmpty,
      );

      if (result['status'] == true) {
        final data = result['data'] as List;
        final cities = data.map((json) => CityModel.fromJson(json)).toList();

        setState(() {
          _allCities = cities;
          _applyCountryFilter();
          _isLoading = false;
        });
        print('✅ [CityPicker] Loaded ${_allCities.length} cities');
      } else {
        throw Exception(result['error'] ?? 'Failed to load cities');
      }
    } catch (e) {
      print('🔴 [CityPicker] Error loading cities: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка загрузки городов: $e')));
      }
    }
  }

  void _applyCountryFilter() {
    if (_selectedCountry == null) {
      _cities = _allCities;
    } else {
      _cities = _allCities
          .where((city) => city.country == _selectedCountry)
          .toList();
    }
  }

  List<String> _getAvailableCountries() {
    final countries = _allCities.map((city) => city.country).toSet().toList();
    countries.sort();
    return countries;
  }

  // ============================================================
  // РЕЖИМ ВЫБОРА ГОРОДА (picker)
  // ============================================================

  Future<void> _loadRegions() async {
    setState(() => _isLoadingRegions = true);

    try {
      final result = await _geoApi.getRegions();

      if (result['status'] == true) {
        final data = result['data'] as List;

        // 👇 ДОБАВЬТЕ ЭТОТ ЛОГ
        print('🔍 [CityPicker] ===== ВСЕ РЕГИОНЫ =====');
        for (var region in data) {
          print(
            '  ID: ${region['region_id']}, Название: ${region['region_name']}',
          );
        }
        print('🔍 [CityPicker] =========================');

        setState(() {
          _regions = data.cast<Map<String, dynamic>>();
          _isLoadingRegions = false;
        });
      } else {
        throw Exception(result['error'] ?? 'Failed to load regions');
      }
    } catch (e) {
      print('🔴 [CityPicker] Error loading regions: $e');
      setState(() => _isLoadingRegions = false);
    }
  }

  Future<void> _loadCitiesByRegion(int regionId) async {
    setState(() {
      _isLoadingCities = true;
      _currentLevel = 'cities';
      _selectedRegionId = regionId;
    });

    try {
      final result = await _geoApi.getCitiesByRegion(regionId: regionId);

      if (result['status'] == true) {
        final data = result['data'] as List;

        // Сортируем города: главный город края первым
        final sortedCities = _sortCitiesByRegion(
          data.cast<Map<String, dynamic>>(),
          regionId,
        );

        setState(() {
          _citiesByRegion = sortedCities;
          _isLoadingCities = false;
        });
        print(
          '✅ [CityPicker] Loaded ${_citiesByRegion.length} cities for region $regionId',
        );
      } else {
        throw Exception(result['error'] ?? 'Failed to load cities');
      }
    } catch (e) {
      print('🔴 [CityPicker] Error loading cities: $e');
      setState(() => _isLoadingCities = false);
    }
  }

  /// Сортировка городов: главный город края первым
  List<Map<String, dynamic>> _sortCitiesByRegion(
    List<Map<String, dynamic>> cities,
    int regionId,
  ) {
    // Список главных городов для краев по ID городов
    final mainCityIds = {
      55: [732], // Приморский Край → Владивосток (ID: 732)
      78: [1040], // Хабаровский Край → Хабаровск (ID: 1040)
    };

    // Получаем список ID главных городов для этого региона
    final mainIds = mainCityIds[regionId] ?? [];

    // Разделяем на главный город и остальные
    List<Map<String, dynamic>> mainCitiesList = [];
    List<Map<String, dynamic>> otherCities = [];

    for (var city in cities) {
      final cityId = _parseInt(city['city_id']);

      // Проверяем, является ли город главным по ID
      if (mainIds.contains(cityId)) {
        mainCitiesList.add(city);
        print(
          '✅ [CityPicker] Main city found: ${city['city_name']} (ID: $cityId)',
        );
      } else {
        otherCities.add(city);
      }
    }

    // Сортируем остальные города по алфавиту
    otherCities.sort((a, b) {
      final nameA = (a['city_name'] ?? a['geo_name'] ?? '')
          .toString()
          .toLowerCase();
      final nameB = (b['city_name'] ?? b['geo_name'] ?? '')
          .toString()
          .toLowerCase();
      return nameA.compareTo(nameB);
    });

    final result = [...mainCitiesList, ...otherCities];

    // Логируем результат
    print('🔍 [CityPicker] First 5 cities after sorting:');
    for (int i = 0; i < (result.length > 5 ? 5 : result.length); i++) {
      final city = result[i];
      final name = city['city_name'] ?? city['geo_name'] ?? 'unknown';
      final id = city['city_id'];
      print('  ${i + 1}. $name (ID: $id)');
    }

    return result;
  }

  void _goBackToRegions() {
    setState(() {
      _currentLevel = 'regions';
      _selectedRegionId = null;
      _selectedRegionName = null;
      _citiesByRegion.clear();
      _searchController.clear();
    });
  }

  // ============================================================
  // ОБЩЕЕ
  // ============================================================

  void _onSearchChanged(String query) async {
    if (widget.mode == CityPickerMode.search) {
      // Режим поиска - фильтруем города
      setState(() {
        _searchQuery = query;
      });
      await _loadCities(query: query);
      return;
    }

    // Режим выбора города - поиск по регионам
    // Просто фильтруем список, без API запроса
    setState(() {
      _searchQuery = query;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == CityPickerMode.search) {
      return _buildSearchMode();
    } else {
      return _buildPickerMode();
    }
  }

  // ============================================================
  // ПОСТРОЕНИЕ РЕЖИМА ПОИСКА
  // ============================================================

  Widget _buildSearchMode() {
    final countries = _getAvailableCountries();
    final showTabs = _allCities.isNotEmpty && countries.length > 1;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff151e27) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputBgColor = isDark
        ? const Color(0xff233040)
        : const Color(0xFFF5F7FA);

    return DefaultTabController(
      length: showTabs ? countries.length + 1 : 1,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: SizedBox(
            height: 40,
            child: TextField(
              controller: _searchController,
              autofocus: false,
              onChanged: _onSearchChanged,
              style: GoogleFonts.montserrat(fontSize: 14, color: textColor),
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
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.close,
                          color: isDark
                              ? Colors.white54
                              : const Color(0xff999999),
                          size: 18,
                        ),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          bottom: showTabs
              ? TabBar(
                  isScrollable: true,
                  indicatorColor: const Color(0xff917dfa),
                  labelColor: const Color(0xff917dfa),
                  unselectedLabelColor: isDark ? Colors.white70 : Colors.grey,
                  labelStyle: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelStyle: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  onTap: (index) {
                    setState(() {
                      if (index == 0) {
                        _selectedCountry = null;
                      } else {
                        _selectedCountry = countries[index - 1];
                      }
                      _applyCountryFilter();
                    });
                  },
                  tabs: [
                    const Tab(text: 'Все'),
                    ...countries.map((country) => Tab(text: country)),
                  ],
                )
              : null,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xff917dfa)),
              )
            : _buildSearchCityList(),
      ),
    );
  }

  Widget _buildSearchCityList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white70 : const Color(0xff808080);

    if (_cities.isEmpty) {
      return Center(
        child: Text(
          _searchQuery.isEmpty
              ? 'Города не найдены'
              : 'Ничего не найдено по запросу "$_searchQuery"',
          style: GoogleFonts.montserrat(fontSize: 16, color: Colors.grey),
        ),
      );
    }

    return ListView(
      children: [
        // "All cities" option
        ListTile(
          title: Text(
            'Все города',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
          trailing: widget.selectedCity == null && widget.selectedCityId == null
              ? const Icon(Icons.check, color: Color(0xff917dfa))
              : null,
          onTap: () {
            if (widget.returnId) {
              Navigator.pop(context, {
                'id': 0,
                'name': 'Все города',
                'declination': '',
              });
            } else {
              Navigator.pop(context, null);
            }
          },
        ),
        Divider(
          height: 1,
          indent: 16,
          endIndent: 16,
          color: isDark ? Colors.white24 : null,
        ),
        ..._cities.map((city) {
          final isSelected =
              widget.selectedCityId == city.id ||
              widget.selectedCity == city.name;
          return Column(
            children: [
              ListTile(
                title: Text(
                  city.name,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: textColor,
                  ),
                ),
                subtitle: city.region.isNotEmpty
                    ? Text(
                        '${city.region}, ${city.country}',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: subtitleColor,
                        ),
                      )
                    : null,
                trailing: isSelected
                    ? const Icon(Icons.check, color: Color(0xff917dfa))
                    : null,
                onTap: () {
                  if (widget.returnId) {
                    Navigator.pop(context, {
                      'id': city.id,
                      'name': city.name,
                      'lat': city.lat,
                      'lon': city.lon,
                      'declination': city.declination ?? '',
                    });
                  } else {
                    Navigator.pop(context, city.name);
                  }
                },
              ),
              const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          );
        }),
      ],
    );
  }

  // ============================================================
  // ПОСТРОЕНИЕ РЕЖИМА ВЫБОРА ГОРОДА
  // ============================================================

  Widget _buildPickerMode() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff151e27) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputBgColor = isDark
        ? const Color(0xff233040)
        : const Color(0xFFF5F7FA);

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
        bottom: _currentLevel == 'regions'
            ? PreferredSize(
                preferredSize: const Size.fromHeight(60),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {});
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
                        color: isDark
                            ? Colors.white54
                            : const Color(0xff999999),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: isDark
                            ? Colors.white54
                            : const Color(0xff999999),
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.close,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xff999999),
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
              )
            : null,
      ),
      body: _currentLevel == 'regions'
          ? _buildPickerRegionsList()
          : _buildPickerCitiesList(),
    );
  }

  Widget _buildPickerRegionsList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

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

    return ListView.builder(
      itemCount: filteredRegions.length,
      itemBuilder: (context, index) {
        final region = filteredRegions[index];
        final regionId = _parseInt(region['region_id']);
        final regionName = region['region_name'] ?? '';

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
              _selectedRegionName = regionName;
            });
            _loadCitiesByRegion(regionId);
          },
        );
      },
    );
  }

  Widget _buildPickerCitiesList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputBgColor = isDark
        ? const Color(0xff233040)
        : const Color(0xFFF5F7FA);

    if (_isLoadingCities) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xff917dfa)),
      );
    }

    // Фильтруем города по поиску
    final filteredCities = _citiesByRegion.where((city) {
      final cityName = (city['city_name'] ?? city['geo_name'] ?? '')
          .toString()
          .toLowerCase();
      final query = _searchController.text.toLowerCase();
      return query.isEmpty || cityName.contains(query);
    }).toList();

    return Column(
      children: [
        // Заголовок с названием края
        if (_selectedRegionName != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Text(
                  'Города в крае: ',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: isDark ? Colors.white54 : const Color(0xff808080),
                  ),
                ),
                Expanded(
                  child: Text(
                    _selectedRegionName!,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff917dfa),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

        // Поле поиска
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (value) {
              setState(() {});
            },
            style: GoogleFonts.montserrat(fontSize: 14, color: textColor),
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
                        color: isDark
                            ? Colors.white54
                            : const Color(0xff999999),
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
                    final cityName =
                        city['city_name'] ?? city['geo_name'] ?? '';
                    final declination = city['declination'] ?? '';
                    final region = city['region_name'] ?? '';
                    final country = city['country_name'] ?? '';
                    final lat = _parseDouble(city['lat']);
                    final lon = _parseDouble(city['lon']);

                    final isSelected = _selectedCityId == cityId;

                    return ListTile(
                      leading: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xff917dfa),
                              size: 22,
                            )
                          : null,
                      title: Text(
                        cityName,
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected
                              ? const Color(0xff917dfa)
                              : textColor,
                        ),
                      ),
                      subtitle: region.isNotEmpty
                          ? Text(
                              '$region, $country',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xff808080),
                              ),
                            )
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedCityId = cityId;
                          _selectedCityName = cityName;
                          _selectedDeclination = declination;
                          _selectedLat = lat;
                          _selectedLon = lon;
                        });

                        // Возвращаем результат
                        if (widget.returnId) {
                          Navigator.pop(context, {
                            'id': cityId,
                            'name': cityName,
                            'lat': lat,
                            'lon': lon,
                            'declination': declination,
                          });
                        } else {
                          Navigator.pop(context, cityName);
                        }
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
