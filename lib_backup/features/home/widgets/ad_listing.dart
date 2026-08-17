import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/core/network/home_api_repository.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/shared/presentation/bloc/favorites_bloc.dart';
import 'package:hashtagg/shared/domain/entities/listing.dart' show ListingStatus, Listing;
import 'package:hashtagg/features/listing/screens/listing_screen.dart';
import '../bloc/feed_bloc.dart';

class _ServiceIconBadge extends StatelessWidget {
  final String emoji;
  final Color backgroundColor;
  final double size;

  const _ServiceIconBadge({
    required this.emoji,
    required this.backgroundColor,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Color(0xff917dfa).withOpacity(0.65),
        shape: BoxShape.circle,
        border: Border.all(color: Color(0xff917dfa), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          emoji,
          style: TextStyle(fontSize: size * 0.5),
        ),
      ),
    );
  }
}

/// Карточка объявления для двухколонного грида с данными из API
class AdListing extends StatelessWidget {
  final FeedAd ad;

  const AdListing({super.key, required this.ad});

  Color _colorForServiceName(String name) {
  switch (name) {
    case 'Поднятие':    return const Color(0xFF4CAF50); // зелёный
    case 'Вип':         return const Color(0xFFFFD700); // золотой
    case 'Турбо':       return const Color(0xFF917dfa); // фиолетовый
    case 'Коллаж в сторис': return const Color(0xFFFF6B6B); // красный
    default:            return const Color(0xFF9E9E9E); // серый
  }
}

/// Эмодзи услуги по названию маркера
String _emojiForServiceName(String name) {
  switch (name) {
    case 'Поднятие':    return '🚀';
    case 'Вип':         return '👑';
    case 'Турбо':       return '⚡';
    case 'Коллаж в сторис': return '✨';  // или три звезды
    default:            return '✨';
  }
}


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Преобразуем localhost URL
    final imageUrl = ad.images.isNotEmpty
        ? ApiConfig.replaceMediaUrl(ad.images.first)
        : null;

    // Конвертируем FeedAd в Listing для сохранения в избранным
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
      images: ad.images, // Добавляем изображения
    );

    return GestureDetector(
      onTap: () => context.push("/listing/${ad.id}"),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: isDark ? 0 : 2,
        color: isDark ? const Color(0xff233040) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: ad.markers['vip'] != null || ad.markers['turbo'] != null ? BorderSide(color: const Color(0xff917dfa), width: 2) : BorderSide.none,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Изображение с слайдером (1:1 аспект)
            AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children: [
                  // Изображение
                  Positioned.fill(
                    child: ad.images.isNotEmpty
                        ? _CompactImageSlider(
                            imageUrls: ad.images
                                .map((url) => ApiConfig.replaceMediaUrl(url))
                                .toList()
                                .cast<String>(),
                          )
                        : Container(
                            color: isDark ? Colors.grey.shade800 : Colors.white,
                            child: Icon(
                              Icons.image,
                              size: 40,
                              color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                            ),
                          ),
                  ),

                  // Иконки подключённых услуг (слева сверху, стиль "Продать быстрее")
...() sync* {
  final activeMarkers = ad.markers.entries
      .where((e) => e.value != null)
      .map((e) => e.value!)
      .toList();

  if (activeMarkers.isNotEmpty) {
    yield Positioned(
      bottom: 8,
      right: 6,
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        children: activeMarkers.map((marker) {
          return _ServiceIconBadge(
            emoji: _emojiForServiceName(marker.name),
            backgroundColor: _colorForServiceName(marker.name),
            size: 28,
          );
        }).toList(),
      ),
    );
  }
}(),

                ],
              ),
            ),
            // Информация - растягивается на всю оставшуюся высоту
            Expanded(
              child: Container(
                color: isDark ? const Color(0xff233040) : Colors.white,
                padding: const EdgeInsets.all(6),
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Заголовок и кнопка избранного
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
                                print('🔵 [AdListing] Favorite icon tapped for ad: ${ad.id}');
                                print('🔵 [AdListing] Current favorite state: $isFavorite');
                                
                                if (isFavorite) {
                                  print('🔵 [AdListing] Removing from favorites');
                                  context.read<FavoritesBloc>().add(
                                        RemoveFavorite(ad.id),
                                      );
                                } else {
                                  print('🔵 [AdListing] Adding to favorites');
                                  context.read<FavoritesBloc>().add(
                                        AddFavorite(ad.id, listing),
                                      );
                                }
                              },
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border_outlined,
                                color: Color(0xff917dfa),
                                size: 24,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Просмотры
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
                    // Цена
                    Text(
                      ad.price,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(), // Отталкивает местоположение вниз
                    // Местонахождение
                    Text(
                      ad.cityName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.montserrat(
                        fontSize: 13.2,
                        color: isDark ? Colors.white : Colors.grey.shade600,
                      ),
                    ),
                    // Дата публикации (если есть)
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


/// Компактный слайдер изображений для карточек объявлений
class _CompactImageSlider extends StatefulWidget {
  final List<String> imageUrls;
  
  const _CompactImageSlider({required this.imageUrls});

  @override
  State<_CompactImageSlider> createState() => _CompactImageSliderState();
}

class _CompactImageSliderState extends State<_CompactImageSlider> {
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
    
    // Вычисляем какие точки показывать (максимум 5)
    final totalImages = widget.imageUrls.length;
    final maxDots = 5;
    
    List<int> visibleDots = [];
    if (totalImages <= maxDots) {
      // Если изображений 5 или меньше - показываем все
      visibleDots = List.generate(totalImages, (index) => index);
    } else {
      // Если больше 5 - показываем скользящее окно
      if (_currentPage <= 1) {
        // В начале - показываем первые 5
        visibleDots = [0, 1, 2, 3, 4];
      } else if (_currentPage >= totalImages - 2) {
        // В конце - показываем последние 5
        visibleDots = List.generate(5, (i) => totalImages - 5 + i);
      } else {
        // В середине - текущая по центру
        visibleDots = [
          _currentPage - 2,
          _currentPage - 1,
          _currentPage,
          _currentPage + 1,
          _currentPage + 2,
        ];
      }
    }
    
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: (index) {
            setState(() {
              _currentPage = index;
            });
          },
          itemCount: widget.imageUrls.length,
          itemBuilder: (context, index) {
            return Image.network(
              widget.imageUrls[index],
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: isDark ? Colors.grey.shade800 : Colors.white,
                  child: Icon(
                    Icons.broken_image,
                    size: 40,
                    color: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
                  ),
                );
              },
            );
          },
        ),
        // Индикаторы (точечки) - показываем только если больше 1 изображения
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
                  children: visibleDots.map((dotIndex) {
                    final isActive = dotIndex == _currentPage;
                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          dotIndex,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: isActive ? 20 : 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(3.5),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
