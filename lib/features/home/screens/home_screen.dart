//G:\hashtagg_app\lib\features\home\screens\home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/shared/presentation/widgets/app_footer.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/features/home/bloc/feed_bloc.dart';
import 'package:hashtagg/features/home/bloc/categories_bloc.dart';
import 'package:hashtagg/features/home/bloc/stories_bloc.dart';
import 'package:hashtagg/features/home/bloc/banner_bloc.dart';
import 'package:hashtagg/features/home/widgets/feed.dart';
import 'package:hashtagg/features/home/widgets/map_miniature.dart';
import 'package:hashtagg/features/search/screens/search_filters_screen.dart';
import 'package:hashtagg/features/search/screens/city_selection_screen.dart';
import 'package:hashtagg/features/search/screens/map_screen.dart';
import 'package:hashtagg/features/stories/screens/story_viewer_screen.dart';
import 'package:hashtagg/features/stories/services/story_publisher.dart';
import 'package:hashtagg/core/network/geo_api_repository.dart';
import 'package:hashtagg/core/network/categories_api_repository.dart';
import 'package:hashtagg/core/network/profile_api_repository.dart';
import 'package:hashtagg/core/network/home_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hashtagg/core/services/permission_service.dart';
import 'package:hashtagg/core/services/first_launch_service.dart';
import 'package:hashtagg/core/widgets/autostart_dialog.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/loading_notifier.dart';
import 'package:hashtagg/core/models/banner.dart';
import 'package:hashtagg/shared/presentation/screens/webview_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import 'package:native_video_player/native_video_player.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';
import 'dart:async';
import '../widgets/category_card.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late ScrollController _scrollController;
  bool _isCollapsed = false;
  bool _showScrollToTop = false;
  SearchFilters _filters = const SearchFilters();
  String? cityDeclination;
  Timer? _hideButtonTimer;
  double _lastOffset = 0;

  // ===== ДОБАВЛЕНЫ ПЕРЕМЕННЫЕ ДЛЯ ГОРОДА =====
  int? _cityId;
  int? _regionId;
  int? _countryId;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
    _loadCachedCity();
    //_loadSliders();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstLaunch();
    });
  }

  Future<void> _checkFirstLaunch() async {
    print('🔵 [HomeScreen] Checking first launch...');
    if (mounted) {
      print('✅ [HomeScreen] Context is mounted, checking autostart');

      await showAutostartDialogIfNeeded(context);

      print('✅ [HomeScreen] Showing first launch dialog');
      await FirstLaunchService.showFirstLaunchPermissionsDialog(context);
      print('✅ [HomeScreen] Dialog completed, reloading cached city');
      await _loadCachedCity();
    } else {
      print('🔴 [HomeScreen] Context not mounted');
    }
  }

  @override
  void dispose() {
    _hideButtonTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedCity() async {
    try {
      print('🔵 [HomeScreen] Loading cached city...');
      final box = await Hive.openBox('settings');
      final cityId = box.get('selectedCityId') as int?;
      final cityName = box.get('selectedCityName') as String?;
      final cachedDeclination = box.get('selectedCityDeclination') as String?;
      final cityLat = box.get('selectedCityLat') as double?;
      final cityLon = box.get('selectedCityLon') as double?;

      print(
        '🔵 [HomeScreen] Cached values: ID=$cityId, Name=$cityName, Lat=$cityLat, Lon=$cityLon',
      );

      if (cityId != null && cityName != null) {
        String? declination = cachedDeclination;
        if ((declination == null || declination.isEmpty) && cityId != 0) {
          try {
            final geoApi = GeoApiRepository();
            final result = await geoApi.searchCities(
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
                await box.put('selectedCityDeclination', declination);
                print(
                  '✅ [HomeScreen] Loaded declination from API: $declination',
                );
              }
            }
          } catch (e) {
            print('🔴 [HomeScreen] Error loading declination from API: $e');
          }
        }

        setState(() {
          cityDeclination = declination;
          _filters = _filters.copyWith(
            cityId: cityId,
            city: cityName,
            cityLat: cityLat,
            cityLon: cityLon,
          );
          // ===== СОХРАНЯЕМ ID В ПЕРЕМЕННЫЕ =====
          _cityId = cityId;
          _regionId = 0;
          _countryId = 0;
        });
        print(
          '✅ [HomeScreen] Loaded cached city: $cityName (ID: $cityId, declination: $declination)',
        );
      } else {
        print('⚠️ [HomeScreen] No cached city, setting "Все города"');
        setState(() {
          cityDeclination = '';
          _filters = _filters.copyWith(
            cityId: 0,
            city: 'Все города',
            cityLat: null,
            cityLon: null,
          );
          _cityId = 0;
          _regionId = 0;
          _countryId = 0;
        });
        print('✅ [HomeScreen] Set default city: Все города');
      }
    } catch (e) {
      print('🔴 [HomeScreen] Error loading cached city: $e');
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
          '✅ [HomeScreen] Cached city: $cityName (ID: $cityId, declination: $declination)',
        );
      } else {
        await box.delete('selectedCityId');
        await box.delete('selectedCityName');
        await box.delete('selectedCityDeclination');
        await box.delete('selectedCityLat');
        await box.delete('selectedCityLon');
        print('✅ [HomeScreen] Cleared cached city');
      }
    } catch (e) {
      print('🔴 [HomeScreen] Error saving city to cache: $e');
    }
  }

  void _onScroll() {
    final offset = _scrollController.offset;
    final isCollapsed = offset > (150.0 - kToolbarHeight);

    // Определяем направление скролла
    final isScrollingUp = offset < _lastOffset; // ← МЕНЯЕМ НА isScrollingUp
    print('🔵 offset: $offset, isScrollingUp: $isScrollingUp');
    _lastOffset = offset;

    // Сбрасываем таймер
    _hideButtonTimer?.cancel();

    if (isScrollingUp && offset > 100) {
      // Листаем вверх → показываем кнопку
      if (!_showScrollToTop) {
        setState(() => _showScrollToTop = true);
      }

      // Запускаем таймер на 2 секунды (если остановится — скроем)
      _hideButtonTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && _showScrollToTop) {
          setState(() => _showScrollToTop = false);
        }
      });
    } else if (!isScrollingUp) {
      // Листаем вниз → скрываем кнопку
      if (_showScrollToTop) {
        setState(() => _showScrollToTop = false);
      }
    }

    // Обновляем состояние шапки
    if (_isCollapsed != isCollapsed) {
      setState(() => _isCollapsed = isCollapsed);
    }
  }

  bool _checkStoriesPermission(AuthState authState) {
    if (authState.user == null) {
      print('🔴 [StoriesPermission] User not authenticated');
      return false;
    }

    final activeServices = authState.user!.activeServices;
    print('🔵 [StoriesPermission] Active services: $activeServices');

    if (activeServices == null || activeServices.isEmpty) {
      print(
        '⚠️ [StoriesPermission] No active services data, denying by default',
      );
      return false;
    }

    final hasPermission = activeServices.any(
      (service) => service == 'stories' || service.startsWith('stories_'),
    );
    print(
      '${hasPermission ? "✅" : "🔴"} [StoriesPermission] Has stories permission: $hasPermission',
    );
    return hasPermission;
  }

  void _showStorySettingsDialog(
    BuildContext context, {
    required String filePath,
    required bool isPhoto,
  }) {
    String selectedPromotion = 'Свой профиль';
    String selectedLocation = 'Все города';
    String selectedCategory = 'Все категории';
    int? selectedCityId;
    int? selectedRegionId;
    int? selectedCountryId;
    int? selectedCatId;
    int? selectedAdId;
    String selectedLink = 'profile';
    bool isPublishing = false;

    Navigator.of(context, rootNavigator: true).push(
      createSwipeableRoute(
        builder: (BuildContext context) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              final isDark = Theme.of(context).brightness == Brightness.dark;

              return Scaffold(
                backgroundColor: isDark
                    ? const Color(0xff151e27)
                    : Colors.white,
                body: Column(
                  children: [
                    Container(
                      padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + 8,
                        left: 16,
                        right: 16,
                        bottom: 16,
                      ),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isDark
                                ? const Color(0xff233040)
                                : Colors.grey[300]!,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isPhoto ? 'Добавить фото' : 'Добавить видео',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: Container(
                        color: Colors.black,
                        child: Center(
                          child: isPhoto
                              ? Image.file(File(filePath), fit: BoxFit.contain)
                              : _VideoPreview(filePath: filePath),
                        ),
                      ),
                    ),

                    Container(
                      padding: EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSettingItem(
                            context,
                            title: 'Буду продвигать',
                            subtitle: selectedPromotion,
                            onTap: () {
                              _showPromotionOptions(context, (value, adId) {
                                setModalState(() {
                                  selectedPromotion = value;
                                  if (adId != null) {
                                    selectedAdId = adId;
                                    selectedLink = 'ad';
                                  } else {
                                    selectedAdId = null;
                                    selectedLink = 'profile';
                                  }
                                });
                              });
                            },
                          ),
                          SizedBox(height: 16),

                          _buildSettingItem(
                            context,
                            title: 'Локация',
                            subtitle: selectedLocation,
                            onTap: () {
                              _showLocationOptions(context, (
                                value,
                                cityId,
                                regionId,
                                countryId,
                              ) {
                                setModalState(() {
                                  selectedLocation = value;
                                  selectedCityId = cityId;
                                  selectedRegionId = regionId;
                                  selectedCountryId = countryId;
                                });
                              });
                            },
                          ),
                          SizedBox(height: 16),

                          _buildSettingItem(
                            context,
                            title: 'Категория',
                            subtitle: selectedCategory,
                            onTap: () {
                              _showCategoryOptions(context, (value, catId) {
                                setModalState(() {
                                  selectedCategory = value;
                                  selectedCatId = catId;
                                });
                              });
                            },
                          ),
                          SizedBox(height: 24),

                          ElevatedButton(
                            onPressed: isPublishing
                                ? null
                                : () async {
                                    setModalState(() {
                                      isPublishing = true;
                                    });

                                    try {
                                      final publisher = StoryPublisher();
                                      final result = await publisher
                                          .publishStory(
                                            filePath: filePath,
                                            isPhoto: isPhoto,
                                            cityId: selectedCityId ?? 0,
                                            regionId: selectedRegionId ?? 0,
                                            countryId: selectedCountryId ?? 0,
                                            catId: selectedCatId ?? 0,
                                            link: selectedLink,
                                            adId: selectedAdId ?? 0,
                                          );

                                      if (!context.mounted) return;

                                      final storiesBloc = context
                                          .read<StoriesBloc>();
                                      final scaffoldMessenger =
                                          ScaffoldMessenger.of(context);
                                      final navigator = Navigator.of(context);
                                      final goRouter = GoRouter.of(context);

                                      navigator.pop();

                                      if (result['status'] == true) {
                                        final data = result['data'];
                                        if (data['balance'] == false) {
                                          showDialog(
                                            context: context,
                                            builder: (context) => AlertDialog(
                                              title: Text(
                                                'Недостаточно средств',
                                              ),
                                              content: Text(
                                                'Пополните баланс для публикации стории',
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: Text('Отмена'),
                                                ),
                                                TextButton(
                                                  onPressed: () {
                                                    Navigator.pop(context);
                                                    goRouter.push('/wallet');
                                                  },
                                                  child: Text('Пополнить'),
                                                ),
                                              ],
                                            ),
                                          );
                                        } else {
                                          scaffoldMessenger.showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                'Стория опубликована!',
                                              ),
                                              backgroundColor: Colors.green,
                                            ),
                                          );
                                          storiesBloc.add(LoadStories());
                                        }
                                      } else {
                                        scaffoldMessenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Ошибка: ${result['error']}',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Ошибка: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    } finally {
                                      if (context.mounted) {
                                        setModalState(() {
                                          isPublishing = false;
                                        });
                                      }
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xff917dfa),
                              foregroundColor: Colors.white,
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isPublishing
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    'Опубликовать',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showPromotionOptions(
    BuildContext context,
    Function(String, int?) onSelect,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff233040) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  'Свой профиль',
                  style: GoogleFonts.montserrat(color: textColor),
                ),
                onTap: () {
                  onSelect('Свой профиль', null);
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text(
                  'Объявление',
                  style: GoogleFonts.montserrat(color: textColor),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAdSelectionModal(context, onSelect);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAdSelectionModal(
    BuildContext context,
    Function(String, int?) onSelect,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff233040) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputBgColor = isDark ? const Color(0xff151e27) : Colors.grey[100]!;

    final TextEditingController searchController = TextEditingController();
    List<dynamic> ads = [];
    List<dynamic> filteredAds = [];
    bool isLoading = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setBottomSheetState) {
            if (isLoading && ads.isEmpty) {
              Hive.openBox('user').then((box) {
                final token = box.get('auth_token');
                var userId = box.get('user_id');
                if (userId == null) {
                  final user = box.get('user');
                  if (user is Map) {
                    userId = user['id'];
                  }
                }

                if (token != null && userId != null) {
                  final profileApi = ProfileApiRepository();
                  profileApi
                      .getMyAds(token: token, userId: userId, sorting: 'active')
                      .then((result) {
                        setBottomSheetState(() {
                          isLoading = false;
                          if (result['data'] != null) {
                            ads = result['data'] as List;
                            filteredAds = ads;
                            print('✅ [AdSelection] Loaded ${ads.length} ads');
                          }
                        });
                      })
                      .catchError((e) {
                        print('🔴 [AdSelection] Error loading ads: $e');
                        setBottomSheetState(() {
                          isLoading = false;
                        });
                      });
                } else {
                  setBottomSheetState(() {
                    isLoading = false;
                  });
                }
              });
            }

            void filterAds(String query) {
              setBottomSheetState(() {
                if (query.isEmpty) {
                  filteredAds = ads;
                } else {
                  filteredAds = ads.where((ad) {
                    final title = (ad['ads_title'] ?? '')
                        .toString()
                        .toLowerCase();
                    return title.contains(query.toLowerCase());
                  }).toList();
                }
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom +
                    20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Поиск объявлений',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    style: GoogleFonts.montserrat(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Поиск объявлений',
                      hintStyle: GoogleFonts.montserrat(
                        color: isDark ? Colors.white54 : Colors.grey[400],
                      ),
                      filled: true,
                      fillColor: inputBgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                    onChanged: filterAds,
                  ),
                  SizedBox(height: 16),
                  if (isLoading)
                    Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xff917dfa),
                        ),
                      ),
                    )
                  else if (filteredAds.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          searchController.text.isNotEmpty
                              ? 'Ничего не найдено'
                              : 'Нет объявлений',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: ListView.builder(
                        itemCount: filteredAds.length,
                        itemBuilder: (context, index) {
                          final ad = filteredAds[index];
                          final title = ad['ads_title'] ?? '';
                          final adId = ad['ads_id'];

                          return ListTile(
                            title: Text(
                              title,
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: textColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              onSelect(
                                'Объявление: $title',
                                adId is int
                                    ? adId
                                    : int.tryParse(adId?.toString() ?? '0'),
                              );
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showLocationOptions(
    BuildContext context,
    Function(String, int?, int?, int?) onSelect,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff233040) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputBgColor = isDark ? const Color(0xff151e27) : Colors.white;

    final TextEditingController searchController = TextEditingController();
    List<dynamic> locations = [];
    bool isLoading = true;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: bgColor,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setBottomSheetState) {
            if (isLoading && locations.isEmpty) {
              final geoApi = GeoApiRepository();
              geoApi.searchCities(onlyCity: true).then((result) {
                print('🔵 [LocationOptions] Initial load result: $result');
                setBottomSheetState(() {
                  isLoading = false;
                  if (result['status'] == true) {
                    locations = result['data'] as List;
                    print(
                      '✅ [LocationOptions] Loaded ${locations.length} locations',
                    );
                  }
                });
              });
            }

            print(
              '🔵 [LocationOptions] Building UI - isLoading: $isLoading, locations count: ${locations.length}',
            );

            Future<void> searchLocations(String query) async {
              setBottomSheetState(() {
                isLoading = true;
              });

              final geoApi = GeoApiRepository();
              final result = await geoApi.searchCities(
                query: query,
                onlyCity: true,
              );

              setBottomSheetState(() {
                isLoading = false;
                if (result['status'] == true) {
                  locations = result['data'] as List;
                } else {
                  locations = [];
                }
              });
            }

            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom:
                    MediaQuery.of(context).viewInsets.bottom +
                    MediaQuery.of(context).padding.bottom +
                    20,
              ),
              child: Column(
                children: [
                  TextField(
                    controller: searchController,
                    style: GoogleFonts.montserrat(color: textColor),
                    decoration: InputDecoration(
                      hintText: 'Укажите название города',
                      hintStyle: GoogleFonts.montserrat(
                        color: isDark ? Colors.white54 : Colors.grey[400],
                      ),
                      filled: true,
                      fillColor: inputBgColor,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: Icon(
                        Icons.search,
                        color: isDark ? Colors.white54 : Colors.grey[600],
                      ),
                    ),
                    onChanged: (value) {
                      if (value.length >= 2) {
                        searchLocations(value);
                      } else if (value.isEmpty) {
                        setBottomSheetState(() {
                          isLoading = true;
                        });
                        final geoApi = GeoApiRepository();
                        geoApi.searchCities(onlyCity: true).then((result) {
                          setBottomSheetState(() {
                            isLoading = false;
                            if (result['status'] == true) {
                              locations = result['data'] as List;
                            }
                          });
                        });
                      }
                    },
                  ),
                  SizedBox(height: 10),
                  ListTile(
                    title: Text(
                      'Все города',
                      style: GoogleFonts.montserrat(color: textColor),
                    ),
                    onTap: () {
                      onSelect('Все города', null, null, null);
                      Navigator.pop(context);
                    },
                  ),
                  Divider(color: isDark ? Colors.white24 : Colors.grey[300]),
                  if (isLoading)
                    Expanded(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xff917dfa),
                        ),
                      ),
                    )
                  else if (locations.isEmpty)
                    Expanded(
                      child: Center(
                        child: Text(
                          searchController.text.isNotEmpty
                              ? 'Ничего не найдено'
                              : 'Нет доступных городов',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: isDark ? Colors.white70 : Colors.grey,
                          ),
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          print(
                            '🔵 [LocationOptions] Building ListView with ${locations.length} items',
                          );
                          return ListView.builder(
                            itemCount: locations.length,
                            itemBuilder: (context, index) {
                              final location = locations[index];
                              final name =
                                  location['geo_name'] ??
                                  location['city_name'] ??
                                  '';
                              print('🔵 [LocationOptions] Item $index: $name');
                              final cityId = location['city_id'];
                              final regionId = location['region_id'];
                              final countryId = location['country_id'];

                              return ListTile(
                                title: Text(
                                  name,
                                  style: GoogleFonts.montserrat(
                                    color: textColor,
                                  ),
                                ),
                                onTap: () {
                                  onSelect(
                                    name,
                                    cityId is int
                                        ? cityId
                                        : int.tryParse(
                                            cityId?.toString() ?? '0',
                                          ),
                                    regionId is int
                                        ? regionId
                                        : int.tryParse(
                                            regionId?.toString() ?? '0',
                                          ),
                                    countryId is int
                                        ? countryId
                                        : int.tryParse(
                                            countryId?.toString() ?? '0',
                                          ),
                                  );
                                  Navigator.pop(context);
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showCategoryOptions(
    BuildContext context,
    Function(String, int?) onSelect,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff233040) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final inputBgColor = isDark ? const Color(0xff151e27) : Colors.white;

    final TextEditingController searchController = TextEditingController();
    List<dynamic> categories = [];
    List<dynamic> filteredCategories = [];
    bool isLoading = true;
    // ===== Модальное окно все категории =====
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: bgColor,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            padding: const EdgeInsets.all(20),
            child: StatefulBuilder(
              builder: (BuildContext context, StateSetter setDialogState) {
                if (isLoading && categories.isEmpty) {
                  final categoriesApi = CategoriesApiRepository();
                  categoriesApi.getCategories().then((result) {
                    setDialogState(() {
                      isLoading = false;
                      if (result['status'] == true && result['data'] != null) {
                        final data = result['data'];
                        if (data is List) {
                          categories = data;
                          filteredCategories = categories;
                        } else if (data is Map &&
                            data.containsKey('data') &&
                            data['data'] != null) {
                          categories = data['data'] as List;
                          filteredCategories = categories;
                        }
                      }
                    });
                  });
                }

                void filterCategories(String query) {
                  setDialogState(() {
                    if (query.isEmpty) {
                      filteredCategories = categories;
                    } else {
                      filteredCategories = categories.where((cat) {
                        final name = (cat['category_board_name'] ?? '')
                            .toString()
                            .toLowerCase();
                        return name.contains(query.toLowerCase());
                      }).toList();
                    }
                  });
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ===== ВЕРХНЯЯ ЧАСТЬ: ЗАГОЛОВОК + КРЕСТИК =====
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Выберите категорию',
                          style: GoogleFonts.montserrat(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.grey[800]
                                  : Colors.grey[200],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.close,
                              color: textColor,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // ===== СПИСОК КАТЕГОРИЙ =====
                    if (isLoading)
                      Expanded(
                        child: Center(
                          child: CircularProgressIndicator(
                            color: const Color(0xff917dfa),
                          ),
                        ),
                      )
                    else if (filteredCategories.isEmpty)
                      Expanded(
                        child: Center(
                          child: Text(
                            'Категории не найдены',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: isDark ? Colors.white70 : Colors.grey,
                            ),
                          ),
                        ),
                      )
                    else
                      Expanded(
                        child: ListView.builder(
                          itemCount: filteredCategories.length,
                          itemBuilder: (context, index) {
                            final category = filteredCategories[index];
                            final name = category['category_board_name'] ?? '';
                            final catId = category['category_board_id'];

                            return ListTile(
                              title: Text(
                                name,
                                style: GoogleFonts.montserrat(color: textColor),
                              ),
                              onTap: () {
                                onSelect(
                                  name,
                                  catId is int
                                      ? catId
                                      : int.tryParse(catId?.toString() ?? '0'),
                                );
                                Navigator.pop(context);
                              },
                            );
                          },
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSettingItem(
    BuildContext context, {
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey[600];

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: subtitleColor,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.keyboard_arrow_down, color: subtitleColor),
          ],
        ),
      ),
    );
  }

  void _openGalleryForStory(BuildContext context) async {
    final hasPermission = await PermissionService.requestStoragePermission(
      context,
    );
    if (!hasPermission) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null && context.mounted) {
      _showStorySettingsDialog(context, filePath: image.path, isPhoto: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async {
              context.read<FeedBloc>().add(
                FeedCategoryChangeEvent(
                  category: context.read<FeedBloc>().state.category,
                ),
              );
              context.read<StoriesBloc>().add(LoadStories());
              context.read<BannerBloc>().add(LoadBanner());
              await Future.delayed(const Duration(milliseconds: 500));
            },
            color: const Color(0xff917dfa),
            edgeOffset: 120.0,
            displacement: 20.0,
            strokeWidth: 3.0,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  //  верх страницы
                  expandedHeight: 150.0,
                  pinned: true,
                  leading: IconButton(
                    icon: Icon(
                      Icons.grid_view,
                      color: _isCollapsed
                          ? (isDark ? Colors.white : Colors.black)
                          : Colors.white,
                    ),
                    style: ButtonStyle(
                      backgroundColor: WidgetStatePropertyAll(
                        _isCollapsed
                            ? Colors.transparent
                            : const Color.fromRGBO(0, 0, 0, 0.4),
                      ),
                    ),
                    onPressed: () => context.push('/menu'),
                  ),
                  title: SizedBox(
                    height: 40,
                    child: GestureDetector(
                      onTap: () => context.push('/search'),
                      child: AbsorbPointer(
                        child: SearchBar(
                          backgroundColor: WidgetStateProperty.all(
                            _isCollapsed
                                ? (isDark
                                      ? const Color(0xff213140)
                                      : const Color(0xFFF5F7FA))
                                : Colors.white,
                          ),
                          leading: Padding(
                            padding: const EdgeInsets.only(left: 5),
                            child: SvgPicture.asset(
                              'assets/search.svg',
                              height: 16,
                              width: 16,
                              colorFilter: _isCollapsed && isDark
                                  ? const ColorFilter.mode(
                                      Colors.white,
                                      BlendMode.srcIn,
                                    )
                                  : null,
                            ),
                          ),
                          hintText: 'Поиск',
                          hintStyle: WidgetStateProperty.all(
                            GoogleFonts.montserrat(
                              fontSize: 12,
                              color: const Color(0xff999999),
                            ),
                          ),
                          elevation: WidgetStateProperty.all(0.0),
                        ),
                      ),
                    ),
                  ),
                  actions: [
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: _isCollapsed
                            ? Colors.transparent
                            : const Color.fromRGBO(0, 0, 0, 0.4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: GestureDetector(
                        onTap: () async {
                          final result =
                              await Navigator.of(
                                context,
                                rootNavigator: true,
                              ).push<Map<String, dynamic>>(
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
                            final declination =
                                result['declination'] as String?;
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
                              cityDeclination = declination;
                              _filters = _filters.copyWith(
                                cityId: cityId,
                                city: cityName,
                                cityLat: lat,
                                cityLon: lon,
                              );
                              _cityId = cityId;
                              _regionId = null; // ← БЫЛО 0, СТАЛО null
                              _countryId = null; // ← БЫЛО 0, СТАЛО null
                            });
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: _isCollapsed
                                  ? (isDark ? Colors.white : Colors.black)
                                  : Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _wrapCityName(_filters.city ?? 'Все города'),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: _isCollapsed
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  backgroundColor: Theme.of(
                    context,
                  ).appBarTheme.backgroundColor,
                  surfaceTintColor: Colors.transparent,
                  foregroundColor: isDark ? Colors.white : Colors.black,
                  systemOverlayStyle: SystemUiOverlayStyle(
                    statusBarColor: Theme.of(
                      context,
                    ).appBarTheme.backgroundColor,
                    statusBarIconBrightness: isDark
                        ? Brightness.light
                        : Brightness.dark,
                    statusBarBrightness: isDark
                        ? Brightness.dark
                        : Brightness.light,
                  ),
                  flexibleSpace: FlexibleSpaceBar(
                    background: MapMiniature(
                      filters: _filters,
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).push(
                          CupertinoPageRoute(
                            builder: (_) => MapScreen(filters: _filters),
                          ),
                        );
                      },
                      onMarkerTap: (adId) {
                        Navigator.of(context, rootNavigator: true).push(
                          CupertinoPageRoute(
                            builder: (_) =>
                                MapScreen(filters: _filters, initialAdId: adId),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                SliverToBoxAdapter(
                  // контентная часть
                  child: BlocBuilder<CategoriesBloc, CategoriesState>(
                    builder: (context, state) {
                      if (state is CategoriesLoaded) {
                        final categories = state.categories;

                        return Container(
                          height: 160,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ===== СТАТИЧНАЯ КНОПКА "ВСЕ КАТЕГОРИИ" (НЕ СКРОЛЛИТСЯ) =====
                              GestureDetector(
                                onTap: () {
                                  _showCategoryOptions(context, (name, id) {
                                    final filters =
                                        (_filters ?? const SearchFilters())
                                            .copyWith(
                                              categoryId: id,
                                              category: name,
                                            );
                                    context.push('/search', extra: filters);
                                  });
                                },
                                child: SizedBox(
                                  width: 70,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 70,
                                        height: 70,
                                        decoration: BoxDecoration(
                                          color: const Color(0xffF0EEFF),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xff917dfa),
                                            width: 2,
                                          ),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Image.asset(
                                            'assets/all_categories.jpg',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Все категории',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: const Color(0xff917dfa),
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              const SizedBox(width: 10),

                              // ===== ГОРИЗОНТАЛЬНЫЙ СПИСОК КАТЕГОРИЙ (СКРОЛЛИТСЯ) =====
                              Expanded(
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: categories.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(width: 10),
                                  itemBuilder: (context, index) {
                                    final category = categories[index];
                                    return CategoryCard(
                                      width: 70,
                                      imageSize: 70,
                                      uri: category.image ?? '',
                                      name: category.name,
                                      categoryId: category.id,
                                      filters: _filters,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }
                      if (state is CategoriesError) {
                        return Container(
                          height: 160,
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.grey,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Не удалось загрузить категории',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 12,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                SliverToBoxAdapter(
                  child: BlocBuilder<StoriesBloc, StoriesState>(
                    builder: (context, state) {
                      if (state is StoriesLoaded) {
                        return Container(
                          height: 95,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            itemCount: state.users.length + 1,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              if (index == 0) {
                                return BlocBuilder<AuthBloc, AuthState>(
                                  builder: (context, authState) {
                                    if (!_checkStoriesPermission(authState))
                                      return const SizedBox.shrink();
                                    return GestureDetector(
                                      onTap: () =>
                                          _openGalleryForStory(context),
                                      child: SizedBox(
                                        width: 80,
                                        child: Column(
                                          children: [
                                            Container(
                                              width: 80,
                                              height: 80,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: isDark
                                                      ? Colors.grey[700]!
                                                      : Colors.grey[300]!,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Stack(
                                                children: [
                                                  Center(
                                                    child: Container(
                                                      width: 76,
                                                      height: 76,
                                                      decoration: BoxDecoration(
                                                        shape: BoxShape.circle,
                                                        color: isDark
                                                            ? const Color(
                                                                0xff233040,
                                                              )
                                                            : Colors.grey[200],
                                                      ),
                                                      child: Icon(
                                                        Icons.camera_alt,
                                                        size: 35,
                                                        color: isDark
                                                            ? Colors.grey[400]
                                                            : Colors.grey[600],
                                                      ),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    bottom: 0,
                                                    right: 0,
                                                    child: Container(
                                                      width: 24,
                                                      height: 24,
                                                      decoration:
                                                          const BoxDecoration(
                                                            shape:
                                                                BoxShape.circle,
                                                            color: Color(
                                                              0xff917dfa,
                                                            ),
                                                          ),
                                                      child: const Icon(
                                                        Icons.add,
                                                        size: 16,
                                                        color: Colors.white,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }
                              final userIndex = index - 1;
                              final user = state.users[userIndex];
                              final userName = user['name'] ?? 'Пользователь';
                              final avatar = ApiConfig.replaceMediaUrl(
                                user['avatar']?.toString() ?? '',
                              );
                              final stories = user['stories'] as List? ?? [];
                              final hasUnviewed = stories.any(
                                (s) => s['status'] == 1,
                              );

                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  ).push(
                                    createSwipeableRoute(
                                      builder: (_) => StoryViewerScreen(
                                        allUsers: state.users,
                                        initialUserIndex: userIndex,
                                      ),
                                    ),
                                  );
                                },
                                child: SizedBox(
                                  width: 80,
                                  child: Column(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        children: [
                                          Container(
                                            width: 80,
                                            height: 80,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: hasUnviewed
                                                    ? Colors.orange
                                                    : Colors.grey,
                                                width: 2,
                                              ),
                                            ),
                                            child: ClipOval(
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  color: isDark
                                                      ? const Color(0xff233040)
                                                      : Colors.grey[300],
                                                  image: avatar.isNotEmpty
                                                      ? DecorationImage(
                                                          image: NetworkImage(
                                                            avatar,
                                                          ),
                                                          fit: BoxFit.cover,
                                                        )
                                                      : null,
                                                ),
                                                child: avatar.isEmpty
                                                    ? Icon(
                                                        Icons.person,
                                                        size: 35,
                                                        color: isDark
                                                            ? Colors.grey[400]
                                                            : Colors.grey[600],
                                                      )
                                                    : null,
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            left: 0,
                                            right: 0,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 3,
                                                    horizontal: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withOpacity(
                                                  0.85,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              child: Text(
                                                userName,
                                                style: GoogleFonts.montserrat(
                                                  fontSize: 9,
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      }
                      if (state is StoriesError) {
                        return Container(
                          height: 80,
                          margin: const EdgeInsets.symmetric(horizontal: 20),
                          child: Center(
                            child: Text(
                              'Ошибка загрузки историй',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
                const SliverToBoxAdapter(child: _InfoBannersCarousel()),
                const SliverToBoxAdapter(child: SizedBox(height: 15)),
                Feed(
                  scrollController: _scrollController,
                  cityId: _cityId,
                  regionId: _regionId,
                  countryId: _countryId,
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
                // 🔥 КНОПКА ДИАГНОСТИКИ
                SliverToBoxAdapter(
                  child: Container(
                    height: 60,
                    alignment: Alignment.center,
                    child: ElevatedButton(
                      onPressed: () => context.go('/diagnostic'),
                      child: Text('🔍 Диагностика'),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(top: 16, bottom: 16),
                    child: AppFooter(), // футер
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top + 10,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedOpacity(
                opacity: _showScrollToTop ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOutCubic,
                child: IgnorePointer(
                  ignoring: !_showScrollToTop,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        _scrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      borderRadius: BorderRadius.circular(20),
                      splashColor: Colors.white.withOpacity(0.2),
                      highlightColor: Colors.white.withOpacity(0.1),
                      child: Ink(
                        width: 140,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xff917dfa),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.keyboard_arrow_up,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Наверх',
                              style: GoogleFonts.montserrat(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
}

class _VideoPreview extends StatefulWidget {
  final String filePath;

  const _VideoPreview({required this.filePath});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  NativeVideoPlayerController? _controller;
  StreamSubscription<void>? _eventsSubscription;
  bool _isReady = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void dispose() {
    _eventsSubscription?.cancel();
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  void _onViewReady(NativeVideoPlayerController controller) async {
    _controller = controller;

    _eventsSubscription = controller.events.listen((event) {
      print('🔵 [VideoPreview] Event: ${event.runtimeType}');

      switch (event) {
        case PlaybackReadyEvent():
          print(
            '✅ [VideoPreview] Video ready - ${controller.videoInfo?.width}x${controller.videoInfo?.height}, duration: ${controller.videoInfo?.duration}',
          );
          if (mounted) {
            setState(() {
              _isReady = true;
              _hasError = false;
            });
          }
          controller.play();
          break;

        case PlaybackEndedEvent():
          print('🔵 [VideoPreview] Playback ended, restarting...');
          controller.stop();
          controller.play();
          break;

        case PlaybackErrorEvent():
          print('🔴 [VideoPreview] Playback error: ${event.errorMessage}');
          if (mounted) {
            setState(() {
              _hasError = true;
              _errorMessage = event.errorMessage;
            });
          }
          break;

        case PlaybackStatusChangedEvent():
          print(
            '🔵 [VideoPreview] Status changed: ${controller.playbackStatus}',
          );
          break;

        default:
          break;
      }
    });

    try {
      print('🔵 [VideoPreview] Loading video from: ${widget.filePath}');

      await controller
          .loadVideo(
            VideoSource(path: widget.filePath, type: VideoSourceType.file),
          )
          .timeout(
            Duration(seconds: 10),
            onTimeout: () {
              print('🔴 [VideoPreview] Video loading timeout');
              if (mounted) {
                setState(() {
                  _hasError = true;
                  _errorMessage = 'Не удалось загрузить видео (таймаут)';
                });
              }
            },
          );
    } catch (e) {
      print('🔴 [VideoPreview] Error loading video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.videocam, size: 100, color: Colors.white54),
          SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Видео выбрано',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Предпросмотр недоступен на этом устройстве',
              style: GoogleFonts.montserrat(
                fontSize: 12,
                color: Colors.white70,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (_errorMessage != null) ...[
            SizedBox(height: 8),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                style: GoogleFonts.montserrat(
                  fontSize: 10,
                  color: Colors.white38,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ],
      );
    }

    return Stack(
      children: [
        NativeVideoPlayerView(onViewReady: _onViewReady),
        if (!_isReady)
          Center(child: CircularProgressIndicator(color: Colors.white)),
      ],
    );
  }
}

class _InfoBannersCarousel extends StatefulWidget {
  const _InfoBannersCarousel();

  @override
  State<_InfoBannersCarousel> createState() => _InfoBannersCarouselState();
}

class _InfoBannersCarouselState extends State<_InfoBannersCarousel> {
  final PageController _pageController = PageController();
  final HomeApiRepository _homeApi = HomeApiRepository(DioClient.createDio());
  int _currentPage = 0;
  List<Map<String, dynamic>> _sliders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSliders();
  }

  Future<void> _loadSliders() async {
    try {
      final sliders = await _homeApi.getInfoBanners();
      if (mounted) {
        setState(() {
          _sliders = sliders;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('🔴 [PromoSliders] Error loading sliders: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xff917dfa)),
        ),
      );
    }

    if (_sliders.isEmpty) {
      return const SizedBox.shrink();
    }

    return AspectRatio(
      aspectRatio: 16 / 7,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 15),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemCount: _sliders.length,
              itemBuilder: (context, index) {
                final slider = _sliders[index];
                final image = slider['image'] as String? ?? '';
                final link = slider['link'] as String? ?? '';
                final colorBg = slider['color_bg'] as String? ?? '#ffffff';

                return GestureDetector(
                  onTap: () {
                    if (link.isNotEmpty) {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (context) =>
                              WebViewScreen(url: link, title: ''),
                        ),
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: _parseColor(colorBg),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Image.network(
                      image,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: _parseColor(colorBg),
                          child: Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                        loadingProgress.expectedTotalBytes!
                                  : null,
                              color: const Color(0xff917dfa),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        print(
                          '🔴 [PromoSlider] Error loading image: $image, error: $error',
                        );
                        return Container(
                          color: _parseColor(colorBg),
                          child: Center(
                            child: Icon(
                              Icons.image_not_supported,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _sliders.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 20 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index
                          ? const Color(0xff917dfa)
                          : Colors.grey.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(4),
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

  Color _parseColor(String colorString) {
    try {
      String hexColor = colorString.replaceAll('#', '');
      if (hexColor.length == 6) {
        hexColor = 'FF$hexColor';
      }
      return Color(int.parse(hexColor, radix: 16));
    } catch (e) {
      print('🔴 [PromoSlider] Error parsing color: $colorString, error: $e');
      return Colors.white;
    }
  }
}
