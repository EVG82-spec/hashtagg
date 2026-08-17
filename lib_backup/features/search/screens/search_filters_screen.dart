import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'city_picker_screen.dart';
import 'category_picker_screen.dart';
import 'package:hashtagg/core/network/filters_api_repository.dart';

class SearchFilters {
  final String? city;
  final int? cityId;
  final double? cityLat;
  final double? cityLon;
  final String? category;
  final int? categoryId;
  final Map<String, bool> options; // vip, secure, online_view, etc.
  final int? priceFrom;
  final int? priceTo;
  final Map<String, List<String>> filters; // {filterId: [selectedItemIds]}

  const SearchFilters({
    this.city,
    this.cityId,
    this.cityLat,
    this.cityLon,
    this.category,
    this.categoryId,
    this.options = const {},
    this.priceFrom,
    this.priceTo,
    this.filters = const {},
  });

  SearchFilters copyWith({
    Object? city = _sentinel,
    Object? cityId = _sentinel,
    Object? cityLat = _sentinel,
    Object? cityLon = _sentinel,
    Object? category = _sentinel,
    Object? categoryId = _sentinel,
    Map<String, bool>? options,
    Object? priceFrom = _sentinel,
    Object? priceTo = _sentinel,
    Map<String, List<String>>? filters,
  }) {
    return SearchFilters(
      city: city == _sentinel ? this.city : city as String?,
      cityId: cityId == _sentinel ? this.cityId : cityId as int?,
      cityLat: cityLat == _sentinel ? this.cityLat : cityLat as double?,
      cityLon: cityLon == _sentinel ? this.cityLon : cityLon as double?,
      category: category == _sentinel ? this.category : category as String?,
      categoryId: categoryId == _sentinel ? this.categoryId : categoryId as int?,
      options: options ?? this.options,
      priceFrom: priceFrom == _sentinel ? this.priceFrom : priceFrom as int?,
      priceTo: priceTo == _sentinel ? this.priceTo : priceTo as int?,
      filters: filters ?? this.filters,
    );
  }
}

const _sentinel = Object();

class SearchFiltersScreen extends StatefulWidget {
  final SearchFilters initial;

  const SearchFiltersScreen({super.key, required this.initial});

  @override
  State<SearchFiltersScreen> createState() => _SearchFiltersScreenState();
}

class _SearchFiltersScreenState extends State<SearchFiltersScreen> {
  final FiltersApiRepository _filtersApi = FiltersApiRepository();
  
  late int? _cityId;
  late String? _city;
  late double? _cityLat;
  late double? _cityLon;
  late int? _categoryId;
  late String? _category;
  late Map<String, bool> _options;
  late Map<String, List<String>> _selectedFilters;
  late TextEditingController _priceFromController;
  late TextEditingController _priceToController;
  
  bool _isLoading = true;
  Map<String, dynamic>? _filterData;

  @override
  void initState() {
    super.initState();
    _cityId = widget.initial.cityId;
    _city = widget.initial.city;
    _cityLat = widget.initial.cityLat;
    _cityLon = widget.initial.cityLon;
    _categoryId = widget.initial.categoryId;
    _category = widget.initial.category;
    _options = Map.from(widget.initial.options);
    _selectedFilters = Map.from(widget.initial.filters);
    _priceFromController = TextEditingController(
      text: widget.initial.priceFrom?.toString() ?? '',
    );
    _priceToController = TextEditingController(
      text: widget.initial.priceTo?.toString() ?? '',
    );
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    setState(() => _isLoading = true);
    
    try {
      print('🔵 [SearchFilters] Loading filter options for category: ${_categoryId ?? 0}');
      print('🔵 [SearchFilters] Current filters: $_selectedFilters');
      
      final result = await _filtersApi.getFilterOptions(
        categoryId: _categoryId ?? 0,
        filters: _selectedFilters.isNotEmpty ? _selectedFilters : null,
      );
      
      if (result['status'] == true) {
        setState(() {
          _filterData = result['data'];
          _isLoading = false;
        });
        
        final filtersCount = (_filterData?['filters'] as List?)?.length ?? 0;
        print('✅ [SearchFilters] Filter options loaded: $filtersCount filters');
      } else {
        throw Exception(result['error'] ?? 'Failed to load filters');
      }
    } catch (e) {
      print('🔴 [SearchFilters] Error loading filters: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _priceFromController.dispose();
    _priceToController.dispose();
    super.dispose();
  }

  Future<void> _pickCity() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      createSwipeableRoute(
        builder: (_) => CityPickerScreen(
          selectedCityId: _cityId,
          selectedCity: _city,
          returnId: true,
        ),
      ),
    );
    if (mounted && result != null) {
      setState(() {
        _cityId = result['id'] as int?;
        _city = result['name'] as String?;
        _cityLat = result['lat'] as double?;
        _cityLon = result['lon'] as double?;
      });
    }
  }

  Future<void> _pickCategory() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      createSwipeableRoute(
        builder: (_) => CategoryPickerScreen(
          selectedCategoryId: _categoryId,
          selectedCategory: _category,
          returnId: true,
        ),
      ),
    );
    if (mounted && result != null) {
      setState(() {
        _categoryId = result['id'] as int?;
        _category = result['name'] as String?;
      });
      // Перезагружаем фильтры для новой категории
      _loadFilterOptions();
    }
  }

  void _apply() {
    final priceFrom = int.tryParse(_priceFromController.text);
    final priceTo = int.tryParse(_priceToController.text);
    Navigator.pop(
      context,
      SearchFilters(
        cityId: _cityId,
        city: _city,
        cityLat: _cityLat,
        cityLon: _cityLon,
        categoryId: _categoryId,
        category: _category,
        options: _options,
        priceFrom: priceFrom,
        priceTo: priceTo,
        filters: _selectedFilters,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Фильтры',
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: isDark ? const Color(0xff233040) : Colors.white,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(0xff917dfa)),
        ),
      );
    }

    final options = _filterData?['options'] as Map<String, dynamic>?;
    final filters = _filterData?['filters'] as List?;
    final priceName = _filterData?['price_name'] as String? ?? 'Цена';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Фильтры',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: isDark ? const Color(0xff233040) : Colors.white,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // City selector
                  _SelectorTile(label: _city ?? 'Все города', onTap: _pickCity),
                  const SizedBox(height: 12),

                  // Category selector (с второстепенным цветом)
                  _SelectorTile(
                    label: _category ?? 'Все категории',
                    onTap: _pickCategory,
                    isSecondary: true,
                  ),
                  const SizedBox(height: 20),

                  // Options (VIP, secure, etc.)
                  if (options != null && options.isNotEmpty) ...[
                    for (var entry in options.entries) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.value,
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                          ),
                          Switch(
                            value: _options[entry.key] ?? false,
                            onChanged: (v) => setState(() => _options[entry.key] = v),
                            activeColor: const Color(0xff917dfa),
                            inactiveThumbColor: isDark ? Colors.white70 : Colors.grey,
                            inactiveTrackColor: isDark ? const Color(0xff233040) : Colors.grey[300],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],

                  // Dynamic filters
                  if (filters != null && filters.isNotEmpty) ...[
                    for (var filter in filters) ...[
                      Text(
                        filter['name'] + (filter['required'] == true ? ' *' : ''),
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 10),
                      
                      if (filter['view'] == 'select') ...[
                        // Dropdown
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xff151e27) : const Color(0xFFF5F7FA),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _selectedFilters[filter['id'].toString()]?.firstOrNull,
                              dropdownColor: isDark ? const Color(0xff233040) : Colors.white,
                              hint: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Выберите ${filter['name'].toLowerCase()}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 15,
                                        color: const Color(0xff999999),
                                      ),
                                    ),
                                  ),
                                  if (filter['podfilter'] == true)
                                    const Icon(
                                      Icons.filter_list,
                                      size: 16,
                                      color: Color(0xff917dfa),
                                    ),
                                ],
                              ),
                              isExpanded: true,
                              items: (filter['items'] as List).map<DropdownMenuItem<String>>((item) {
                                return DropdownMenuItem<String>(
                                  value: item['id'].toString(),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item['name'],
                                          style: GoogleFonts.montserrat(
                                            fontSize: 15,
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                      ),
                                      if (item['podfilter'] == true)
                                        const Icon(
                                          Icons.arrow_forward_ios,
                                          size: 12,
                                          color: Color(0xff917dfa),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() {
                                    _selectedFilters[filter['id'].toString()] = [value];
                                  });
                                  // Перезагружаем фильтры если есть подфильтры
                                  if (filter['podfilter'] == true) {
                                    print('🔵 [SearchFilters] Reloading filters for subfilters');
                                    // Показываем индикатор загрузки
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => const Center(
                                        child: CircularProgressIndicator(
                                          color: Color(0xff917dfa),
                                        ),
                                      ),
                                    );
                                    _loadFilterOptions().then((_) {
                                      if (mounted) Navigator.pop(context);
                                    });
                                  }
                                }
                              },
                            ),
                          ),
                        ),
                        if (filter['podfilter'] == true && _selectedFilters[filter['id'].toString()] == null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.info_outline,
                                  size: 14,
                                  color: Color(0xff917dfa),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    'После выбора появятся дополнительные фильтры',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 12,
                                      color: const Color(0xff917dfa),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ] else if (filter['view'] == 'checkbox') ...[
                        // Chips
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
                                      : const Color(0xFFF5F7FA),
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
                        // Text input
                        TextField(
                          controller: TextEditingController(
                            text: _selectedFilters[filter['id'].toString()]?.firstOrNull ?? '',
                          ),
                          onChanged: (value) {
                            setState(() {
                              _selectedFilters[filter['id'].toString()] = [value];
                            });
                          },
                          style: GoogleFonts.montserrat(fontSize: 15),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: const Color(0xFFF5F7FA),
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
                              color: const Color(0xff999999),
                            ),
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 20),
                    ],
                  ],

                  // Price
                  Text(
                    priceName,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Price inputs
                  Row(
                    children: [
                      Expanded(
                        child: _PriceField(
                          controller: _priceFromController,
                          hint: 'От',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _PriceField(
                          controller: _priceToController,
                          hint: 'До',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Apply button
          Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              top: 8,
            ),
            child: SizedBox(
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
          ),
        ],
      ),
    );
  }
}

class _SelectorTile extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isSecondary; // Для второстепенного цвета

  const _SelectorTile({
    required this.label, 
    required this.onTap,
    this.isSecondary = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark 
        ? (isSecondary ? const Color(0xff233040) : const Color(0xff151e27))
        : const Color(0xFFF5F7FA);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _PriceField({required this.controller, required this.hint});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: GoogleFonts.montserrat(
        fontSize: 15,
        color: isDark ? Colors.white : Colors.black,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xff151e27) : const Color(0xFFF5F7FA),
        hintText: hint,
        hintStyle: GoogleFonts.montserrat(
          fontSize: 15,
          color: const Color(0xff999999),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
