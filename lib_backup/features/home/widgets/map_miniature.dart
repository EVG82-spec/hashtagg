import 'dart:ui' as ui;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:hashtagg/core/network/catalog_api_repository.dart';
import 'package:hashtagg/core/network/home_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/features/search/screens/search_filters_screen.dart';

class MapMiniature extends StatefulWidget {
  final SearchFilters filters;
  final VoidCallback onTap;
  final Function(int adId)? onMarkerTap;

  const MapMiniature({
    super.key,
    required this.filters,
    required this.onTap,
    this.onMarkerTap,
  });

  @override
  State<MapMiniature> createState() => _MapMiniatureState();
}

class _MapMiniatureState extends State<MapMiniature> {
  YandexMapController? _mapController;
  final List<MapObject> _mapObjects = [];
  final CatalogApiRepository _catalogApi = CatalogApiRepository(DioClient.createDio());
  List<FeedAd> _listings = [];
  bool _isLoading = true;
  int? _tappedAdId;

  static const _defaultTarget = Point(latitude: 55.7558, longitude: 37.6173);
  static const _defaultZoom = 12.0;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  @override
  void didUpdateWidget(MapMiniature oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.filters.cityId != widget.filters.cityId ||
        oldWidget.filters.categoryId != widget.filters.categoryId) {
      _loadListings();
      
      if (_mapController != null &&
          (oldWidget.filters.cityLat != widget.filters.cityLat ||
           oldWidget.filters.cityLon != widget.filters.cityLon)) {
        _moveCameraToCity();
      }
    }
  }

  Future<void> _loadListings() async {
    setState(() => _isLoading = true);
    
    try {
      print('🔵 [MapMiniature] Loading listings with filters');
      
      var result = await _catalogApi.getAds(
        CatalogSearchParams(
          search: '',
          cityId: widget.filters.cityId,
          categoryId: widget.filters.categoryId,
          page: 1,
        ),
      );
      
      if (!result.success || result.data == null) {
        throw Exception(result.error ?? 'Failed to load listings');
      }
      
      var data = result.data!['data'] as List;
      final allAds = data.map((json) => FeedAd.fromJson(json)).toList();
      
      final adsWithCoords = allAds.where((ad) => 
        ad.latitude != null && 
        ad.longitude != null &&
        ad.latitude != 0 &&
        ad.longitude != 0
      ).toList();
      
      print('✅ [MapMiniature] Loaded ${adsWithCoords.length} ads with coordinates');
      
      _listings = adsWithCoords;
      
      setState(() => _isLoading = false);
      
      if (_mapController != null) {
        await _buildPlacemarks();
      }
    } catch (e) {
      print('🔴 [MapMiniature] Error loading listings: $e');
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _moveCameraToCity() async {
    if (_mapController == null) return;
    
    Point targetPoint;
    double zoom;
    
    if (widget.filters.cityLat != null && 
        widget.filters.cityLon != null &&
        widget.filters.cityLat != 0.0 && 
        widget.filters.cityLon != 0.0) {
      targetPoint = Point(
        latitude: widget.filters.cityLat!,
        longitude: widget.filters.cityLon!,
      );
      zoom = 12.0;
      print('🗺️ [MapMiniature] Moving camera to city: ${widget.filters.cityLat}, ${widget.filters.cityLon}');
    } else {
      targetPoint = _defaultTarget;
      zoom = _defaultZoom;
      print('🗺️ [MapMiniature] Moving camera to default coordinates (Moscow)');
    }
    
    await _mapController!.moveCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: targetPoint,
          zoom: zoom,
        ),
      ),
    );
  }

  Future<void> _buildPlacemarks() async {
    try {
      final listings = _listings;
      if (listings.isEmpty) {
        print('⚠️ [MapMiniature] No listings to display on map');
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
              scale: 0.7,
              anchor: const Offset(0.5, 1.0),
            ),
          ),
          consumeTapEvents: true,
          onTap: (_, __) {
            setState(() => _tappedAdId = listing.id);
            widget.onMarkerTap?.call(listing.id);
          },
        );
        placemarks.add(placemark);
      }

      if (mounted) {
        setState(() {
          _mapObjects
            ..clear()
            ..addAll(placemarks);
        });
      }
      
      print('✅ [MapMiniature] Built ${placemarks.length} placemarks');
    } catch (e, st) {
      debugPrint('🔴 [MapMiniature] _buildPlacemarks error: $e\n$st');
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

  Future<Uint8List> _buildPriceBubble(FeedAd listing) async {
    final priceInt = int.tryParse(listing.price.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    final priceText = priceInt > 0
        ? '${_formatPrice(priceInt)} ₽'
        : listing.title;

    const bubbleColor = Color(0xff917dfa);
    const bgColor = Colors.white;

    const paddingH = 18.0;
    const paddingV = 9.0;
    const tailHeight = 9.0;
    const radius = 18.0;
    const fontSize = 22.0;

    final textPainter = TextPainter(
      text: TextSpan(
        text: priceText,
        style: GoogleFonts.montserrat(
          color: bubbleColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    const stroke = 2.5;
    const pad = stroke;

    final bubbleW = textPainter.width + paddingH * 2;
    final bubbleH = textPainter.height + paddingV * 2;
    final totalH = bubbleH + tailHeight;
    final canvasW = bubbleW + pad * 2;
    final canvasH = totalH + pad;

    return _renderToPng(
      (canvas) {
        canvas.translate(pad, pad);

        final fillPaint = Paint()
          ..color = bgColor
          ..isAntiAlias = true;

        final strokePaint = Paint()
          ..color = bubbleColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..isAntiAlias = true;

        final bubblePath = Path()
          ..addRRect(RRect.fromRectAndRadius(
            Rect.fromLTWH(0, 0, bubbleW, bubbleH),
            const Radius.circular(radius),
          ));

        final tailPath = Path()
          ..moveTo(bubbleW / 2 - 6, bubbleH)
          ..lineTo(bubbleW / 2 + 6, bubbleH)
          ..lineTo(bubbleW / 2, totalH)
          ..close();

        final combinedPath = Path.combine(PathOperation.union, bubblePath, tailPath);

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(20),
            ),
            child: YandexMap(
              mapObjects: _mapObjects,
              nightModeEnabled: isDark,
              onMapCreated: (controller) async {
                _mapController = controller;
                
                Point targetPoint;
                double zoom;
                
                if (widget.filters.cityLat != null && 
                    widget.filters.cityLon != null &&
                    widget.filters.cityLat != 0.0 && 
                    widget.filters.cityLon != 0.0) {
                  targetPoint = Point(
                    latitude: widget.filters.cityLat!,
                    longitude: widget.filters.cityLon!,
                  );
                  zoom = 12.0;
                  print('🗺️ [MapMiniature] Using city coordinates: ${widget.filters.cityLat}, ${widget.filters.cityLon}');
                } else {
                  targetPoint = _defaultTarget;
                  zoom = _defaultZoom;
                  print('🗺️ [MapMiniature] Using default coordinates (Moscow)');
                }
                
                await _mapController!.moveCamera(
                  CameraUpdate.newCameraPosition(
                    CameraPosition(
                      target: targetPoint,
                      zoom: zoom,
                    ),
                  ),
                );
                
                if (_listings.isNotEmpty) {
                  await _buildPlacemarks();
                }
              },
              onMapTap: (point) {
                widget.onTap();
              },
            ),
          ),
          
          if (_isLoading)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
              ),
            ),
          
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.map_outlined,
                    color: Colors.white,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Открыть карту',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
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