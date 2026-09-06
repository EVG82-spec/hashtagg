// lib/features/shop/widgets/shop_ad_card.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/core/network/home_api_repository.dart';
import 'package:hashtagg/shared/presentation/bloc/favorites_bloc.dart';
import 'package:hashtagg/shared/domain/entities/listing.dart'
    show ListingStatus, Listing;
import 'package:flutter_bloc/flutter_bloc.dart';

class ShopAdCard extends StatelessWidget {
  final FeedAd ad;

  const ShopAdCard({Key? key, required this.ad}) : super(key: key);

  // ✅ ВОТ СЮДА ДОБАВЛЯЕМ МЕТОД (ПЕРЕД build)
  String? _getImageUrl(String? image) {
    print('🔍🔍🔍 [_getImageUrl] INPUT: "$image"');

    if (image == null || image.isEmpty) {
      print('   ❌ image is null or empty');
      return null;
    }

    if (image.startsWith('http://') || image.startsWith('https://')) {
      print('   ✅ image is full URL: $image');
      // 👇 ПРОВЕРЯЕМ, СУЩЕСТВУЕТ ЛИ ФАЙЛ
      // Если это /media/ads/ - пробуем заменить на /media/images_boards/big/
      if (image.contains('/media/ads/')) {
        // Берем имя файла из URL
        final fileName = image.split('/').last;
        final nameWithoutExt = fileName.split('.').first;
        final newUrl =
            'https://hashtagg.ru/media/images_boards/big/$nameWithoutExt.webp';
        print('   🔄 REPLACED: $newUrl');
        return newUrl;
      }
      return image;
    }

    // Если это просто имя файла
    final nameWithoutExtension = image.split('.').first;
    final newUrl =
        'https://hashtagg.ru/media/images_boards/big/$nameWithoutExtension.webp';
    print('   ✅ generated: $newUrl');
    return newUrl;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ БЕЗ replaceMediaUrl!
    final imageUrl = ad.images.isNotEmpty ? ad.images.first : null;

    final listing = Listing(
      id: ad.id,
      title: ad.title,
      location: ad.cityName,
      views: ad.countView,
      publishedAt: ad.title,
      price: int.tryParse(ad.price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
      description: ad.text,
      status: ListingStatus.active,
      userId: ad.user.id,
      images: ad.images,
    );

    return GestureDetector(
      onTap: () => context.push("/listing/${ad.id}"),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: isDark ? 0 : 2,
        color: isDark ? const Color(0xff233040) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: ad.markers['vip'] != null || ad.markers['turbo'] != null
              ? BorderSide(color: const Color(0xff917dfa), width: 2)
              : BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ad.images.isNotEmpty
                        ? _ShopImageSlider(
                            imageUrls: ad.images,
                          ) // ✅ БЕЗ replaceMediaUrl
                        : Container(
                            color: isDark ? Colors.grey.shade800 : Colors.white,
                            child: Icon(
                              Icons.image,
                              size: 40,
                              color: isDark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: isDark ? const Color(0xff233040) : Colors.white,
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            ad.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.2,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        SizedBox(width: 4),
                        BlocBuilder<FavoritesBloc, FavoritesState>(
                          builder: (context, favState) {
                            final isFavorite = favState.ids.contains(ad.id);
                            return GestureDetector(
                              onTap: () {
                                if (isFavorite) {
                                  context.read<FavoritesBloc>().add(
                                    RemoveFavorite(ad.id),
                                  );
                                } else {
                                  context.read<FavoritesBloc>().add(
                                    AddFavorite(ad.id, listing),
                                  );
                                }
                              },
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border_outlined,
                                color: const Color(0xff917dfa),
                                size: 24,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 13.2,
                          color: isDark ? Colors.white : Colors.grey.shade600,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          ad.countView.toString(),
                          style: GoogleFonts.montserrat(
                            fontSize: 13.2,
                            color: isDark ? Colors.white : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      ad.price,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      ad.cityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontSize: 13.2,
                        color: isDark ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                    if (ad.dateTimeAdd != 'Дата не указана')
                      Text(
                        ad.dateTimeAdd,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 13.2,
                          color: isDark ? Colors.white : Colors.grey.shade600,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// СЛАЙДЕР (БЕЗ replaceMediaUrl)
// ============================================================

class _ShopImageSlider extends StatefulWidget {
  final List<String> imageUrls;

  const _ShopImageSlider({required this.imageUrls});

  @override
  State<_ShopImageSlider> createState() => _ShopImageSliderState();
}

class _ShopImageSliderState extends State<_ShopImageSlider> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemCount: widget.imageUrls.length,
          itemBuilder: (context, index) {
            return Image.network(
              widget.imageUrls[index],
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        const Color(0xff917dfa),
                      ),
                    ),
                  ),
                );
              },
              errorBuilder: (_, __, ___) => Container(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                child: Icon(
                  Icons.broken_image,
                  size: 40,
                  color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                ),
              ),
            );
          },
        ),
        if (widget.imageUrls.length > 1)
          Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(
                    widget.imageUrls.length > 5 ? 5 : widget.imageUrls.length,
                    (index) {
                      final isActive = index == _currentPage;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(3.5),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
