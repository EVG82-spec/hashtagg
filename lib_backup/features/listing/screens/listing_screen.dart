import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';
import 'package:hashtagg/features/home/widgets/feed.dart';
import 'package:hashtagg/features/search/screens/search_filters_screen.dart';
import 'package:hashtagg/shared/presentation/bloc/favorites_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/listing_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/domain/entities/listing.dart';
import 'package:hashtagg/shared/infrastructure/repositories/test_listing_repository.dart';
import 'package:hashtagg/shared/presentation/utils.dart';
import 'package:hashtagg/shared/presentation/view_models/listing_view_model.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hashtagg/features/chats/screens/chat_screen.dart';
import 'package:hashtagg/features/chats/bloc/chat_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:swipe_image_gallery/swipe_image_gallery.dart';
import 'package:share_plus/share_plus.dart';

import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/utils/ad_services_modal.dart';

// Виджет отдельной страницы с собственной анимацией вспышки
class AnimatedPage extends StatefulWidget {
  final String imageUrl;
  const AnimatedPage({required this.imageUrl, super.key});

  @override
  State<AnimatedPage> createState() => _AnimatedPageState();
}

class _AnimatedPageState extends State<AnimatedPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  bool _hasAppeared = false; // флаг: была ли уже анимация

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800), // длительность вспышки
    );
    _opacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    // Запускаем анимацию при первом появлении виджета
    WidgetsBinding.instance.addPostFrameCallback((_) {
      appear();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Запуск анимации появления (только один раз)
  void appear() {
    if (!_hasAppeared) {
      _hasAppeared = true;
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(widget.imageUrl, fit: BoxFit.cover),
          // Белый слой с анимацией, игнорирующий касания
          IgnorePointer(
            child: AnimatedBuilder(
              animation: _opacity,
              builder: (context, child) {
                return Opacity(
                  opacity: _opacity.value,
                  child: Container(color: Colors.white),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Основной слайдер с PageView
class AnimatedImageSlider extends StatefulWidget {
  final List<String> imageUrls;
  final int maxDots;
  final double activeDotWidth;
  final double inactiveDotSize;
  final double dotHeight;
  
  const AnimatedImageSlider({
    required this.imageUrls,
    this.maxDots = 10,
    this.activeDotWidth = 24,
    this.inactiveDotSize = 8,
    this.dotHeight = 8,
    super.key,
  });

  @override
  State<AnimatedImageSlider> createState() => _AnimatedImageSliderState();
}

class _AnimatedImageSliderState extends State<AnimatedImageSlider> {
  late PageController _pageController;
  final Map<int, GlobalKey<_AnimatedPageState>> _pageKeys = {};
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

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    // При смене страницы запускаем анимацию на новой странице (только один раз)
    _pageKeys[index]?.currentState?.appear();
  }

  void _openGallery(BuildContext context, int initialIndex) {
    final overlayController = StreamController<Widget>.broadcast();
    
    // Виджет оверлея с кнопкой закрытия
    Widget buildOverlay(int index) {
      return SafeArea(
        child: Container(
          alignment: Alignment.topRight,
          padding: const EdgeInsets.all(16),
          child: IconButton(
            icon: const Icon(
              Icons.close,
              color: Colors.white,
              size: 30,
            ),
            onPressed: () {
              overlayController.close();
              Navigator.of(context).pop();
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                Colors.black.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      );
    }
    
    SwipeImageGallery(
      context: context,
      initialIndex: initialIndex,
      itemCount: widget.imageUrls.length,
      itemBuilder: (context, index) {
        return Image.network(
          widget.imageUrls[index],
          fit: BoxFit.contain,
        );
      },
      overlayController: overlayController,
      initialOverlay: buildOverlay(initialIndex),
      onSwipe: (index) {
        overlayController.add(buildOverlay(index));
      },
    ).show();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Вычисляем какие точки показывать (максимум задается через параметр)
    final totalImages = widget.imageUrls.length;
    final maxDots = widget.maxDots;
    
    List<int> visibleDots = [];
    if (totalImages <= maxDots) {
      // Если изображений меньше или равно maxDots - показываем все
      visibleDots = List.generate(totalImages, (index) => index);
    } else {
      // Если больше - показываем скользящее окно
      final halfWindow = maxDots ~/ 2;
      
      if (_currentPage < halfWindow) {
        // В начале - показываем первые maxDots
        visibleDots = List.generate(maxDots, (i) => i);
      } else if (_currentPage >= totalImages - halfWindow) {
        // В конце - показываем последние maxDots
        visibleDots = List.generate(maxDots, (i) => totalImages - maxDots + i);
      } else {
        // В середине - текущая по центру
        visibleDots = List.generate(maxDots, (i) => _currentPage - halfWindow + i);
      }
    }
    
    return Stack(
      children: [
        PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: widget.imageUrls.length,
          itemBuilder: (context, index) {
            final key = _pageKeys.putIfAbsent(
              index,
              () => GlobalKey<_AnimatedPageState>(),
            );
            return GestureDetector(
              onTap: () => _openGallery(context, index),
              child: AnimatedPage(key: key, imageUrl: widget.imageUrls[index]),
            );
          },
        ),
        // Индикаторы (точечки) - показываем только если больше 1 изображения
        if (widget.imageUrls.length > 1)
          Positioned(
            bottom: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
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
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
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

class ListingScreen extends StatefulWidget {
  final String itemId;
  final Listing? listing;

  const ListingScreen({super.key, required this.itemId, this.listing});

  @override
  State<ListingScreen> createState() => _ListingScreenState();
}

class _ListingScreenState extends State<ListingScreen> {
  ListingViewModel? _listingViewModel;
  late Listing listing;
  bool _reportSent = false;
  bool _isPhoneRevealed = false; // Состояние раскрытия номера телефона

  @override
  void initState() {
    super.initState();
    _loadListing();
    // Загружаем похожие объявления
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (listing.id != null) {
        context.read<ListingBloc>().add(LoadSimilarAds(listing.id!));
      }
    });
  }

  void _loadListing() {
    // Если listing передан из ListingLoadingScreen
    if (widget.listing != null) {
      listing = widget.listing!;
    } else {
      // Fallback на тестовый репозиторий
      final repository = TestListingRepository();
      listing = repository.findById(int.parse(widget.itemId)) ?? 
          Listing(
            id: 0,
            title: 'Объявление не найдено',
            description: '',
            price: 0,
            location: '',
            views: 0,
            status: ListingStatus.active,
            userId: 0,
            publishedAt: '',
          );
    }
    _listingViewModel = ListingViewModel(listing);
  }

  String? _fixImageUrl(String? url) {
    if (url == null) return null;
    if (url.contains('localhost')) {
      return url.replaceAll(
        RegExp(r'http://localhost(:\d+)?'),
        ApiConfig.mediaUrl,
      );
    }
    return url;
  }

  String _pluralizeViews(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'просмотров';
    if (mod10 == 1) return 'просмотр';
    if (mod10 >= 2 && mod10 <= 4) return 'просмотра';
    return 'просмотров';
  }

  void _shareListing() {
    // Формируем ссылку на объявление
    String shareUrl = 'https://hashtagg.ru';
    
    print('🔵 [Share] listing.link: "${listing.link}"');
    print('🔵 [Share] listing.id: ${listing.id}');
    
    // Используем готовую ссылку из API если она есть
    if (listing.link != null && listing.link!.isNotEmpty) {
      // Поле link уже содержит полный путь: city_alias/category_board_alias/ads_alias-ads_id
      // Убираем возможный домен если он есть
      String linkPath = listing.link!;
      if (linkPath.startsWith('http://') || linkPath.startsWith('https://')) {
        linkPath = Uri.parse(linkPath).path;
      }
      // Убираем начальный слэш
      linkPath = linkPath.replaceAll(RegExp(r'^/'), '');
      
      shareUrl = 'https://hashtagg.ru/$linkPath';
      print('✅ [Share] Final URL from API link: $shareUrl');
    } else if (listing.id != null) {
      // Fallback: формируем ссылку вручную если link не пришел из API
      print('⚠️ [Share] No link from API, building manually');
      
      String citySlug = '';
      String categorySlug = '';
      String listingSlug = '';
      
      // Получаем slug города
      if (listing.cityAlias != null && listing.cityAlias!.isNotEmpty) {
        citySlug = listing.cityAlias!;
      } else if (listing.location != null && listing.location!.isNotEmpty) {
        citySlug = _transliterateCity(listing.location!);
      }
      
      // Получаем slug объявления
      if (listing.listingAlias != null && listing.listingAlias!.isNotEmpty) {
        listingSlug = listing.listingAlias!;
      }
      
      // Извлекаем последний сегмент категории
      if (listing.breadcrumbs != null && listing.breadcrumbs!.isNotEmpty) {
        final lastBreadcrumb = listing.breadcrumbs!.last;
        if (lastBreadcrumb.link.isNotEmpty) {
          final link = lastBreadcrumb.link.startsWith('http://') || 
                       lastBreadcrumb.link.startsWith('https://')
              ? Uri.parse(lastBreadcrumb.link).path
              : lastBreadcrumb.link;
          
          final fullPath = link.replaceAll(RegExp(r'^/|/$'), '');
          final segments = fullPath.split('/');
          categorySlug = segments.isNotEmpty ? segments.last : '';
        }
      }
      
      // Формируем финальную ссылку
      if (citySlug.isNotEmpty && categorySlug.isNotEmpty && listingSlug.isNotEmpty) {
        shareUrl = 'https://hashtagg.ru/$citySlug/$categorySlug/$listingSlug-${listing.id}';
      } else {
        shareUrl = 'https://hashtagg.ru/listing/${listing.id}';
      }
      
      print('✅ [Share] Final URL (manual): $shareUrl');
    }
    
    // Формируем текст для шаринга
    final shareText = '${listing.title}\n\n$shareUrl';
    
    // Делимся ссылкой
    Share.share(
      shareText,
      subject: listing.title,
    );
  }

  // Простая транслитерация названия города в slug
  String _transliterateCity(String cityName) {
    final Map<String, String> translitMap = {
      'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'e',
      'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
      'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
      'ф': 'f', 'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch',
      'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
      ' ': '-', '_': '-',
    };
    
    String result = cityName.toLowerCase();
    translitMap.forEach((key, value) {
      result = result.replaceAll(key, value);
    });
    
    // Убираем все символы кроме букв, цифр и дефиса
    result = result.replaceAll(RegExp(r'[^a-z0-9\-]'), '');
    
    return result;
  }

  void _showOptionsModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.pop(context);
                  if (_reportSent) {
                    showSwipeDownNotification(
                      context,
                      message:
                          'Ваше обращение уже принято и находится на рассмотрении.',
                    );
                  } else {
                    _showReportModal(context);
                  }
                },
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Пожаловаться',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showReportModal(BuildContext context) {
    final TextEditingController controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 
                  MediaQuery.of(ctx).padding.bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Опишите причину жалобы',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      maxLines: 5,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xffF0F0F0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Опишите причину жалобы',
                                  style: GoogleFonts.montserrat(),
                                ),
                              ),
                            );
                            return;
                          }

                          // Получаем данные пользователя
                          final authState = context.read<AuthBloc>().state;
                          if (authState.user == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Необходимо авторизоваться',
                                  style: GoogleFonts.montserrat(),
                                ),
                              ),
                            );
                            return;
                          }

                          Navigator.pop(ctx);

                          // Отправляем жалобу
                          final listingBloc = context.read<ListingBloc>();
                          await listingBloc.reportListing(
                            listingId: int.parse(widget.itemId),
                            text: text,
                          );

                          if (!mounted) return;

                          // Проверяем результат
                          final error = listingBloc.state.error;
                          if (error != null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  error,
                                  style: GoogleFonts.montserrat(),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            setState(() => _reportSent = true);
                            _showReportSuccessModal(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff917dfa),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Отправить',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportSuccessModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SizedBox(
        width: double.infinity,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: const BoxDecoration(
                        color: Color(0xff4CAF50),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Обращение принято',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          // Перезагружаем данные объявления
          _loadListing();
          // Перезагружаем похожие объявления
          if (listing.id != null) {
            context.read<ListingBloc>().add(LoadSimilarAds(listing.id!));
          }
          // Небольшая задержка для визуального эффекта
          await Future.delayed(Duration(milliseconds: 500));
        },
        color: const Color(0xff917dfa),
        edgeOffset: 40.0,
        displacement: 20.0,
        strokeWidth: 3.0,
        child: BlocBuilder<FavoritesBloc, FavoritesState>(
          builder: (context, state) {
            return Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    SliverAppBar(
                    expandedHeight: 400.0,
                    pinned: true,
                    surfaceTintColor: Colors.transparent,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back),
                      style: ButtonStyle(
                        iconColor: WidgetStateProperty.all(Colors.white),
                        backgroundColor: WidgetStateProperty.all(
                          Color.fromRGBO(0, 0, 0, 0.4),
                        ),
                        overlayColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.pressed)) {
                            return Color(
                              0xff917dfa,
                            ).withValues(alpha: 0.3); // цвет splash при нажатии
                          }
                          return Colors
                              .transparent; // прозрачный в остальных состояниях
                        }),
                      ),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/');
                        }
                      },
                    ),
                    actions: [
                      IconButton(
                        icon: Icon(Icons.share),
                        onPressed: _shareListing,
                        style: ButtonStyle(
                          iconColor: WidgetStateProperty.all(Colors.white),
                          backgroundColor: WidgetStateProperty.all(
                            Color.fromRGBO(0, 0, 0, 0.4),
                          ),
                          overlayColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.pressed)) {
                              return Color(0xff917dfa).withValues(
                                alpha: 0.3,
                              ); // цвет splash при нажатии
                            }
                            return Colors
                                .transparent; // прозрачный в остальных состояниях
                          }),
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          context.read<FavoritesBloc>().state.ids.contains(
                                    listing!.id!,
                                  ) ==
                                  true
                              ? Icons.favorite
                              : Icons.favorite_border_outlined,
                          color:
                              context.read<FavoritesBloc>().state.ids.contains(
                                    listing!.id!,
                                  ) ==
                                  true
                              ? Color(0xff917dfa)
                              : Colors.white,
                        ),

                        onPressed: () {
                          final isFavorite = context
                              .read<FavoritesBloc>()
                              .state
                              .ids
                              .contains(listing!.id!);
                          if (isFavorite) {
                            context.read<FavoritesBloc>().add(
                              RemoveFavorite(listing!.id!),
                            );
                          } else {
                            context.read<FavoritesBloc>().add(
                              AddFavorite(listing!.id!, listing!),
                            );
                          }
                        },
                        style: ButtonStyle(
                          iconColor: WidgetStateProperty.all(Colors.white),
                          backgroundColor: WidgetStateProperty.all(
                            Color.fromRGBO(0, 0, 0, 0.4),
                          ),
                          overlayColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.pressed)) {
                              return Color(0xff917dfa).withValues(
                                alpha: 0.3,
                              ); // цвет splash при нажатии
                            }
                            return Colors
                                .transparent; // прозрачный в остальных состояниях
                          }),
                        ),
                      ),
                      IconButton(
                        icon: SvgPicture.asset(
                          'assets/menu.svg',
                          color: Colors.white,
                          width: 16,
                          height: 16,
                        ),
                        onPressed: () => _showOptionsModal(context),
                        style: ButtonStyle(
                          iconColor: WidgetStateProperty.all(Colors.white),
                          backgroundColor: WidgetStateProperty.all(
                            Color.fromRGBO(0, 0, 0, 0.4),
                          ),
                          overlayColor: WidgetStateProperty.resolveWith((
                            states,
                          ) {
                            if (states.contains(WidgetState.pressed)) {
                              return Color(0xff917dfa).withValues(
                                alpha: 0.3,
                              ); // цвет splash при нажатии
                            }
                            return Colors
                                .transparent; // прозрачный в остальных состояниях
                          }),
                        ),
                      ),
                    ],
                    backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
                    flexibleSpace: FlexibleSpaceBar(
                      background: AnimatedImageSlider(
                        imageUrls: listing.images?.isNotEmpty ?? false
                            ? listing.images!
                            : [
                                '${ApiConfig.mediaUrl}/public/media/others/icon_photo.png',
                              ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(child: SizedBox(height: 20)),

                  // Breadcrumbs
                  if (listing.breadcrumbs != null && listing.breadcrumbs!.isNotEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            for (int i = 0; i < listing.breadcrumbs!.length; i++) ...[
                              GestureDetector(
                                onTap: () {
                                  // Навигация на экран поиска с фильтром категории
                                  final searchFilters = SearchFilters(
                                    categoryId: listing.breadcrumbs![i].id,
                                    category: listing.breadcrumbs![i].name,
                                  );
                                  context.push('/search', extra: searchFilters);
                                },
                                child: Text(
                                  listing.breadcrumbs![i].name,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400,
                                    color: const Color(0xff917dfa),
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                              ),
                              if (i < listing.breadcrumbs!.length - 1)
                                Transform.translate(
                                  offset: const Offset(0, 1),
                                  child: Text(
                                    ' > ',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w400,
                                      color: const Color(0xff917dfa),
                                    ),
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  if (listing.breadcrumbs != null && listing.breadcrumbs!.isNotEmpty)
                    SliverToBoxAdapter(child: SizedBox(height: 8)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsetsGeometry.symmetric(horizontal: 20),
                      child: Text(
                        _listingViewModel?.fullTitle() ?? 'Объявление не найдено',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight(600),
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(child: SizedBox(height: 5)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            _listingViewModel?.price() ??
                                'Объявление не найдено',
                            style: GoogleFonts.montserrat(
                              fontSize: 22,
                              fontWeight: FontWeight(700),
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(child: SizedBox(height: 15)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final currentUser = context
                                  .read<AuthBloc>()
                                  .state
                                  .user;
                              final listingUserId = listing.userId;

                              if (listingUserId != null && listingUserId > 0) {
                                // Дополнительная проверка через Hive для надежности
                                final box = await Hive.openBox('user');
                                final userData = box.get('user');
                                int? currentUserId;
                                if (userData is Map && userData['id'] != null) {
                                  currentUserId = int.tryParse(userData['id'].toString());
                                }
                                
                                print('🔵 [ListingScreen] Navigating to profile: listingUserId=$listingUserId, currentUserId=$currentUserId');
                                
                                if (currentUserId == listingUserId || 
                                    (currentUser != null && currentUser.id == listingUserId)) {
                                  print('🔵 [ListingScreen] Same user detected - this is your own listing, not navigating');
                                  // Это собственное объявление пользователя, не переходим никуда
                                  // Можно показать сообщение или просто ничего не делать
                                  return;
                                } else {
                                  print('🔵 [ListingScreen] Different user, navigating to /user/$listingUserId');
                                  context.push('/user/$listingUserId');
                                }
                              }
                            },
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 60,
                                  height: 60,
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(30),
                                    child: Image.network(
                                      _fixImageUrl(listing.userAvatar) ??
                                          'https://hashtagg.ru/media/others/no_avatar.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        listing.userName ?? 'Unknown',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 16,
                                          fontWeight: FontWeight(700),
                                        ),
                                      ),
                                      Row(
                                        children: List.generate(5, (index) {
                                          final rating = listing.userRating ?? 0.0;
                                          return Icon(
                                            index < rating.floor()
                                                ? Icons.star
                                                : (index < rating
                                                    ? Icons.star_half
                                                    : Icons.star_border),
                                            color: rating > 0
                                                ? Color(0xffFFC107)
                                                : Color(0xffdee2e6),
                                            size: 18,
                                          );
                                        }),
                                      ),
                                      Text(
                                        'В Хештег с 06.04.2025',
                                        style: GoogleFonts.montserrat(
                                          color: Color(0xff666666),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                          // Показываем кнопку "Продать быстрее" если это собственное объявление
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, authState) {
                              final currentUser = authState.user;
                              final listingUserId = listing?.userId;
                              final isOwnListing = currentUser != null && 
                                                   listingUserId != null && 
                                                   currentUser.id == listingUserId;
                              
                              // Показываем кнопку "Продать быстрее" только для собственных объявлений
                              if (isOwnListing && listing?.id != null) {
                                return Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          await AdServicesModal.show(context, listing!.id!);
                                          // Перезагружаем данные объявления после закрытия модалки
                                          if (mounted) {
                                            _loadListing();
                                            setState(() {});
                                          }
                                        },
                                        style: ButtonStyle(
                                          backgroundColor: WidgetStatePropertyAll(
                                            Color(0xff917dfa),
                                          ),
                                          padding: WidgetStatePropertyAll(
                                            EdgeInsets.only(top: 16, bottom: 16),
                                          ),
                                          shape: WidgetStatePropertyAll(
                                            RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.rocket_launch, color: Colors.white, size: 20),
                                            SizedBox(width: 8),
                                            Text(
                                              "Продать быстрее",
                                              style: GoogleFonts.montserrat(
                                                color: Color(0xffffffff),
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                  ],
                                );
                              }
                              return SizedBox.shrink();
                            },
                          ),
                          // Показываем кнопку "Показать номер" если есть телефон и это не собственное объявление
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, authState) {
                              final currentUser = authState.user;
                              final listingUserId = listing?.userId;
                              final isOwnListing = currentUser != null && 
                                                   listingUserId != null && 
                                                   currentUser.id == listingUserId;
                              final hasPhone = listing?.userPhone != null && 
                                              listing!.userPhone!.isNotEmpty;
                              
                              // Показываем кнопку только если есть телефон и это не собственное объявление
                              if (!isOwnListing && hasPhone) {
                                return Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          if (!_isPhoneRevealed) {
                                            // Первое нажатие - показываем номер
                                            setState(() {
                                              _isPhoneRevealed = true;
                                            });
                                          } else {
                                            // Второе нажатие - открываем звонок
                                            final phone = listing!.userPhone!;
                                            final uri = Uri.parse('tel:$phone');
                                            if (await canLaunchUrl(uri)) {
                                              await launchUrl(uri);
                                            }
                                          }
                                        },
                                        style: ButtonStyle(
                                          backgroundColor: WidgetStatePropertyAll(
                                            _isPhoneRevealed 
                                                ? Color(0xffffffff)
                                                : Color(0xff917dfa),
                                          ),
                                          padding: WidgetStatePropertyAll(
                                            EdgeInsets.only(top: 16, bottom: 16),
                                          ),
                                          shape: WidgetStatePropertyAll(
                                            RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                              side: _isPhoneRevealed
                                                  ? BorderSide(color: Color(0xff917dfa), width: 1)
                                                  : BorderSide.none,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          _isPhoneRevealed 
                                              ? listing!.userPhone!
                                              : "Показать номер",
                                          style: GoogleFonts.montserrat(
                                            color: _isPhoneRevealed
                                                ? Color(0xff917dfa)
                                                : Color(0xffffffff),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(height: 12),
                                  ],
                                );
                              }
                              return SizedBox.shrink();
                            },
                          ),
                          // Показываем кнопку "Написать" только если это не собственное объявление
                          BlocBuilder<AuthBloc, AuthState>(
                            builder: (context, authState) {
                              final currentUser = authState.user;
                              final listingUserId = listing?.userId;
                              final isOwnListing = currentUser != null && 
                                                   listingUserId != null && 
                                                   currentUser.id == listingUserId;
                              
                              // Не показываем кнопку для собственных объявлений
                              if (isOwnListing) {
                                return SizedBox.shrink();
                              }
                              
                              return BlocBuilder<ChatBloc, ChatState>(
                                builder: (context, chatState) {
                                  return ElevatedButton(
                                onPressed: chatState.isLoading ? null : () async {
                                  final user = context.read<AuthBloc>().state.user;
                                  if (user == null) {
                                    showAuthModal(context);
                                  } else if (listing != null && listing!.id != null) {
                                    // Загружаем диалог через API
                                    final chatBloc = context.read<ChatBloc>();
                                    
                                    // Создаем hash для диалога
                                    final dialogId = 'ad_${listing!.id}_${user.id}';
                                    
                                    // Загружаем диалог (создастся автоматически если не существует)
                                    chatBloc.add(LoadDialog(
                                      dialogId: dialogId,
                                      adId: listing!.id!,
                                    ));
                                    
                                    // Ждем загрузки
                                    await Future.delayed(Duration(milliseconds: 500));
                                    
                                    if (context.mounted && chatBloc.state.currentDialog != null) {
                                      final dialog = chatBloc.state.currentDialog!;
                                      
                                      Navigator.of(
                                        context,
                                        rootNavigator: true,
                                      ).push(
                                        createSwipeableRoute(
                                          builder: (_) => BlocProvider.value(
                                            value: chatBloc,
                                            child: ChatScreen(
                                              userName: dialog.user?.name ?? 'Пользователь',
                                              lastSeen: dialog.user?.statusOnline ?? 'Был(а) в сети',
                                              avatarUrl: dialog.user?.avatar,
                                              listing: ChatListing(
                                                title: dialog.ad?.title ?? listing!.title,
                                                price: dialog.ad?.price ?? '${listing!.price ?? 0} ₽',
                                                status: dialog.ad?.statusName ?? 'Активно',
                                                imageUrl: dialog.ad?.image,
                                                listingId: listing!.id?.toString(),
                                              ),
                                              dialogId: dialog.idHash,
                                              userId: dialog.user?.id ?? 0,
                                            ),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ButtonStyle(
                                  backgroundColor: WidgetStatePropertyAll(
                                    Color(0xff917dfa),
                                  ),
                                  padding: WidgetStatePropertyAll(
                                    EdgeInsets.only(top: 16, bottom: 16),
                                  ),
                                  shape: WidgetStatePropertyAll(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                child: chatState.isLoading
                                    ? SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Text(
                                        "Написать",
                                        style: GoogleFonts.montserrat(
                                          color: Color(0xffffffff),
                                        ),
                                      ),
                              );
                            },
                          );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(child: SizedBox(height: 15)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Местоположение',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight(700),
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            _listingViewModel?.location() ??
                                'Объявление не найдено',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight(500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(child: SizedBox(height: 10)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Описание',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight(700),
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            _listingViewModel?.description() ??
                                'Объявление не найдено',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight(500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(child: SizedBox(height: 60)),

                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsetsGeometry.only(left: 20, right: 20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Color(0xff917dfa).withValues(alpha: 0.325),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        child: Padding(
                          padding: EdgeInsetsGeometry.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Опубликовано: 06 февраля 2026',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight(500),
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                '${listing.views ?? 0} ${_pluralizeViews(listing.views ?? 0)}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight(500),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  SliverToBoxAdapter(child: SizedBox(height: 30)),

                  // Похожие объявления
                  BlocBuilder<ListingBloc, ListingState>(
                    builder: (context, listingState) {
                      if (listingState.isLoadingSimilar) {
                        return SliverToBoxAdapter(
                          child: Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: Color(0xff917dfa),
                              ),
                            ),
                          ),
                        );
                      }

                      if (listingState.similarAds != null && 
                          listingState.similarAds!.isNotEmpty) {
                        return SliverPadding(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              Text(
                                'Похожие объявления',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              SizedBox(height: 15),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: NeverScrollableScrollPhysics(),
                                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  childAspectRatio: 0.5765,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                ),
                                itemCount: listingState.similarAds!.length,
                                itemBuilder: (context, index) {
                                  final ad = listingState.similarAds![index];
                                  final images = ad.images?.isNotEmpty == true
                                      ? ad.images!
                                      : ['https://hashtagg.ru/media/others/0d2d3064105f566413575dfe6c094d71.jpg'];
                                  
                                  return GestureDetector(
                                    onTap: () => context.push('/listing/${ad.id}'),
                                    child: Card(
                                      clipBehavior: Clip.antiAlias,
                                      elevation: isDark ? 0 : 2,
                                      color: isDark ? const Color(0xff233040) : Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Изображение с слайдером (1:1 аспект)
                                          AspectRatio(
                                            aspectRatio: 1,
                                            child: AnimatedImageSlider(
                                              imageUrls: images,
                                            ),
                                          ),
                                          // Информация
                                          Expanded(
                                            child: Container(
                                              color: isDark ? const Color(0xff233040) : Colors.white,
                                              padding: EdgeInsets.all(6),
                                              child: Column(
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
                                                            fontSize: 12,
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
                                                                  RemoveFavorite(ad.id!),
                                                                );
                                                              } else {
                                                                context.read<FavoritesBloc>().add(
                                                                  AddFavorite(ad.id!, ad),
                                                                );
                                                              }
                                                            },
                                                            child: Icon(
                                                              isFavorite
                                                                  ? Icons.favorite
                                                                  : Icons.favorite_border_outlined,
                                                              color: Color(0xff917dfa),
                                                              size: 18,
                                                            ),
                                                          );
                                                        },
                                                      ),
                                                    ],
                                                  ),
                                                  SizedBox(height: 6),
                                                  // Просмотры
                                                  Row(
                                                    children: [
                                                      Icon(
                                                        Icons.visibility_outlined,
                                                        size: 11,
                                                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                                                      ),
                                                      SizedBox(width: 3),
                                                      Text(
                                                        ad.views?.toString() ?? '0',
                                                        style: GoogleFonts.montserrat(
                                                          fontSize: 10,
                                                          color: isDark ? Colors.white70 : Colors.grey.shade600,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Spacer(),
                                                  // Цена
                                                  Text(
                                                    '${ad.price} ₽',
                                                    style: GoogleFonts.montserrat(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : Colors.black,
                                                    ),
                                                  ),
                                                  Spacer(),
                                                  // Местонахождение
                                                  if (ad.location != null && ad.location!.isNotEmpty)
                                                    Text(
                                                      ad.location!,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 10,
                                                        color: isDark ? Colors.white70 : Colors.grey.shade600,
                                                      ),
                                                    ),
                                                  // Дата публикации (если есть)
                                                  if (ad.publishedAt != null && ad.publishedAt!.isNotEmpty)
                                                    Text(
                                                      ad.publishedAt!,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: GoogleFonts.montserrat(
                                                        fontSize: 10,
                                                        color: isDark ? Colors.white70 : Colors.grey.shade600,
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
                                },
                              ),
                            ]),
                          ),
                        );
                      }

                      return SliverToBoxAdapter(child: SizedBox());
                    },
                  ),

                  SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
