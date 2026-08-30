import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/core/network/home_api_repository.dart';
import 'package:hashtagg/features/home/bloc/feed_bloc.dart';
import 'package:hashtagg/features/home/widgets/ad_listing.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hashtagg/features/shop/models/shop.dart';

class FeedHeader extends StatelessWidget {
  const FeedHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<FeedBloc, FeedState>(
      builder: (context, state) {
        return Column(
          children: [
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  Wrap(
                    spacing: 20,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      SizedBox(width: 0),
                      GestureDetector(
                        onTap: () {
                          context.read<FeedBloc>().add(
                            FeedCategoryChangeEvent(
                              category: FeedCategory.recommendations,
                            ),
                          );
                        },
                        child: SizedBox(
                          width: 168,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Рекомендации',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                style: GoogleFonts.montserrat(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      state.category ==
                                          FeedCategory.recommendations
                                      ? (isDark
                                            ? Colors.white
                                            : const Color(0xff000000))
                                      : const Color(0xff666666),
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                height: 2,
                                color:
                                    state.category ==
                                        FeedCategory.recommendations
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          context.read<FeedBloc>().add(
                            FeedCategoryChangeEvent(
                              category: FeedCategory.fresh,
                            ),
                          );
                        },
                        child: SizedBox(
                          width: 86,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Свежие',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                style: GoogleFonts.montserrat(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color: state.category == FeedCategory.fresh
                                      ? (isDark
                                            ? Colors.white
                                            : const Color(0xff000000))
                                      : const Color(0xff808080),
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                height: 2,
                                color: state.category == FeedCategory.fresh
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          context.read<FeedBloc>().add(
                            FeedCategoryChangeEvent(
                              category: FeedCategory.companies,
                            ),
                          );
                        },
                        child: SizedBox(
                          width: 113,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Компании',
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                style: GoogleFonts.montserrat(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  color:
                                      state.category == FeedCategory.companies
                                      ? (isDark
                                            ? Colors.white
                                            : const Color(0xff000000))
                                      : const Color(0xff808080),
                                ),
                              ),
                              SizedBox(height: 4),
                              Container(
                                height: 2,
                                color: state.category == FeedCategory.companies
                                    ? (isDark ? Colors.white : Colors.black)
                                    : Colors.transparent,
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(width: 0),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class MultiSliver extends StatelessWidget {
  final List<Widget> children;

  const MultiSliver({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(slivers: children);
  }
}

class FeedView extends StatefulWidget {
  final ScrollController? scrollController;
  final int? cityId;
  final int? regionId;
  final int? countryId;

  const FeedView({
    super.key,
    this.scrollController,
    this.cityId,
    this.regionId,
    this.countryId,
  });

  @override
  State<FeedView> createState() => _FeedViewState();
}

class _FeedViewState extends State<FeedView> {
  late final HomeApiRepository _homeApiRepository;
  final List<FeedAd> _allAds = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  bool _hasNext = false;
  int _currentPage = 1;
  bool _isScrollHandling = false;

  @override
  void initState() {
    super.initState();
    _homeApiRepository = HomeApiRepository(DioClient.createDio());

    if (widget.scrollController != null) {
      widget.scrollController!.addListener(_onScroll);
    }

    _loadFeed();
  }

  @override
  void didUpdateWidget(covariant FeedView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Проверяем, изменился ли город, регион или страна
    if (widget.cityId != oldWidget.cityId ||
        widget.regionId != oldWidget.regionId ||
        widget.countryId != oldWidget.countryId) {
      print(
        '🔄 [Feed] Город изменился: ${oldWidget.cityId} → ${widget.cityId}',
      );
      _loadFeed();
    }
  }

  @override
  void dispose() {
    if (widget.scrollController != null) {
      widget.scrollController!.removeListener(_onScroll);
    }
    super.dispose();
  }

  void _onScroll() {
    if (widget.scrollController == null || _isScrollHandling) return;

    final controller = widget.scrollController!;
    final threshold = controller.position.maxScrollExtent - 100;
    if (controller.position.pixels >= threshold) {
      if (!_isLoadingMore && _hasNext) {
        _isScrollHandling = true;
        _loadMoreAds().then((_) {
          _isScrollHandling = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<FeedBloc, FeedState>(
      listenWhen: (previous, current) => previous.category != current.category,
      listener: (context, state) {
        _loadFeed();
      },
      child: MultiSliver(
        children: [
          SliverToBoxAdapter(child: FeedHeader()),
          SliverToBoxAdapter(child: SizedBox(height: 10)),
          _buildContent(),
          if (_isLoadingMore) _buildLoadingIndicator(),
        ],
      ),
    );
  }

  Future<void> _loadFeed() async {
    print('🔵 [Feed] Загрузка ленты с cityId=${widget.cityId}');
    setState(() {
      _isLoading = true;
      _error = null;
      _allAds.clear();
      _currentPage = 1;
    });

    try {
      final category = context.read<FeedBloc>().state.category;
      final categoryString = category == FeedCategory.recommendations
          ? 'recommendations'
          : category == FeedCategory.fresh
          ? 'fresh'
          : 'companies';

      final result = await _homeApiRepository.getAdsFeed(
        category: categoryString,
        page: 1,
        pageSize: 8,
        cityId: widget.cityId,
        regionId: widget.regionId,
        countryId: widget.countryId,
      );

      if (result.success && result.data != null) {
        setState(() {
          _allAds.addAll(result.data!.ads);
          _hasNext = result.data!.hasNext;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result.error;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreAds() async {
    if (_isLoadingMore || !_hasNext) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final category = context.read<FeedBloc>().state.category;
      final categoryString = category == FeedCategory.recommendations
          ? 'recommendations'
          : category == FeedCategory.fresh
          ? 'fresh'
          : 'companies';

      final result = await _homeApiRepository.getAdsFeed(
        category: categoryString,
        page: _currentPage + 1,
        pageSize: 8,
        cityId: widget.cityId,
        regionId: widget.regionId,
        countryId: widget.countryId,
      );

      if (result.success && result.data != null) {
        setState(() {
          _allAds.addAll(result.data!.ads);
          _hasNext = result.data!.hasNext;
          _currentPage++;
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  Widget _buildLoadingIndicator() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xff917dfa)),
              ),
            ),
            SizedBox(height: 10),
            Text(
              'Загрузка',
              style: GoogleFonts.montserrat(fontSize: 16, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final category = context.read<FeedBloc>().state.category;
    if (category == FeedCategory.companies) {
      return _ShopsSliverList();
    }

    if (_isLoading) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red.shade700),
                SizedBox(height: 16),
                Text('Ошибка: $_error', style: GoogleFonts.montserrat()),
                SizedBox(height: 16),
                ElevatedButton(onPressed: _loadFeed, child: Text('Повторить')),
              ],
            ),
          ),
        ),
      );
    }

    if (_allAds.isEmpty) {
      return SliverToBoxAdapter(
        child: SizedBox(
          height: 200,
          child: Center(
            child: Text('Нет данных', style: GoogleFonts.montserrat()),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      sliver: SliverGrid(
        delegate: SliverChildBuilderDelegate((context, index) {
          final ad = _allAds[index];
          return AdListing(ad: ad);
        }, childCount: _allAds.length),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 0.5225,
        ),
      ),
    );
  }
}

// ==================== ШОПЫ (КОМПАНИИ) ====================

class _ShopsSliverList extends StatelessWidget {
  const _ShopsSliverList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FeedBloc, FeedState>(
      builder: (context, state) {
        final shops = state.shops;

        print('📋 [ShopList] Total shops: ${shops.length}');

        // 👇 ДОБАВЛЯЕМ ДЕТАЛЬНЫЙ ЛОГ КАЖДОГО МАГАЗИНА
        for (var i = 0; i < shops.length; i++) {
          final shop = shops[i];
          print(
            '📋 [ShopList] Shop #$i: ID=${shop.id}, Title="${shop.title}", Logo=${shop.logo?.substring(0, 30) ?? 'null'}...',
          );
        }

        if (shops.isEmpty) {
          return const SliverToBoxAdapter(
            child: SizedBox(
              height: 300,
              child: Center(
                child: Text(
                  'Магазины не найдены',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final shop = shops[index];
              return _ShopListCard(shop: shop);
            }, childCount: shops.length),
          ),
        );
      },
    );
  }
}

class Feed extends StatelessWidget {
  final ScrollController? scrollController;
  final int? cityId;
  final int? regionId;
  final int? countryId;

  const Feed({
    super.key,
    this.scrollController,
    this.cityId,
    this.regionId,
    this.countryId,
  });

  @override
  Widget build(BuildContext context) {
    return FeedView(
      scrollController: scrollController,
      cityId: cityId,
      regionId: regionId,
      countryId: countryId,
    );
  }
}

// ==================== КАРТОЧКА МАГАЗИНА ====================

class _ShopListCard extends StatelessWidget {
  final Shop shop;

  const _ShopListCard({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    final bannerUrl = shop.banner ?? shop.bannerUrl;

    print('🔴🔴🔴 [_ShopListCard] ${shop.title}:');
    print('   avatarUrl: ${shop.avatarUrl}');
    print('   banner: ${shop.banner}');
    print('   description: ${shop.description}');

    return GestureDetector(
      onTap: () {
        GoRouter.of(context).push('/shop/${shop.id}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          image: bannerUrl != null && bannerUrl.isNotEmpty
              ? DecorationImage(
                  image: NetworkImage(bannerUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withOpacity(0.5),
                    BlendMode.darken,
                  ),
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Аватарка
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: CachedNetworkImage(
                imageUrl: shop.avatarUrl ?? '',
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[300],
                  child: const Icon(Icons.store, color: Colors.grey),
                ),
                errorWidget: (_, __, ___) => Container(
                  width: 80,
                  height: 80,
                  color: Colors.grey[300],
                  child: const Icon(Icons.store, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Информация
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Название
                  Text(
                    shop.title,
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  // ✅ Описание (3 строки, 80 символов)
                  if (shop.description != null && shop.description!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        shop.description!,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                          height: 1.3,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),

                  // ✅ Статистика в одну строку (объявления + подписчики)
                  Row(
                    children: [
                      // Количество объявлений
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "${shop.adsCount} ${_pluralize(shop.adsCount)}",
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Количество подписчиков
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(width: 4),
                            Text(
                              "${shop.subscribersCount} ${_pluralizeSubscribers(shop.subscribersCount)}",
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Стрелка
          ],
        ),
      ),
    );
  }

  String _pluralize(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'объявление';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100))
      return 'объявления';
    return 'объявлений';
  }

  String _pluralizeSubscribers(int count) {
    if (count % 10 == 1 && count % 100 != 11) return 'подписчик';
    if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100))
      return 'подписчика';
    return 'подписчиков';
  }
}
