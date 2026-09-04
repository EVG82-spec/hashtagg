//G:\hashtagg_app\lib\features\search\screens\city_picker_screen.dart
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

class CityPickerScreen extends StatefulWidget {
  final int? selectedCityId;
  final String? selectedCity;
  final bool returnId; // Если true, возвращает Map с id и name

  const CityPickerScreen({
    super.key,
    this.selectedCityId,
    this.selectedCity,
    this.returnId = false,
  });

  @override
  State<CityPickerScreen> createState() => _CityPickerScreenState();
}

class _CityPickerScreenState extends State<CityPickerScreen> {
  final GeoApiRepository _geoApi = GeoApiRepository();
  final TextEditingController _searchController = TextEditingController();

  List<CityModel> _cities = [];
  List<CityModel> _allCities = []; // Все города без фильтра
  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedCountry; // Выбранная страна для фильтрации

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  final CategoriesApiRepository _categoriesApi = CategoriesApiRepository();

  @override
  void initState() {
    super.initState();
    _loadCities();
  }

  Future<void> _loadCities({String query = ''}) async {
    setState(() => _isLoading = true);

    try {
      // Если query пустой, загружаем все города, иначе ищем по запросу
      final result = await _geoApi.searchCities(
        query: query,
        onlyCity: true,
        allCities:
            query.isEmpty, // Все города только если нет поискового запроса
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

  void _onSearchChanged(String query) async {
    if (query.length < 2) {
      setState(() {
        _searchQuery = '';
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _searchQuery = query;
      _isSearching = true;
    });

    final result = await _categoriesApi.searchCategories(query);
    if (result['status'] == true) {
      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(result['data'] ?? []);
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
            : _buildCityList(),
      ),
    );
  }

  Widget _buildCityList() {
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
}
