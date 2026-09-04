//G:\hashtagg_app\lib\features\search\screens\map_screen.dart
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';

import 'package:hashtagg/core/network/catalog_api_repository.dart';
import 'package:hashtagg/core/network/home_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hashtagg/core/services/permission_service.dart';
import 'search_filters_screen.dart';

class MapScreen extends StatefulWidget {
  final SearchFilters filters;
  final int? initialAdId;

  const MapScreen({
    super.key,
    this.filters = const SearchFilters(),
    this.initialAdId,
  });

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late YandexMapController _mapController;
  final List<MapObject> _mapObjects = [];
  FeedAd? _selectedListing;
  static const _clusterizedId = MapObjectId('clusterized_collection');

  // Центр России по умолчанию (Москва)
  static const _defaultTarget = Point(latitude: 55.7558, longitude: 37.6173);
  static const _defaultZoom = 12.0;

  final CatalogApiRepository _catalogApi = CatalogApiRepository(
    DioClient.createDio(),
  );
  List<FeedAd> _listings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _requestLocationPermissionAndLoad();
  }

  Future<void> _requestLocationPermissionAndLoad() async {
    // Запрашиваем разрешение на геолокацию
    final hasPermission = await PermissionService.requestLocationPermission(
      context,
    );
    if (!hasPermission) {
      // Если разрешение не предоставлено, все равно загружаем объявления
      print(
        '⚠️ [MapScreen] Location permission denied, loading listings anyway',
      );
    }
    _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() => _isLoading = true);

    try {
      print('🔵 [MapScreen] Loading listings with filters');

      List<FeedAd> allAds = [];
      int currentPage = 1;
      int totalCount = 0;

      // Загружаем первую страницу
      print('🔵 [MapScreen] Loading page $currentPage...');
      var result = await _catalogApi.getAds(
        CatalogSearchParams(
          search: '',
          cityId: widget.filters.cityId,
          categoryId: widget.filters.categoryId,
          priceStart: widget.filters.priceFrom?.toDouble(),
          priceEnd: widget.filters.priceTo?.toDouble(),
          vip: widget.filters.options['vip'],
          secure: widget.filters.options['secure'],
          onlineView: widget.filters.options['online_view'],
          auction: widget.filters.options['auction'],
          booking: widget.filters.options['booking'],
          filters: widget.filters.filters,
          page: currentPage,
        ),
      );

      if (!result.success || result.data == null) {
        throw Exception(result.error ?? 'Failed to load listings');
      }

      // Получаем общее количество (может быть String или int)
      final countValue = result.data!['count'];
      print(
        '🔵 [MapScreen] Count value: $countValue (type: ${countValue.runtimeType})',
      );

      if (countValue is int) {
        totalCount = countValue;
      } else if (countValue is String) {
        // Извлекаем число из строки типа "49 объявлений"
        final match = RegExp(r'(\d+)').firstMatch(countValue);
        totalCount = match != null ? int.parse(match.group(1)!) : 0;
      } else {
        totalCount = 0;
      }

      var data = result.data!['data'] as List;
      allAds.addAll(data.map((json) => FeedAd.fromJson(json)).toList());

      print(
        '✅ [MapScreen] Page 1: loaded ${data.length} ads, total count: $totalCount, loaded so far: ${allAds.length}',
      );

      // Загружаем остальные страницы, если есть
      int maxPages = 10; // Защита от бесконечного цикла
      int pageCount = 1;

      while (allAds.length < totalCount && pageCount < maxPages) {
        currentPage++;
        pageCount++;

        print(
          '🔵 [MapScreen] Loading page $currentPage... (loaded: ${allAds.length}/$totalCount)',
        );

        result = await _catalogApi.getAds(
          CatalogSearchParams(
            search: '',
            cityId: widget.filters.cityId,
            categoryId: widget.filters.categoryId,
            priceStart: widget.filters.priceFrom?.toDouble(),
            priceEnd: widget.filters.priceTo?.toDouble(),
            vip: widget.filters.options['vip'],
            secure: widget.filters.options['secure'],
            onlineView: widget.filters.options['online_view'],
            auction: widget.filters.options['auction'],
            booking: widget.filters.options['booking'],
            filters: widget.filters.filters,
            page: currentPage,
          ),
        );

        if (!result.success || result.data == null) {
          print(
            '⚠️ [MapScreen] Failed to load page $currentPage: ${result.error}',
          );
          break;
        }

        data = result.data!['data'] as List;
        if (data.isEmpty) {
          print('⚠️ [MapScreen] Page $currentPage is empty, stopping');
          break;
        }

        allAds.addAll(data.map((json) => FeedAd.fromJson(json)).toList());
        print(
          '✅ [MapScreen] Page $currentPage: loaded ${data.length} ads, total loaded: ${allAds.length}/$totalCount',
        );
      }

      print('🔵 [MapScreen] Finished loading. Total ads: ${allAds.length}');

      // Фильтруем только объявления с координатами
      final adsWithCoords = allAds
          .where(
            (ad) =>
                ad.latitude != null &&
                ad.longitude != null &&
                ad.latitude != 0 &&
                ad.longitude != 0,
          )
          .toList();

      final adsWithoutCoords = allAds.length - adsWithCoords.length;

      print(
        '✅ [MapScreen] Total: ${allAds.length} ads, with coordinates: ${adsWithCoords.length}, without: $adsWithoutCoords',
      );

      _listings = adsWithCoords;

      setState(() => _isLoading = false);

      // Строим метки после загрузки
      await _buildPlacemarks();

      // Если передан initialAdId, открываем это объявление
      if (widget.initialAdId != null) {
        final ad = _listings.firstWhere(
          (ad) => ad.id == widget.initialAdId,
          orElse: () => _listings.first,
        );
        if (mounted) {
          setState(() => _selectedListing = ad);
        }
      }
    } catch (e, stackTrace) {
      print('🔴 [MapScreen] Error loading listings: $e');
      print('🔴 [MapScreen] Stack trace: $stackTrace');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки объявлений: $e')),
        );
      }
    }
  }

  Future<void> _buildPlacemarks() async {
    try {
      final listings = _listings;
      if (listings.isEmpty) {
        print('⚠️ [MapScreen] No listings to display on map');
        return;
      }

      final placemarks = <PlacemarkMapObject>[];

      for (final listing in listings) {
        final image = await _buildPriceBubble(listing);
        final placemark = PlacemarkMapObject(
          mapId: MapObjectId('listing_${listing.id}'),
          opacity: 1,
          point: Point(
            latitude: listing.latitude!,
            longitude: listing.longitude!,
          ),
          icon: PlacemarkIcon.single(
            PlacemarkIconStyle(
              image: BitmapDescriptor.fromBytes(image),
              scale: 1.0,
              anchor: const Offset(0.5, 1.0),
            ),
          ),
          consumeTapEvents: true,
          onTap: (_, __) {
            setState(() => _selectedListing = listing);
          },
        );
        placemarks.add(placemark);
      }

      final collection = ClusterizedPlacemarkCollection(
        mapId: _clusterizedId,
        placemarks: placemarks,
        radius: 60,
        minZoom: 15,
        consumeTapEvents: true,
        onClusterAdded: (self, cluster) async {
          final image = await _buildClusterIcon(cluster.size);
          return cluster.copyWith(
            appearance: cluster.appearance.copyWith(
              opacity: 1.0,
              icon: PlacemarkIcon.single(
                PlacemarkIconStyle(
                  image: BitmapDescriptor.fromBytes(image),
                  scale: 1.0,
                  anchor: const Offset(0.5, 0.5),
                ),
              ),
            ),
          );
        },
        onClusterTap: (self, cluster) {
          final listings = cluster.placemarks
              .map(
                (p) => _listings.firstWhere(
                  (l) => MapObjectId('listing_${l.id}') == p.mapId,
                  orElse: () => _listings.first,
                ),
              )
              .toList();
          _showClusterBottomSheet(listings);
        },
      );

      setState(() {
        _mapObjects
          ..clear()
          ..add(collection);
      });

      print('✅ [MapScreen] Built ${placemarks.length} placemarks');
    } catch (e, st) {
      debugPrint('🔴 [MapScreen] _buildPlacemarks error: $e\n$st');
    }
  }

  Future<Uint8List> _renderToPng(
    void Function(Canvas canvas) draw,
    int width,
    int height,
  ) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(
      pictureRecorder,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    );
    draw(canvas);
    final picture = pictureRecorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _buildClusterIcon(int count) async {
    const size = 80;
    const bgColor = Color(0xff917dfa);

    return _renderToPng(
      (canvas) {
        canvas.drawCircle(
          const Offset(size / 2, size / 2),
          size / 2,
          Paint()..color = bgColor,
        );

        canvas.drawCircle(
          const Offset(size / 2, size / 2),
          size / 2 - 2,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );

        final textPainter = TextPainter(
          text: TextSpan(
            text: count > 99 ? '99+' : '$count',
            style: GoogleFonts.montserrat(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            size / 2 - textPainter.width / 2,
            size / 2 - textPainter.height / 2,
          ),
        );
      },
      size,
      size,
    );
  }

  Future<Uint8List> _buildPriceBubble(FeedAd listing) async {
    final isSelected = _selectedListing?.id == listing.id;
    // price это String, парсим его для проверки
    final priceInt =
        int.tryParse(listing.price.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    final priceText = priceInt > 0
        ? '${_formatPrice(priceInt)} ₽'
        : listing.title;

    const bubbleColor = Color(0xff917dfa);
    const selectedColor = Color(0xff6a52e8);
    const bgColor = Colors.white;

    const paddingH = 25.0;
    const paddingV = 12.5;
    const tailHeight = 12.5;
    const radius = 25.0;
    const fontSize = 30.0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: priceText,
        style: GoogleFonts.montserrat(
          color: isSelected ? bgColor : bubbleColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    const stroke = 3.5;
    const pad = stroke; // отступ со всех сторон чтобы обводка не обрезалась

    final bubbleW = textPainter.width + paddingH * 2;
    final bubbleH = textPainter.height + paddingV * 2;
    final totalH = bubbleH + tailHeight;
    final canvasW = bubbleW + pad * 2;
    final canvasH = totalH + pad;

    return _renderToPng(
      (canvas) {
        // Смещаем всё на pad чтобы обводка не обрезалась по краям
        canvas.translate(pad, pad);

        final fillPaint = Paint()
          ..color = isSelected ? selectedColor : bgColor
          ..isAntiAlias = true;

        final strokePaint = Paint()
          ..color = bubbleColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..isAntiAlias = true;

        final bubblePath = Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(0, 0, bubbleW, bubbleH),
              const Radius.circular(radius),
            ),
          );

        final tailPath = Path()
          ..moveTo(bubbleW / 2 - 8, bubbleH)
          ..lineTo(bubbleW / 2 + 8, bubbleH)
          ..lineTo(bubbleW / 2, totalH)
          ..close();

        final combinedPath = Path.combine(
          PathOperation.union,
          bubblePath,
          tailPath,
        );

        canvas.drawPath(combinedPath, fillPaint);
        canvas.drawPath(combinedPath, strokePaint);

        textPainter.paint(canvas, Offset(paddingH, paddingV));
      },
      canvasW.ceil(),
      canvasH.ceil(),
    );
  }

  String _formatPrice(int price) {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(price % 1000000 == 0 ? 0 : 1)} млн';
    } else if (price >= 1000) {
      final k = price ~/ 1000;
      final rem = price % 1000;
      return rem == 0 ? '${k} тыс' : '${(price / 1000).toStringAsFixed(1)} тыс';
    }
    return price.toString();
  }

  String _pluralListings(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 19) return 'объявлений';
    if (mod10 == 1) return 'объявление';
    if (mod10 >= 2 && mod10 <= 4) return 'объявления';
    return 'объявлений';
  }

  void _showClusterBottomSheet(List<FeedAd> listings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return SafeArea(
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xffE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Заголовок
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Text(
                      '${listings.length} ${_pluralListings(listings.length)}',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Список
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: listings.length,
                      itemBuilder: (context, index) {
                        final listing = listings[index];
                        return _ClusterListingRow(
                          listing: listing,
                          onTap: () {
                            Navigator.pop(context);
                            context.push('/listing/${listing.id}');
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

  void _openFilters() async {
    final result = await Navigator.push<SearchFilters>(
      context,
      createSwipeableRoute(
        builder: (_) => SearchFiltersScreen(initial: widget.filters),
      ),
    );
    if (result != null && mounted) {
      // Rebuild with new filters by pushing replacement
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => MapScreen(filters: result)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff151e27) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.tune, color: textColor),
            onPressed: _openFilters,
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Яндекс карта ──────────────────────────────────────────────
          Positioned.fill(
            child: YandexMap(
              mapObjects: _mapObjects,
              nightModeEnabled: isDark,
              onMapCreated: (controller) async {
                _mapController = controller;

                // Определяем начальную позицию карты
                Point targetPoint;
                double zoom;

                // Проверяем координаты города (не null и не 0.0)
                if (widget.filters.cityLat != null &&
                    widget.filters.cityLon != null &&
                    widget.filters.cityLat != 0.0 &&
                    widget.filters.cityLon != 0.0) {
                  // Используем координаты выбранного города
                  targetPoint = Point(
                    latitude: widget.filters.cityLat!,
                    longitude: widget.filters.cityLon!,
                  );
                  zoom = 12.0;
                  print(
                    '🗺️ [MapScreen] Using city coordinates: ${widget.filters.cityLat}, ${widget.filters.cityLon}',
                  );
                } else {
                  // Используем координаты по умолчанию (Москва)
                  targetPoint = _defaultTarget;
                  zoom = _defaultZoom;
                  print('🗺️ [MapScreen] Using default coordinates (Moscow)');
                }

                await _mapController.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(target: targetPoint, zoom: zoom),
                  ),
                );
              },
              onCameraPositionChanged: (position, reason, finished) {},
              onMapTap: (point) {
                if (_selectedListing != null) {
                  setState(() => _selectedListing = null);
                }
              },
            ),
          ),

          // ── Индикатор загрузки ────────────────────────────────────────
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.white.withOpacity(0.8),
                child: const Center(
                  child: CircularProgressIndicator(color: Color(0xff917dfa)),
                ),
              ),
            ),

          // ── Карточка выбранного объявления ────────────────────────────
          if (_selectedListing != null)
            Positioned(
              bottom: 32,
              left: 16,
              right: 16,
              child: _ListingPreviewCard(
                listing: _selectedListing!,
                onClose: () => setState(() => _selectedListing = null),
                onTap: () => context.push('/listing/${_selectedListing!.id}'),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Строка объявления в bottom sheet кластера ───────────────────────────────
class _ClusterListingRow extends StatelessWidget {
  final FeedAd listing;
  final VoidCallback onTap;

  const _ClusterListingRow({required this.listing, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final imageUrl = listing.images.isNotEmpty ? listing.images.first : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Фото
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: imageUrl != null
                  ? Image.network(
                      imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 100,
                        height: 100,
                        color: const Color(0xffF5F7FA),
                        child: const Icon(
                          Icons.image_outlined,
                          color: Color(0xffcccccc),
                          size: 36,
                        ),
                      ),
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: const Color(0xffF5F7FA),
                      child: const Icon(
                        Icons.image_outlined,
                        color: Color(0xffcccccc),
                        size: 36,
                      ),
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 6),
                  if (listing.price.isNotEmpty)
                    Text(
                      listing.price,
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                  const SizedBox(height: 4),
                  if (listing.cityName.isNotEmpty)
                    Text(
                      listing.cityName,
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: const Color(0xff808080),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Кнопка поверх карты ─────────────────────────────────────────────────────
class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.black, size: 22),
      ),
    );
  }
}

// ── Карточка предпросмотра объявления ───────────────────────────────────────
class _ListingPreviewCard extends StatelessWidget {
  final FeedAd listing;
  final VoidCallback onClose;
  final VoidCallback onTap;

  const _ListingPreviewCard({
    required this.listing,
    required this.onClose,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = listing.images.isNotEmpty ? listing.images.first : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Фото
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(12),
              ),
              child: imageUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        imageUrl,
                        width: 64,
                        height: 64,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.image_outlined,
                          color: Color(0xffcccccc),
                          size: 32,
                        ),
                      ),
                    )
                  : const Icon(
                      Icons.image_outlined,
                      color: Color(0xffcccccc),
                      size: 32,
                    ),
            ),
            const SizedBox(width: 12),
            // Информация
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    listing.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (listing.price.isNotEmpty)
                    Text(
                      listing.price,
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff917dfa),
                      ),
                    ),
                  if (listing.cityName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        listing.cityName,
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          color: const Color(0xff808080),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Кнопка закрыть
            GestureDetector(
              onTap: onClose,
              child: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: Color(0xff808080),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
