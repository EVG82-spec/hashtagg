import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/shared/presentation/bloc/subscriptions_bloc.dart';
import 'package:hive/hive.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/core/network/shops_api_repository.dart';
import 'package:hashtagg/core/network/profile_api_repository.dart';
import 'package:hashtagg/core/network/home_api_repository.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hashtagg/features/chats/screens/chat_screen.dart';
import 'package:hashtagg/features/chats/bloc/chat_bloc.dart';
import 'package:hashtagg/features/home/widgets/ad_listing.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/shared/presentation/screens/webview_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ShopDetailScreen extends StatefulWidget {
  final String shopId;

  const ShopDetailScreen({super.key, required this.shopId});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  final ShopsApiRepository _shopsApi = ShopsApiRepository();
  final ProfileApiRepository _profileApi = ProfileApiRepository();
  final PageController _pageController = PageController();
  final ScrollController _tabScrollController = ScrollController();

  Map<String, dynamic>? _shop;
  List<Map<String, dynamic>> _ads = [];
  bool _isLoading = true;
  bool _isSubscribed = false;
  int _currentSliderIndex = 0;
  int _selectedTabIndex = 0; // 0 = Объявления, 1+ = страницы магазина

  @override
  void dispose() {
    _pageController.dispose();
    _tabScrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    setState(() => _isLoading = true);

    try {
      final box = await Hive.openBox('user');
      final token = box.get('auth_token') as String?;

      // Получаем userId из объекта user
      final userData = box.get('user');
      int? userId;
      if (userData is Map) {
        userId = userData['id'] is int
            ? userData['id']
            : int.tryParse(userData['id']?.toString() ?? '0');
      }

      final result = await _shopsApi.getShop(
        shopId: widget.shopId,
        userId: userId,
        token: token,
      );

      if (result['status'] == true && mounted) {
        setState(() {
          _shop = result['data'];
          _isSubscribed = _shop?['in_subscribers'] ?? false;
        });

        // Загружаем объявления пользователя магазина
        if (_shop != null) {
          await _loadAds();
        }
      }
    } catch (e) {
      print('🔴 [ShopDetail] Error loading shop: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadAds() async {
    try {
      final shopUserIdRaw = _shop!['user']['id'];
      final shopUserId = shopUserIdRaw is int
          ? shopUserIdRaw
          : int.tryParse(shopUserIdRaw?.toString() ?? '0');

      if (shopUserId == null) {
        print('🔴 [ShopDetail] Invalid shop user ID');
        return;
      }

      print('🔵 [ShopDetail] Loading ads for user: $shopUserId');

      final result = await _profileApi.getUserAds(userId: shopUserId);

      if (result['status'] == true && mounted) {
        setState(() {
          _ads = List<Map<String, dynamic>>.from(result['data'] ?? []);
        });
        print('✅ [ShopDetail] Loaded ${_ads.length} ads');
      }
    } catch (e) {
      print('🔴 [ShopDetail] Error loading ads: $e');
    }
  }

  Future<void> _toggleSubscription() async {
    if (_shop == null) return;

    try {
      final box = await Hive.openBox('user');
      final token = box.get('auth_token') as String?;
      final userData = box.get('user');
      int? userId;
      if (userData is Map) {
        userId = userData['id'] is int
            ? userData['id']
            : int.tryParse(userData['id']?.toString() ?? '0');
      }

      if (token == null || userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Необходима авторизация')),
          );
        }
        return;
      }

      final shopUserIdRaw = _shop!['user']['id'];
      final shopUserId = shopUserIdRaw is int
          ? shopUserIdRaw
          : int.tryParse(shopUserIdRaw?.toString() ?? '0');

      if (shopUserId == null) return;

      // ✅ ВЫЗЫВАЕМ API
      final result = await _profileApi.toggleSubscribe(
        token: token,
        userIdFrom: userId,
        userIdTo: shopUserId,
      );

      if (mounted && result['success'] == true) {
        final status = result['status'];
        final isSubscribed = (status == 'added');

        // ✅ ОБНОВЛЯЕМ LOCAL STATE
        setState(() {
          _isSubscribed = isSubscribed;
          final currentCount = _shop!['subscribers_count'] ?? 0;
          _shop!['subscribers_count'] = isSubscribed
              ? currentCount + 1
              : currentCount - 1;
        });

        // ✅ СИНХРОНИЗИРУЕМ С BLOC
        final bloc = context.read<SubscriptionsBloc>();
        if (isSubscribed) {
          final user = User(
            id: shopUserId,
            name: _shop!['title'] ?? 'Магазин',
            avatar: _fixImageUrl(_shop!['logo']),
          );
          bloc.add(
            AddSubscription(
              userId: shopUserId, // 👈 ВЛАДЕЛЕЦ МАГАЗИНА
              shopId: _shop!['id'], // 👈 ID МАГАЗИНА
              user: user,
            ),
          );
        } else {
          bloc.add(RemoveSubscription(shopUserId));
        }
      }
    } catch (e) {
      print('❌ [ShopDetail] Error toggling subscription: $e');
    }
  }

  Future<void> _openChat() async {
    if (_shop == null) return;

    try {
      final box = await Hive.openBox('user');
      final token = box.get('auth_token') as String?;

      // Получаем userId из объекта user
      final userData = box.get('user');
      int? userId;
      if (userData is Map) {
        userId = userData['id'] is int
            ? userData['id']
            : int.tryParse(userData['id']?.toString() ?? '0');
      }

      if (token == null || userId == null) {
        if (mounted) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Необходима авторизация',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: isDark ? const Color(0xff233040) : null,
            ),
          );
        }
        return;
      }

      final shopUserIdRaw = _shop!['user']['id'];
      final shopUserId = shopUserIdRaw is int
          ? shopUserIdRaw
          : int.tryParse(shopUserIdRaw?.toString() ?? '0');

      if (shopUserId == null) {
        print('🔴 [ShopDetail] Invalid user IDs for chat');
        return;
      }

      final shopName = _shop!['title'] ?? 'Магазин';
      final shopAvatar = _fixImageUrl(_shop!['logo']);

      print('🔵 [ShopDetail] Opening chat with shop user: $shopUserId');

      if (!mounted) return;

      // Используем существующий ChatBloc из контекста (уже инициализирован с authBloc)
      final chatBloc = context.read<ChatBloc>();

      // Формируем dialogId (hash_id диалога) - используем формат как в listing_screen
      final dialogId = 'u${shopUserId}_$userId';

      // Загружаем диалог (создастся автоматически если не существует)
      chatBloc.add(LoadDialog(dialogId: dialogId, userToId: shopUserId));

      // Ждем загрузки
      await Future.delayed(Duration(milliseconds: 500));

      if (!mounted) return;

      if (chatBloc.state.currentDialog != null) {
        final dialog = chatBloc.state.currentDialog!;

        // Открываем экран чата
        await Navigator.of(context).push(
          createSwipeableRoute(
            builder: (_) => BlocProvider.value(
              value: chatBloc,
              child: ChatScreen(
                userName: dialog.user?.name ?? shopName,
                lastSeen: dialog.user?.statusOnline ?? 'Магазин',
                avatarUrl: dialog.user?.avatar ?? shopAvatar,
                listing: ChatListing(
                  title: shopName,
                  price: '',
                  status: 'Магазин',
                  imageUrl: shopAvatar.isNotEmpty ? shopAvatar : null,
                  listingId: null,
                ),
                dialogId: dialog.idHash,
                userId: dialog.user?.id ?? shopUserId,
                isShop: true,
              ),
            ),
          ),
        );
      } else {
        print('🔴 [ShopDetail] Failed to load dialog');
        if (mounted) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Не удалось открыть чат',
                style: TextStyle(color: Colors.white),
              ),
              backgroundColor: isDark ? const Color(0xff233040) : null,
            ),
          );
        }
      }
    } catch (e) {
      print('🔴 [ShopDetail] Error opening chat: $e');
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка открытия чата',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: isDark ? const Color(0xff233040) : null,
          ),
        );
      }
    }
  }

  String _fixImageUrl(String? url) {
    if (url == null) return '';
    return ApiConfig.replaceMediaUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff151e27) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;

    // Получаем слайдеры заранее для проверки
    final sliders = _shop?['sliders'] as List?;
    final hasSliders = sliders != null && sliders.isNotEmpty;
    final sliderUrls = hasSliders
        ? sliders!
              .map((s) => _fixImageUrl(s.toString()))
              .where((url) => url.isNotEmpty)
              .toList()
        : <String>[];
    final hasBanner = sliderUrls.isNotEmpty;

    return Scaffold(
      backgroundColor: bgColor,
      extendBodyBehindAppBar:
          hasBanner, // Расширяем body за AppBar если есть баннер
      appBar: AppBar(
        backgroundColor: hasBanner ? Colors.transparent : bgColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: hasBanner ? Colors.white : textColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        systemOverlayStyle: hasBanner
            ? SystemUiOverlayStyle.light
            : (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xff917dfa)))
          : _shop == null
          ? Center(child: Text('Магазин не найден'))
          : RefreshIndicator(
              onRefresh: _loadShop,
              color: Color(0xff917dfa),
              edgeOffset: 40.0,
              displacement: 20.0,
              strokeWidth: 3.0,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildHeader(),
                    SizedBox(height: 20),
                    _buildStats(),
                    SizedBox(height: 20),
                    _buildSocialLinks(),
                    SizedBox(height: 20),
                    _buildButtons(),
                    SizedBox(height: 30),
                    _buildPageTabs(),
                    SizedBox(height: 20),
                    _buildContent(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final subtitleColor = isDark ? Colors.white70 : Colors.grey[600];

    final logo = _fixImageUrl(_shop!['logo']);
    final title = _shop!['title'] ?? '';
    final desc = _shop!['desc'] ?? '';

    // Получаем все слайдеры
    final sliders = _shop!['sliders'] as List?;
    final hasSliders = sliders != null && sliders.isNotEmpty;

    // Преобразуем слайдеры в список URL
    final sliderUrls = hasSliders
        ? sliders!
              .map((s) => _fixImageUrl(s.toString()))
              .where((url) => url.isNotEmpty)
              .toList()
        : <String>[];

    final hasBanner = sliderUrls.isNotEmpty;

    return Stack(
      children: [
        // Слайдер баннеров (если есть)
        if (hasBanner)
          Container(
            width: double.infinity,
            height: 380,
            child: Stack(
              children: [
                // PageView для слайдера
                PageView.builder(
                  controller: _pageController,
                  itemCount: sliderUrls.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentSliderIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40),
                      ),
                      child: Stack(
                        children: [
                          // Изображение баннера
                          Image.network(
                            sliderUrls[index],
                            width: double.infinity,
                            height: 380,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                                child: Icon(
                                  Icons.image,
                                  size: 50,
                                  color: Colors.grey,
                                ),
                              );
                            },
                          ),
                          // Затемнение для читаемости текста
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.3),
                                  Colors.black.withOpacity(0.6),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),

                // Индикаторы слайдера (если больше 1 слайда)
                if (sliderUrls.length > 1)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(sliderUrls.length, (index) {
                        return Container(
                          margin: EdgeInsets.symmetric(horizontal: 4),
                          width: _currentSliderIndex == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentSliderIndex == index
                                ? Colors.white
                                : Colors.white.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),

        // Контент поверх баннера
        Padding(
          padding: EdgeInsets.only(
            top: hasBanner ? MediaQuery.of(context).padding.top + 56 + 20 : 20,
            bottom: 20,
          ),
          child: Column(
            children: [
              // Логотип
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasBanner
                      ? Colors.white24
                      : (isDark ? Colors.white24 : Colors.grey[200]),
                  border: hasBanner
                      ? Border.all(color: Colors.white, width: 3)
                      : null,
                  image: logo.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(logo),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: logo.isEmpty
                    ? Icon(
                        Icons.store,
                        color: hasBanner
                            ? Colors.white
                            : (isDark ? Colors.white54 : Colors.grey),
                        size: 50,
                      )
                    : null,
              ),
              SizedBox(height: 12),

              // Название
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: hasBanner ? Colors.white : textColor,
                ),
                textAlign: TextAlign.center,
              ),

              // Описание
              if (desc.isNotEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40, vertical: 4),
                  child: Text(
                    desc,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: hasBanner
                          ? Colors.white.withOpacity(0.9)
                          : subtitleColor,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

              SizedBox(height: 8),

              // Рейтинг (пока пустой)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return Icon(
                    Icons.star_border,
                    color: hasBanner
                        ? Colors.white70
                        : (isDark ? Colors.white54 : Colors.grey),
                    size: 20,
                  );
                }),
              ),

              SizedBox(height: 4),

              // Количество отзывов
              Text(
                '0 отзывов',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: hasBanner ? Colors.white70 : subtitleColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildButtons() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Кнопка "Написать"
          GestureDetector(
            onTap: () => _openChat(),
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Color(0xff917dfa),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Написать',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12),

          // Кнопка "Подписаться"
          InkWell(
            onTap: _toggleSubscription,
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _isSubscribed
                    ? (isDark
                          ? const Color(0xff233040)
                          : const Color(0xfff0f0f0))
                    : const Color(0xff917dfa),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                _isSubscribed ? 'Отписаться' : 'Подписаться',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _isSubscribed
                      ? (isDark ? Colors.white : const Color(0xff666666))
                      : Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageTabs() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pages = _shop!['pages'] as List?;

    // Если нет страниц, показываем только вкладку "Объявления"
    if (pages == null || pages.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          height: 45,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Color(0xff917dfa),
            borderRadius: BorderRadius.circular(25),
            border: Border.all(color: Color(0xff917dfa)),
          ),
          child: Center(
            child: Text(
              'Объявления',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 45,
      child: ListView.builder(
        controller: _tabScrollController,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 20),
        itemCount: pages.length + 1, // +1 для вкладки "Объявления"
        itemBuilder: (context, index) {
          final isSelected = _selectedTabIndex == index;
          final isAdsTab = index == 0;
          final tabName = isAdsTab
              ? 'Объявления'
              : pages[index - 1]['name'] as String;

          return GestureDetector(
            onTap: () {
              if (isAdsTab) {
                // Вкладка "Объявления" - просто переключаем
                setState(() {
                  _selectedTabIndex = 0;
                });
              } else {
                // Вкладка страницы - открываем WebView
                final page = pages[index - 1];
                final pageAlias = page['alias'] as String?;
                final shopIdHash = _shop!['id_hash'] as String;

                // Формируем URL страницы магазина: /shop/shopslug/page/pageslug
                final pageUrl =
                    'https://hashtagg.ru/shop/$shopIdHash/page/$pageAlias';

                Navigator.of(context).push(
                  createSwipeableRoute(
                    builder: (_) => WebViewScreen(url: pageUrl, title: tabName),
                  ),
                );
              }
            },
            child: Container(
              margin: EdgeInsets.only(right: 12),
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? Color(0xff917dfa)
                    : (isDark ? Colors.grey[850] : Colors.white),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected
                      ? Color(0xff917dfa)
                      : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                ),
              ),
              child: Center(
                child: Text(
                  tabName,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isSelected
                        ? Colors.white
                        : (isDark ? Colors.white : Colors.black),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildContent() {
    // Всегда показываем объявления, так как страницы открываются в WebView
    return _buildAdsSection();
  }

  Widget _buildStats() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Парсим количество объявлений из строки "5 объявлений"
    final countAdsStr = _shop!['count_ads']?.toString() ?? '0';
    final adsCount = int.tryParse(countAdsStr.split(' ').first) ?? 0;
    final subscribersCount = _shop!['subscribers_count'] ?? 0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Первый ряд: Объявления и Товары
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.shopping_bag_outlined,
                    value: adsCount.toString(),
                    label: 'Объявления',
                    isDark: isDark,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    icon: Icons.inventory_2_outlined,
                    value: adsCount.toString(),
                    label: 'Товары',
                    isDark: isDark,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 12),
          // Второй ряд: Подписчики на всю ширину
          SizedBox(
            width: double.infinity,
            child: _buildStatCard(
              icon: Icons.people_outline,
              value: subscribersCount.toString(),
              label: 'Подписчики',
              isDark: isDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required bool isDark,
  }) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.max,
        children: [
          Icon(icon, color: Color(0xff917dfa), size: 24),
          SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.montserrat(fontSize: 11, color: Colors.grey),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSocialLinks() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Получаем ссылки из API
    final link1Text = _shop!['link_1_text'] as String?;
    final link1Link = _shop!['link_1_link'] as String?;
    final link1Image = _shop!['link_1_image'] as String?;

    final link2Text = _shop!['link_2_text'] as String?;
    final link2Link = _shop!['link_2_link'] as String?;
    final link2Image = _shop!['link_2_image'] as String?;

    final link3Text = _shop!['link_3_text'] as String?;
    final link3Link = _shop!['link_3_link'] as String?;
    final link3Image = _shop!['link_3_image'] as String?;

    final links = <Map<String, String?>>[];

    if ((link1Text?.isNotEmpty ?? false) || (link1Link?.isNotEmpty ?? false)) {
      links.add({'text': link1Text, 'link': link1Link, 'image': link1Image});
    }
    if ((link2Text?.isNotEmpty ?? false) || (link2Link?.isNotEmpty ?? false)) {
      links.add({'text': link2Text, 'link': link2Link, 'image': link2Image});
    }
    if ((link3Text?.isNotEmpty ?? false) || (link3Link?.isNotEmpty ?? false)) {
      links.add({'text': link3Text, 'link': link3Link, 'image': link3Image});
    }

    if (links.isEmpty) return SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.grey[850] : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ссылки',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            SizedBox(height: 12),
            ...links.map(
              (link) => _buildSocialLink(
                text: link['text'] ?? '',
                url: link['link'] ?? '',
                imageUrl: link['image'],
                isDark: isDark,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLink({
    required String text,
    required String url,
    String? imageUrl,
    required bool isDark,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () async {
          if (url.isNotEmpty) {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          }
        },
        child: Row(
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              Image.network(
                _fixImageUrl(imageUrl),
                width: 20,
                height: 20,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.link, size: 20, color: Color(0xff917dfa));
                },
              )
            else
              Icon(Icons.link, size: 20, color: Color(0xff917dfa)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                text.isNotEmpty ? text : url,
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  color: Color(0xff917dfa),
                  decoration: TextDecoration.underline,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildAdsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Text(
                'Объявления',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),

        if (_ads.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text(
                'Нет объявлений',
                style: GoogleFonts.montserrat(fontSize: 14, color: Colors.grey),
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: 10),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.5225, // Как в feed.dart
            ),
            itemCount: _ads.length,
            itemBuilder: (context, index) {
              final ad = _ads[index];
              return _buildAdCard(ad);
            },
          ),

        SizedBox(height: 100),
      ],
    );
  }

  Widget _buildAdCard(Map<String, dynamic> ad) {
    // Преобразуем данные в FeedAd
    final feedAd = FeedAd.fromJson(ad);

    return AdListing(ad: feedAd);
  }
}
