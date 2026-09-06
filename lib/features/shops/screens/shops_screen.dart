import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/core/network/shops_api_repository.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/features/shop/screens/shop_webview_screen.dart';
import 'package:hive/hive.dart';

class ShopsScreen extends StatefulWidget {
  const ShopsScreen({super.key});

  @override
  State<ShopsScreen> createState() => _ShopsScreenState();
}

class _ShopsScreenState extends State<ShopsScreen> {
  final ShopsApiRepository _shopsApi = ShopsApiRepository();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _shops = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _totalPages = 1;
  int _extractCountAds(dynamic countAds) {
    if (countAds is int) return countAds;
    if (countAds is String) {
      final match = RegExp(r'\d+').firstMatch(countAds);
      if (match != null) {
        return int.tryParse(match.group(0)!) ?? 0;
      }
    }
    return 0;
  }

  String _pluralize(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'объявление';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100))
      return 'объявления';
    return 'объявлений';
  }

  @override
  void initState() {
    super.initState();
    _loadShops();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoading && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadShops() async {
    print('🔴🔴🔴 [ShopsScreen] _loadShops() CALLED!');
    if (_isLoading) return;

    setState(() => _isLoading = true);

    try {
      print('🔴🔴🔴 [ShopsScreen] Calling _shopsApi.getShops()...');
      final result = await _shopsApi.getShops(page: 1);
      print('🔴🔴🔴 [ShopsScreen] Result: $result');

      if (result['status'] == true && mounted) {
        final data = result['data'];
        final allShops = List<Map<String, dynamic>>.from(data['data'] ?? []);

        // ✅ ФИЛЬТР: НЕ ПОКАЗЫВАТЬ ПУСТЫЕ МАГАЗИНЫ ДЛЯ ГОСТЕЙ
        final box = await Hive.openBox('user');
        final userData = box.get('user');
        final userId = userData is Map ? userData['id'] : null;

        final filteredShops = userId != null
            ? allShops // Владелец видит все свои магазины
            : allShops.where((shop) {
                final count = _extractCountAds(shop['count_ads']);
                return count > 0;
              }).toList();

        setState(() {
          _shops = filteredShops;
          _totalPages = data['pages'] ?? 1;
          _currentPage = 1;
          _hasMore = _currentPage < _totalPages;
        });

        print(
          '✅ [ShopsScreen] Filtered: ${_shops.length} shops (of ${allShops.length})',
        );
      }
    } catch (e) {
      print('🔴 [ShopsScreen] Error loading shops: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final nextPage = _currentPage + 1;
      final result = await _shopsApi.getShops(page: nextPage);

      if (result['status'] == true && mounted) {
        final data = result['data'];
        final newShops = List<Map<String, dynamic>>.from(data['data'] ?? []);

        setState(() {
          _shops.addAll(newShops);
          _currentPage = nextPage;
          _hasMore = _currentPage < _totalPages;
        });
      }
    } catch (e) {
      print('🔴 [ShopsScreen] Error loading more: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: _shops.isEmpty && _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xff917dfa)))
          : RefreshIndicator(
              onRefresh: _loadShops,
              color: Color(0xff917dfa),
              edgeOffset: 40.0,
              displacement: 20.0,
              strokeWidth: 3.0,
              child: ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.all(16),
                itemCount: _shops.length + (_hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _shops.length) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          color: Color(0xff917dfa),
                        ),
                      ),
                    );
                  }

                  final shop = _shops[index];
                  return _ShopCard(shop: shop);
                },
              ),
            ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final Map<String, dynamic> shop;

  const _ShopCard({required this.shop});

  @override
  Widget build(BuildContext context) {
    final title = shop['title'] ?? 'Магазин';
    final desc = shop['desc'] ?? '';
    final logo = ApiConfig.replaceMediaUrl(shop['logo'] as String? ?? '');
    final countAds = shop['count_ads'] ?? '0 объявлений';

    // Получаем превью изображений из ads_images
    final adsImages = shop['ads_images'] as List? ?? [];
    final previewImages = adsImages
        .take(3)
        .map((img) {
          if (img is String) {
            return ApiConfig.replaceMediaUrl(img);
          }
          return '';
        })
        .where((url) => url.isNotEmpty)
        .toList();

    final countAdsInt = shop['count_ads_int'] ?? 0;
    final remainingCount = countAdsInt > 3 ? countAdsInt - 3 : 0;

    return GestureDetector(
      onTap: () {
        final shopId = shop['id']?.toString();
        if (shopId != null) {
          // Открываем WebView с мобильной версией магазина
          final shopHash = shop['id_hash'] ?? shop['hash'] ?? shopId;
          final url = 'https://hashtagg.ru/shop/$shopHash';

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ShopWebViewScreen(
                url: url,
                title: shop['title'] ?? 'Магазин',
              ),
            ),
          );
        }
      },
      child: Container(
        margin: EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Color(0xfff5f5f5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header с логотипом и названием
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    image: logo.isNotEmpty
                        ? DecorationImage(
                            image: NetworkImage(logo),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: logo.isEmpty
                      ? Icon(Icons.store, color: Colors.grey, size: 30)
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (desc.isNotEmpty)
                        Text(
                          desc,
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 12),

            // Превью изображений
            if (previewImages.isNotEmpty)
              SizedBox(
                height: 120,
                child: Row(
                  children: [
                    // Первое изображение (большое) - занимает 50% ширины
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _buildImage(previewImages[0]),
                      ),
                    ),

                    SizedBox(width: 4),

                    // Правая колонка с двумя изображениями
                    Expanded(
                      child: Column(
                        children: [
                          // Второе изображение (если есть) - всегда занимает 50% высоты
                          if (previewImages.length > 1)
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: _buildImage(previewImages[1]),
                              ),
                            ),

                          // Если нет второго изображения, показываем пустое место
                          if (previewImages.length == 1)
                            Expanded(child: SizedBox()),

                          if (previewImages.length > 2) ...[
                            SizedBox(height: 4),
                            // Третье изображение с оверлеем
                            Expanded(
                              child: Stack(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: _buildImage(previewImages[2]),
                                  ),
                                  if (remainingCount > 0)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            '+$remainingCount',
                                            style: GoogleFonts.montserrat(
                                              color: Colors.white,
                                              fontSize: 24,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ] else if (previewImages.length == 2) ...[
                            // Если только 2 изображения, нижняя половина пустая
                            SizedBox(height: 4),
                            Expanded(child: SizedBox()),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            if (previewImages.isEmpty)
              Container(
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Icon(Icons.image, size: 48, color: Colors.grey[500]),
                ),
              ),

            SizedBox(height: 12),

            // Количество объявлений
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                countAds,
                style: GoogleFonts.montserrat(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String imageUrl) {
    if (imageUrl.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Icon(Icons.image, color: Colors.grey[500]),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[300],
          child: Icon(Icons.broken_image, color: Colors.grey[500]),
        );
      },
    );
  }
}
