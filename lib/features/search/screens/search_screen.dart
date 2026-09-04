//G:\hashtagg_app\lib\features\search\screens\search_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hashtagg/features/search/bloc/search_bloc.dart';
import 'package:hashtagg/features/home/bloc/categories_bloc.dart';
import 'package:hashtagg/features/home/bloc/stories_bloc.dart';
import 'package:hashtagg/features/home/widgets/ad_listing.dart';
import 'package:hashtagg/features/stories/screens/story_viewer_screen.dart';
import 'package:hashtagg/core/network/catalog_api_repository.dart';
import 'package:hashtagg/core/network/categories_api_repository.dart';
import 'package:hashtagg/core/network/filters_api_repository.dart';
import 'package:hashtagg/core/network/geo_api_repository.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/models/category.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hashtagg/features/stories/services/story_publisher.dart';
import 'package:hashtagg/core/services/permission_service.dart';
import 'dart:io';
import 'dart:async';
import 'search_filters_screen.dart';
import 'city_selection_screen.dart';
import 'category_picker_screen.dart';
import 'map_screen.dart';
import '../widgets/inline_filters.dart';

class SearchScreen extends StatefulWidget {
  final String initialQuery;
  final int? categoryId;
  final String? categoryName;
  final SearchFilters? initialFilters;

  const SearchScreen({
    super.key,
    this.initialQuery = '',
    this.categoryId,
    this.categoryName,
    this.initialFilters,
  });

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late TextEditingController _searchController;
  late FocusNode _focusNode;
  late ScrollController _scrollController;
  late SearchBloc _searchBloc;
  late StoriesBloc _storiesBloc;

  String _query = '';
  int? _selectedCategoryId;
  String? _selectedCategoryName;
  String? _cityDeclination;
  String _sortOption = 'Без сортировки';
  bool _isGridView = false;
  SearchFilters _filters = const SearchFilters();

  // Для подкатегорий и breadcrumbs
  List<Map<String, dynamic>> _subcategories = [];
  String _breadcrumb = '';
  bool _isLoadingSubcategories = false;
  int? _parentCategoryId; // ID родительской категории для показа siblings

  // Для фильтров (из SearchFiltersScreen)
  final FiltersApiRepository _filtersApi = FiltersApiRepository();
  final GeoApiRepository _geoApi = GeoApiRepository();
  bool _isLoadingFilters = true;
  Map<String, dynamic>? _filterData;
  late TextEditingController _priceFromController;
  late TextEditingController _priceToController;

  // Для скрытия/раскрытия категорий
  bool _showSubcategories = true;

  // Debounce timer для текстовых полей
  Timer? _debounceTimer;

  static const List<String> _sortOptions = [
    'Без сортировки',
    'Сначала дешевле',
    'Сначала дороже',
    'По дате (новые)',
    'По дате (старые)',
  ];

  @override
  void initState() {
    super.initState();

    print('🔵 [initState] START');
    print('🔵 [initState] - initialQuery: "${widget.initialQuery}"');
    print('🔵 [initState] - categoryId: ${widget.categoryId}');
    print('🔵 [initState] - categoryName: "${widget.categoryName}"');
    print('🔵 [initState] - initialFilters: ${widget.initialFilters}');

    _searchBloc = SearchBloc();
    _storiesBloc = StoriesBloc();
    _query = widget.initialQuery;
    _searchController = TextEditingController(text: widget.initialQuery);
    _priceFromController = TextEditingController(
      text: widget.initialFilters?.priceFrom?.toString() ?? '',
    );
    _priceToController = TextEditingController(
      text: widget.initialFilters?.priceTo?.toString() ?? '',
    );
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    if (widget.initialFilters != null) {
      _filters = widget.initialFilters!;
      // Если в фильтрах есть категория, используем её
      if (_filters.categoryId != null) {
        _selectedCategoryId = _filters.categoryId;
        _selectedCategoryName = _filters.category;
        print(
          '🔵 [initState] Category from filters: id=$_selectedCategoryId, name="$_selectedCategoryName"',
        );
      }
    }

    // Приоритет у явно переданных categoryId/categoryName
    if (widget.categoryId != null) {
      _selectedCategoryId = widget.categoryId;
      _selectedCategoryName = widget.categoryName;
      print(
        '🔵 [initState] Category from widget params: id=$_selectedCategoryId, name="$_selectedCategoryName"',
      );
    }

    _focusNode = FocusNode();

    // Загружаем кэшированный город
    _loadCachedCity();

    print(
      '🔵 [initState] Final state: categoryId=$_selectedCategoryId, categoryName="$_selectedCategoryName", breadcrumb="$_breadcrumb"',
    );

    // Автофокус при открытии (убран, чтобы не мешать при переходе из категорий)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print('🔵 [initState] PostFrameCallback executing');
      _performSearch();

      // Загружаем сторисы с фильтрами
      _loadStoriesWithFilters();

      // Загружаем подкатегории и фильтры
      _loadSubcategories();
      _loadFilterOptions();
    });

    print('🔵 [initState] END');
  }

  Future<void> _loadSubcategories() async {
    print('🔵 [_loadSubcategories] START');
    print(
      '🔵 [_loadSubcategories] - Current selectedCategoryId: $_selectedCategoryId',
    );
    print(
      '🔵 [_loadSubcategories] - Current selectedCategoryName: $_selectedCategoryName',
    );
    print('🔵 [_loadSubcategories] - Current breadcrumb: "$_breadcrumb"');
    print(
      '🔵 [_loadSubcategories] - Current parentCategoryId: $_parentCategoryId',
    );

    setState(() => _isLoadingSubcategories = true);

    try {
      final categoriesApi = CategoriesApiRepository();

      if (_selectedCategoryId == null) {
        // Если категория не выбрана, загружаем корневые категории
        print('🔵 [_loadSubcategories] Loading root categories (parentId=0)');
        final result = await categoriesApi.getCategories(parentId: 0);

        print('🔵 [_loadSubcategories] Root categories API response:');
        print('🔵 [_loadSubcategories] - status: ${result['status']}');
        print(
          '🔵 [_loadSubcategories] - data count: ${(result['data'] as List?)?.length ?? 0}',
        );
        print('🔵 [_loadSubcategories] - title: ${result['title']}');

        if (result['status'] == true && mounted) {
          setState(() {
            _subcategories = (result['data'] as List)
                .cast<Map<String, dynamic>>();
            _breadcrumb = ''; // Очищаем breadcrumb для корневого уровня
            _parentCategoryId = null;
            _isLoadingSubcategories = false;
          });
          print(
            '🔵 [_loadSubcategories] ROOT LEVEL SET: ${_subcategories.length} categories, breadcrumb cleared',
          );
        }
      } else {
        // Загружаем подкатегории выбранной категории
        print(
          '🔵 [_loadSubcategories] Loading subcategories for category: $_selectedCategoryId ($_selectedCategoryName)',
        );
        final result = await categoriesApi.getCategories(
          parentId: _selectedCategoryId!,
        );

        print('🔵 [_loadSubcategories] Subcategories API response:');
        print('🔵 [_loadSubcategories] - status: ${result['status']}');
        print(
          '🔵 [_loadSubcategories] - data count: ${(result['data'] as List?)?.length ?? 0}',
        );
        print('🔵 [_loadSubcategories] - title from API: "${result['title']}"');

        if (result['status'] == true && mounted) {
          final data = result['data'] as List?;

          // Определяем breadcrumb:
          // 1. Если breadcrumb уже установлен (пришел из клика по подкатегории), используем его
          // 2. Иначе используем title из API (для корневых категорий)
          String breadcrumbPath;
          if (_breadcrumb.isNotEmpty) {
            // Breadcrumb уже установлен из клика по подкатегории
            breadcrumbPath = _breadcrumb;
            print(
              '🔵 [_loadSubcategories] Using existing breadcrumb: "$breadcrumbPath"',
            );
          } else {
            // Используем title из API
            breadcrumbPath =
                result['title']?.toString() ?? _selectedCategoryName ?? '';
            print(
              '🔵 [_loadSubcategories] Using title from API as breadcrumb: "$breadcrumbPath"',
            );
          }

          // Если есть подкатегории - показываем их
          if (data != null && data.isNotEmpty) {
            print(
              '🔵 [_loadSubcategories] Found ${data.length} subcategories:',
            );
            for (var i = 0; i < data.length && i < 3; i++) {
              print(
                '🔵 [_loadSubcategories]   - ${data[i]['category_board_name']} (id: ${data[i]['category_board_id']}, breadcrumb: ${data[i]['breadcrumb']})',
              );
            }

            setState(() {
              _subcategories = data.cast<Map<String, dynamic>>();
              _breadcrumb = breadcrumbPath;
              _parentCategoryId = _selectedCategoryId;
              _isLoadingSubcategories = false;
            });
            print(
              '🔵 [_loadSubcategories] STATE UPDATED: ${_subcategories.length} subcategories, breadcrumb="$_breadcrumb", parent=$_parentCategoryId',
            );
          } else {
            // Если подкатегорий нет, скрываем блок категорий
            print(
              '🔵 [_loadSubcategories] No subcategories found, hiding categories block',
            );

            setState(() {
              _subcategories = [];
              _breadcrumb = breadcrumbPath;
              _isLoadingSubcategories = false;
            });
            print(
              '🔵 [_loadSubcategories] STATE UPDATED: no subcategories, breadcrumb="$_breadcrumb"',
            );
          }
        }
      }
    } catch (e) {
      print('🔴 [_loadSubcategories] ERROR: $e');
      setState(() => _isLoadingSubcategories = false);
    }

    print('🔵 [_loadSubcategories] END');
  }

  Future<void> _loadFilterOptions() async {
    setState(() => _isLoadingFilters = true);

    try {
      final result = await _filtersApi.getFilterOptions(
        categoryId: _selectedCategoryId ?? 0,
        filters: _filters.filters.isNotEmpty ? _filters.filters : null,
      );

      if (result['status'] == true && mounted) {
        setState(() {
          _filterData = result['data'];
          _isLoadingFilters = false;
        });
      } else {
        throw Exception(result['error'] ?? 'Failed to load filters');
      }
    } catch (e) {
      print('🔴 [SearchScreen] Error loading filters: $e');
      setState(() => _isLoadingFilters = false);
    }
  }

  void _onOptionChanged(String key, bool value) {
    print('🔵 [SearchScreen] _onOptionChanged: key=$key, value=$value');

    final newOptions = Map<String, bool>.from(_filters.options);
    newOptions[key] = value;

    setState(() {
      _filters = _filters.copyWith(options: newOptions);
    });

    // Выполняем поиск после обновления состояния с небольшой задержкой
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch();
    });
  }

  void _onFilterChanged(String filterId, String itemId, bool isSelected) {
    print(
      '🔵 [SearchScreen] _onFilterChanged: filterId=$filterId, itemId=$itemId, isSelected=$isSelected',
    );

    final newFilters = Map<String, List<String>>.from(_filters.filters);
    if (!newFilters.containsKey(filterId)) {
      newFilters[filterId] = [];
    }
    if (isSelected) {
      newFilters[filterId]!.remove(itemId);
      if (newFilters[filterId]!.isEmpty) {
        newFilters.remove(filterId);
      }
    } else {
      newFilters[filterId]!.add(itemId);
    }

    print('🔵 [SearchScreen] New filters: $newFilters');

    setState(() {
      _filters = _filters.copyWith(filters: newFilters);
    });

    // Выполняем поиск после обновления состояния с небольшой задержкой
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performSearch();
    });
  }

  void _onSelectCategory(int? categoryId, String? categoryNameOrBreadcrumb) {
    print('🔵 [SearchScreen] _onSelectCategory called');
    print(
      '🔵 [SearchScreen] - New category: id=$categoryId, nameOrBreadcrumb=$categoryNameOrBreadcrumb',
    );
    print(
      '🔵 [SearchScreen] - Previous category: id=$_selectedCategoryId, name=$_selectedCategoryName',
    );
    print('🔵 [SearchScreen] - Current breadcrumb: "$_breadcrumb"');
    print('🔵 [SearchScreen] - Current parent: $_parentCategoryId');

    setState(() {
      _selectedCategoryId = categoryId;
      _selectedCategoryName = categoryNameOrBreadcrumb;
      // Если передан breadcrumb (содержит " - " или " > "), используем его
      // Иначе сбрасываем и дадим _loadSubcategories установить его
      if (categoryNameOrBreadcrumb != null &&
          (categoryNameOrBreadcrumb.contains(' - ') ||
              categoryNameOrBreadcrumb.contains(' > '))) {
        // Это breadcrumb, используем его напрямую
        _breadcrumb = categoryNameOrBreadcrumb;
        print(
          '🔵 [SearchScreen] Using breadcrumb from parameter: "$_breadcrumb"',
        );
      } else {
        // Это просто имя категории, сбрасываем breadcrumb
        _breadcrumb = '';
        print(
          '🔵 [SearchScreen] Clearing breadcrumb, will be set by _loadSubcategories',
        );
      }
      // Также сбрасываем subcategories чтобы избежать показа старых данных
      _subcategories = [];
    });

    print('🔵 [SearchScreen] State updated');

    _performSearch();
    _loadSubcategories();
    _loadFilterOptions();
  }

  Future<void> _loadCachedCity() async {
    try {
      final box = await Hive.openBox('settings');
      final cityId = box.get('selectedCityId') as int?;
      final cityName = box.get('selectedCityName') as String?;
      final cachedDeclination = box.get('selectedCityDeclination') as String?;
      final cityLat = box.get('selectedCityLat') as double?;
      final cityLon = box.get('selectedCityLon') as double?;

      if (cityId != null && cityName != null) {
        // Если склонения нет в кэше, попробуем загрузить из API
        String? declination = cachedDeclination;
        if ((declination == null || declination.isEmpty) && cityId != 0) {
          try {
            final result = await _geoApi.searchCities(
              query: cityName,
              onlyCity: true,
            );
            if (result['status'] == true) {
              final cities = result['data'] as List;
              final city = cities.firstWhere(
                (c) => c['city_id'].toString() == cityId.toString(),
                orElse: () => null,
              );
              if (city != null) {
                declination = city['declination'] ?? '';
                // Сохраняем склонение в кэш
                await box.put('selectedCityDeclination', declination);
                print(
                  '✅ [SearchScreen] Loaded declination from API: $declination',
                );
              }
            }
          } catch (e) {
            print('🔴 [SearchScreen] Error loading declination from API: $e');
          }
        }

        setState(() {
          _cityDeclination = declination;
          _filters = _filters.copyWith(
            cityId: cityId,
            city: cityName,
            cityLat: cityLat,
            cityLon: cityLon,
          );
        });
        print(
          '✅ [SearchScreen] Loaded cached city: $cityName (ID: $cityId, declination: $declination)',
        );
      } else {
        // Устанавливаем "Все города" по умолчанию
        setState(() {
          _cityDeclination = '';
          _filters = _filters.copyWith(
            cityId: 0,
            city: 'Все города',
            cityLat: null,
            cityLon: null,
          );
        });
        print('✅ [SearchScreen] Set default city: Все города');
      }
    } catch (e) {
      print('🔴 [SearchScreen] Error loading cached city: $e');
    }
  }

  Future<void> _saveCityToCache(
    int? cityId,
    String? cityName,
    double? lat,
    double? lon, {
    String? declination,
  }) async {
    try {
      final box = await Hive.openBox('settings');
      if (cityId != null && cityName != null) {
        await box.put('selectedCityId', cityId);
        await box.put('selectedCityName', cityName);
        await box.put('selectedCityDeclination', declination ?? '');
        await box.put('selectedCityLat', lat);
        await box.put('selectedCityLon', lon);
        print(
          '✅ [SearchScreen] Cached city: $cityName (ID: $cityId, declination: $declination)',
        );
      } else {
        await box.delete('selectedCityId');
        await box.delete('selectedCityName');
        await box.delete('selectedCityDeclination');
        await box.delete('selectedCityLat');
        await box.delete('selectedCityLon');
        print('✅ [SearchScreen] Cleared cached city');
      }
    } catch (e) {
      print('🔴 [SearchScreen] Error saving city to cache: $e');
    }
  }

  String _wrapCityName(String name) {
    const maxChars = 11;
    if (name.length <= maxChars) return name;

    final words = name.split(' ');
    final lines = <String>[];
    String currentLine = '';

    for (final word in words) {
      if (currentLine.isEmpty) {
        if (word.length > maxChars) {
          lines.add(word);
          continue;
        }
        currentLine = word;
      } else {
        final testLine = '$currentLine $word';
        if (testLine.length <= maxChars) {
          currentLine = testLine;
        } else {
          lines.add(currentLine);
          if (word.length > maxChars) {
            lines.add(word);
            currentLine = '';
          } else {
            currentLine = word;
          }
        }
      }
    }

    if (currentLine.isNotEmpty) lines.add(currentLine);
    return lines.join('\n');
  }

  @override
  void dispose() {
    _searchBloc.close();
    _storiesBloc.close();
    _searchController.dispose();
    _priceFromController.dispose();
    _priceToController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      _searchBloc.add(LoadMoreAds());
    }
  }

  void _performSearch() {
    final priceFrom = int.tryParse(_priceFromController.text);
    final priceTo = int.tryParse(_priceToController.text);

    print(
      '🔵 [SearchScreen] _performSearch called with filters: ${_filters.filters}',
    );

    final params = CatalogSearchParams(
      categoryId: _selectedCategoryId,
      search: _query.isNotEmpty ? _query : null,
      priceStart: priceFrom?.toDouble(),
      priceEnd: priceTo?.toDouble(),
      cityId: _filters.cityId,
      sorting: _getSortingParam(),
      page: 1,
      vip: _filters.options['vip'],
      secure: _filters.options['secure'],
      onlineView: _filters.options['online_view'],
      auction: _filters.options['auction'],
      booking: _filters.options['booking'],
      filters: _filters.filters.isNotEmpty ? _filters.filters : null,
    );

    _searchBloc.add(SearchAds(params));

    // Перезагружаем сторисы с новыми фильтрами
    _loadStoriesWithFilters();
  }

  void _performSearchWithDebounce() {
    // Отменяем предыдущий таймер если он есть
    _debounceTimer?.cancel();

    // Создаем новый таймер на 250ms
    _debounceTimer = Timer(const Duration(milliseconds: 250), () {
      _performSearch();
    });
  }

  void _loadStoriesWithFilters() {
    // Загружаем сторисы с теми же фильтрами, что и объявления
    // В SearchFilters есть только cityId, regionId и countryId определяются автоматически на бэкенде
    print('🔵 [SearchScreen] Loading stories with filters:');
    print('🔵 [SearchScreen] - catId: $_selectedCategoryId');
    print('🔵 [SearchScreen] - cityId: ${_filters.cityId}');

    _storiesBloc.add(
      LoadStories(catId: _selectedCategoryId, cityId: _filters.cityId),
    );
  }

  String _getSortingParam() {
    switch (_sortOption) {
      case 'Сначала дешевле':
        return 'price_asc';
      case 'Сначала дороже':
        return 'price_desc';
      case 'По дате (новые)':
        return 'news';
      default:
        return 'default';
    }
  }

  void _showSortBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final maxHeight = MediaQuery.of(ctx).size.height * 0.6;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Сортировка',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ..._sortOptions.map(
                          (option) => ListTile(
                            title: Text(
                              option,
                              style: GoogleFonts.montserrat(fontSize: 14),
                            ),
                            trailing: _sortOption == option
                                ? const Icon(
                                    Icons.check,
                                    color: Color(0xff917dfa),
                                  )
                                : null,
                            onTap: () {
                              setState(() => _sortOption = option);
                              Navigator.pop(ctx);
                              _performSearch();
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider.value(value: _searchBloc),
        BlocProvider.value(value: _storiesBloc),
      ],
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Theme.of(context).scaffoldBackgroundColor,
          statusBarIconBrightness:
              Theme.of(context).brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: Theme.of(context).brightness,
        ),
        child: Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              children: [
                // AppBar с поиском
                _buildSearchBar(),

                // Основной контент
                Expanded(
                  child: BlocBuilder<SearchBloc, SearchState>(
                    builder: (context, state) {
                      return RefreshIndicator(
                        onRefresh: () async {
                          _performSearch();
                          _loadStoriesWithFilters();
                          await Future.delayed(Duration(milliseconds: 500));
                        },
                        color: Color(0xff917dfa),
                        edgeOffset: 40.0,
                        displacement: 20.0,
                        strokeWidth: 3.0,
                        child: CustomScrollView(
                          controller: _scrollController,
                          physics: AlwaysScrollableScrollPhysics(),
                          slivers: [
                            // Stories
                            _buildStories(),

                            // Breadcrumbs (хлебные крошки) - над заголовком
                            _buildBreadcrumbs(),

                            // Заголовок результатов
                            _buildResultsHeader(state),

                            // Подкатегории
                            _buildSubcategories(),

                            // Встроенные фильтры
                            _buildInlineFilters(),

                            // Строка сортировки + переключатель вида
                            _buildSortingBar(),

                            // Сетка/список объявлений
                            _buildAdsList(state),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Кнопка «Карта» внизу
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MapScreen(filters: _filters)),
              );
            },
            backgroundColor: const Color(0xff917dfa),
            elevation: 4,
            extendedPadding: const EdgeInsets.symmetric(horizontal: 48),
            icon: const Icon(Icons.map_outlined, color: Colors.white, size: 22),
            label: Text(
              'Карта',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerFloat,
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputBgColor = isDark
        ? const Color(0xff213140)
        : const Color(0xFFF5F7FA);
    final cityName = _filters.city ?? 'Все города';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          // Кнопка назад
          IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => context.pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          // Поисковая строка
          Expanded(
            child: SizedBox(
              height: 44,
              child: TextField(
                controller: _searchController,
                focusNode: _focusNode,
                onChanged: (v) => setState(() => _query = v),
                onSubmitted: (v) {
                  setState(() => _query = v);
                  _performSearch();
                },
                style: GoogleFonts.montserrat(fontSize: 14, color: textColor),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: inputBgColor,
                  hintText: 'Поиск', // <-- всегда просто "Поиск"
                  hintStyle: GoogleFonts.montserrat(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : const Color(0xff999999),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(14),
                    child: SvgPicture.asset(
                      'assets/search.svg',
                      height: 16,
                      width: 16,
                      colorFilter: isDark
                          ? const ColorFilter.mode(
                              Colors.white54,
                              BlendMode.srcIn,
                            )
                          : const ColorFilter.mode(
                              Color(0xff999999),
                              BlendMode.srcIn,
                            ),
                    ),
                  ),
                  suffixIcon: _query.isNotEmpty
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
                            setState(() => _query = '');
                            _performSearch();
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
          ),
          const SizedBox(width: 8),
          // Блок выбора города с иконкой и текстом
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push<Map<String, dynamic>>(
                context,
                createSwipeableRoute(
                  builder: (_) => CitySelectionScreen(
                    selectedCityId: _filters.cityId,
                    selectedCity: _filters.city,
                  ),
                ),
              );
              if (result != null && mounted) {
                final cityId = result['id'] as int?;
                final cityName = result['name'] as String?;
                final declination = result['declination'] as String?;
                final lat = result['lat'] as double?;
                final lon = result['lon'] as double?;

                await _saveCityToCache(
                  cityId,
                  cityName,
                  lat,
                  lon,
                  declination: declination,
                );

                setState(() {
                  _cityDeclination = declination;
                  _filters = _filters.copyWith(
                    cityId: cityId,
                    city: cityName,
                    cityLat: lat,
                    cityLon: lon,
                  );
                });
                _performSearch();
              }
            },
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xff233040)
                      : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        color: isDark ? Colors.white : Colors.black,
                        size: 20,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _wrapCityName(cityName),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStories() {
    return SliverToBoxAdapter(
      child: BlocBuilder<StoriesBloc, StoriesState>(
        builder: (context, state) {
          if (state is StoriesLoading) {
            return Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xff917dfa)),
              ),
            );
          }

          if (state is StoriesError) {
            // Не показываем ошибку, просто скрываем блок
            return SizedBox.shrink();
          }

          if (state is StoriesLoaded) {
            if (state.users.isEmpty) {
              // Если нет сторисов, не показываем блок
              return SizedBox.shrink();
            }

            return Container(
              height: 100,
              margin: EdgeInsets.only(bottom: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: state.users.length + 1, // +1 для кнопки создания
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  // Первый элемент - кнопка создания стории (только если есть разрешение)
                  if (index == 0) {
                    return BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, authState) {
                        // Проверяем разрешение на создание сторисов
                        final activeServices = authState.user?.activeServices;
                        if (activeServices == null || activeServices.isEmpty) {
                          // Если нет данных о сервисах, разрешаем (обратная совместимость)
                          return _buildAddStoryButton(context);
                        }

                        // Проверяем наличие сервиса 'stories' или любого начинающегося с 'stories_'
                        final hasPermission = activeServices.any(
                          (service) =>
                              service == 'stories' ||
                              service.startsWith('stories_'),
                        );

                        if (!hasPermission) {
                          return SizedBox.shrink();
                        }

                        return _buildAddStoryButton(context);
                      },
                    );
                  }

                  // Остальные элементы - сторисы пользователей
                  final userIndex = index - 1;
                  final user = state.users[userIndex];
                  final userName = user['name'] ?? 'Пользователь';
                  final avatar = ApiConfig.replaceMediaUrl(
                    user['avatar']?.toString() ?? '',
                  );
                  final stories = user['stories'] as List? ?? [];
                  final hasUnviewed = stories.any((s) => s['status'] == 1);

                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context, rootNavigator: true).push(
                        createSwipeableRoute(
                          builder: (_) => StoryViewerScreen(
                            allUsers: state.users,
                            initialUserIndex: userIndex,
                          ),
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: hasUnviewed ? Colors.orange : Colors.grey,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: avatar != null
                                ? Image.network(
                                    avatar,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(
                                      Icons.person,
                                      color: Colors.grey[600],
                                      size: 32,
                                    ),
                                  )
                                : Icon(
                                    Icons.person,
                                    color: Colors.grey[600],
                                    size: 32,
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 64,
                          child: Text(
                            userName,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          }

          // Initial state - не показываем ничего
          return SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildAddStoryButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        _showAddStoryDialog(context);
      },
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey[300]!, width: 2),
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey[200],
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 28,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xff917dfa),
                    ),
                    child: Icon(Icons.add, size: 14, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              'Добавить',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddStoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    // Запрашиваем разрешение на доступ к файлам
                    final hasPermission =
                        await PermissionService.requestStoragePermission(
                          context,
                        );
                    if (!hasPermission) {
                      return;
                    }
                    // Выбор фото
                    final picker = ImagePicker();
                    final image = await picker.pickImage(
                      source: ImageSource.gallery,
                    );
                    if (image != null && context.mounted) {
                      // Переход на экран создания стории (можно добавить позже)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Функция создания стории будет добавлена',
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xffF0EEFF),
                    foregroundColor: Color(0xff917dfa),
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Добавить фото',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    // Запрашиваем разрешение на доступ к файлам
                    final hasPermission =
                        await PermissionService.requestStoragePermission(
                          context,
                        );
                    if (!hasPermission) {
                      return;
                    }
                    // Выбор видео
                    final picker = ImagePicker();
                    final video = await picker.pickVideo(
                      source: ImageSource.gallery,
                    );
                    if (video != null && context.mounted) {
                      // Переход на экран создания стории (можно добавить позже)
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Функция создания стории будет добавлена',
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xffF0EEFF),
                    foregroundColor: Color(0xff917dfa),
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Добавить видео',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsHeader(SearchState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _selectedCategoryName ??
                  (_query.isEmpty ? 'Все категории' : 'Результаты поиска'),
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 2),
            if (state is SearchLoaded && _query.isNotEmpty)
              Text(
                state.count,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : const Color(0xff808080),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreadcrumbs() {
    print('🔵 [_buildBreadcrumbs] RENDER START');
    print('🔵 [_buildBreadcrumbs] - breadcrumb: "$_breadcrumb"');
    print('🔵 [_buildBreadcrumbs] - selectedCategoryId: $_selectedCategoryId');
    print(
      '🔵 [_buildBreadcrumbs] - selectedCategoryName: "$_selectedCategoryName"',
    );
    print('🔵 [_buildBreadcrumbs] - parentCategoryId: $_parentCategoryId');

    // Скрываем breadcrumbs если пользователь ввел поисковый запрос
    if (_query.isNotEmpty) {
      print('🔵 [_buildBreadcrumbs] Query is not empty, hiding breadcrumbs');
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    if (_breadcrumb.isEmpty && _selectedCategoryId == null) {
      print(
        '🔵 [_buildBreadcrumbs] Empty breadcrumb and no category selected, hiding',
      );
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white70 : const Color(0xff666666);

    // Разбиваем breadcrumb на части
    // Поддерживаем оба формата: "Категория > Подкатегория" и "Категория - Подкатегория"
    List<String> breadcrumbParts = [];
    if (_breadcrumb.contains('>')) {
      breadcrumbParts = _breadcrumb
          .split('>')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      print('🔵 [_buildBreadcrumbs] Split by ">": $breadcrumbParts');
    } else if (_breadcrumb.contains('-')) {
      breadcrumbParts = _breadcrumb
          .split('-')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      print('🔵 [_buildBreadcrumbs] Split by "-": $breadcrumbParts');
    } else if (_breadcrumb.isNotEmpty) {
      breadcrumbParts = [_breadcrumb.trim()];
      print('🔵 [_buildBreadcrumbs] Single part: $breadcrumbParts');
    }

    print('🔵 [_buildBreadcrumbs] Final parts: $breadcrumbParts');

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Wrap(
          spacing: 6,
          runSpacing: 4,
          children: [
            // "Все категории" - всегда первый элемент
            GestureDetector(
              onTap: () {
                print('🔵 [_buildBreadcrumbs] Clicked "Все категории"');
                _onSelectCategory(null, null);
              },
              child: Text(
                'Все категории',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: _selectedCategoryId == null
                      ? const Color(0xff917dfa)
                      : textColor,
                ),
              ),
            ),
            // Каждая часть breadcrumb как отдельный кликабельный элемент
            if (breadcrumbParts.isNotEmpty) ...[
              for (int i = 0; i < breadcrumbParts.length; i++) ...[
                Icon(Icons.chevron_right, size: 16, color: textColor),
                GestureDetector(
                  onTap: () {
                    print(
                      '🔵 [_buildBreadcrumbs] Clicked breadcrumb part $i: "${breadcrumbParts[i]}"',
                    );
                    print(
                      '🔵 [_buildBreadcrumbs] - Is last part: ${i == breadcrumbParts.length - 1}',
                    );
                    print(
                      '🔵 [_buildBreadcrumbs] - parentCategoryId: $_parentCategoryId',
                    );

                    // Все элементы кликабельны, кроме последнего (текущая категория)
                    if (i < breadcrumbParts.length - 1) {
                      print(
                        '🔵 [_buildBreadcrumbs] Navigating to parent category',
                      );
                      // Клик по родительской категории
                      // Переходим к родительской категории
                      if (i == 0 && _parentCategoryId != null) {
                        // Первый элемент - переходим к родительской категории
                        _onSelectCategory(
                          _parentCategoryId,
                          breadcrumbParts[i],
                        );
                      }
                    } else {
                      print(
                        '🔵 [_buildBreadcrumbs] Current category clicked (no action)',
                      );
                    }
                  },
                  child: Text(
                    breadcrumbParts[i],
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: i == breadcrumbParts.length - 1
                          ? const Color(0xff917dfa)
                          : textColor,
                      fontWeight: i == breadcrumbParts.length - 1
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSubcategories() {
    // Скрываем категории если пользователь ввел поисковый запрос
    if (_query.isNotEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    if (_subcategories.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff233040) : const Color(0xFFF5F7FA);
    final textColor = isDark ? Colors.white : Colors.black;

    return SliverToBoxAdapter(
      child: Column(
        children: [
          // Кнопка скрытия/раскрытия категорий
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showSubcategories = !_showSubcategories;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                color: Colors.transparent,
                child: Row(
                  children: [
                    Text(
                      'Категории',
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      _showSubcategories
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: textColor,
                      size: 20,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Список категорий с анимацией
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _showSubcategories
                ? Column(
                    children: _subcategories.asMap().entries.map((entry) {
                      final index = entry.key;
                      final category = entry.value;
                      final categoryId = _parseInt(
                        category['category_board_id'],
                      );
                      final categoryName =
                          category['category_board_name'] ?? '';
                      final categoryBreadcrumb =
                          category['breadcrumb'] ?? categoryName;
                      final isSelected = _selectedCategoryId == categoryId;

                      return Padding(
                        padding: EdgeInsets.only(
                          left: 20,
                          right: 20,
                          bottom: index == _subcategories.length - 1 ? 12 : 8,
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              print(
                                '🔵 [SubcategoryClick] Clicked: $categoryName (id: $categoryId)',
                              );
                              print(
                                '🔵 [SubcategoryClick] Breadcrumb from category: $categoryBreadcrumb',
                              );
                              // Передаем breadcrumb вместо просто имени
                              _onSelectCategory(categoryId, categoryBreadcrumb);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xff917dfa)
                                    : bgColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      categoryName,
                                      style: GoogleFonts.montserrat(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? Colors.white
                                            : textColor,
                                      ),
                                    ),
                                  ),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                              ? Colors.white54
                                              : Colors.black54),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Widget _buildSortingBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xff444444);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: _showSortBottomSheet,
              child: Row(
                children: [
                  Text(
                    _sortOption,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.keyboard_arrow_down, size: 18, color: textColor),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => _isGridView = !_isGridView),
              child: Icon(
                _isGridView ? Icons.grid_view_rounded : Icons.view_list_rounded,
                color: textColor,
                size: 22,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineFilters() {
    if (_isLoadingFilters) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(color: Color(0xff917dfa)),
          ),
        ),
      );
    }

    if (_filterData == null ||
        (_filterData!['filters'] == null && _filterData!['options'] == null)) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: InlineFilters(
        filterData: _filterData,
        options: _filters.options,
        selectedFilters: _filters.filters,
        priceFromController: _priceFromController,
        priceToController: _priceToController,
        onOptionChanged: _onOptionChanged,
        onFilterChanged: _onFilterChanged,
        onFiltersUpdated: _loadFilterOptions,
        onPriceChanged: _performSearchWithDebounce,
      ),
    );
  }

  Widget _buildAdsList(SearchState state) {
    if (state is SearchLoading) {
      return const SliverFillRemaining(
        child: Center(
          child: CircularProgressIndicator(color: Color(0xff917dfa)),
        ),
      );
    }

    if (state is SearchError) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Color(0xffcccccc),
              ),
              const SizedBox(height: 16),
              Text(
                'Ошибка загрузки',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: const Color(0xff808080),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (state is SearchLoaded && state.ads.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.search_off, size: 64, color: Color(0xffcccccc)),
              const SizedBox(height: 16),
              Text(
                'Ничего не найдено',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: const Color(0xff808080),
                ),
              ),
              if (_query.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Попробуйте изменить запрос',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: const Color(0xffaaaaaa),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (state is SearchLoaded || state is SearchLoadingMore) {
      final ads = state is SearchLoaded
          ? state.ads
          : (state as SearchLoadingMore).currentAds;

      if (_isGridView) {
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.5225,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => AdListing(ad: ads[index]),
              childCount: ads.length,
            ),
          ),
        );
      } else {
        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SizedBox(
                  height: 462, // Увеличена высота для режима списка
                  child: AdListing(ad: ads[index]),
                ),
              ),
              childCount: ads.length,
            ),
          ),
        );
      }
    }

    return const SliverToBoxAdapter(child: SizedBox());
  }
}
