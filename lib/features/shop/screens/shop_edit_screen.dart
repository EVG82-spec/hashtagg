// lib/features/shop/screens/shop_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_state.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_event.dart';
import 'package:hashtagg/features/shop/bloc/shop_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_event.dart';
import 'package:hashtagg/features/shop/bloc/shop_state.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/features/shop/widgets/shop_actions.dart';
import 'package:hashtagg/features/shop/widgets/shop_banner.dart';
import 'package:hashtagg/features/shop/widgets/shop_profile.dart';
import 'package:hashtagg/features/shop/widgets/shop_social_edit_modal.dart';
import 'package:hashtagg/features/shop/widgets/shop_social_icons.dart';
import 'package:hashtagg/features/shop/widgets/shop_stats.dart';
import 'package:hashtagg/features/shop/widgets/shop_navigation.dart';
import 'package:hashtagg/features/shop/widgets/shop_ads_grid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import 'package:dio/dio.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:hashtagg/features/shop/screens/shop_page_edit_screen.dart';
import 'dart:async';

class ShopEditScreen extends StatefulWidget {
  final String shopId;

  const ShopEditScreen({Key? key, required this.shopId}) : super(key: key);

  @override
  State<ShopEditScreen> createState() => _ShopEditScreenState();
}

class _ShopEditScreenState extends State<ShopEditScreen> {
  final ImagePicker _picker = ImagePicker();
  late ShopPublicBloc _shopPublicBloc;
  late TextEditingController _titleController;
  Shop? _currentShop;
  int? _selectedPageId;
  String? _selectedPageContent;
  StreamSubscription<ShopState>? _shopBlocSubscription; // 👈 ДОБАВИТЬ!

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _initBloc();
    _loadShopData();

    // ✅ ПОДПИСКА НА ShopBloc
    _shopBlocSubscription = context.read<ShopBloc>().stream.listen((state) {
      if (state is ShopLoaded) {
        print('🔄 [ShopEdit] ShopLoaded received');
        setState(() {
          _currentShop = state.shop;
          _titleController.text = state.shop.title;
        });
      } else if (state is ShopEditDataLoaded) {
        print('🔄 [ShopEdit] ShopEditDataLoaded received');
        final shop = Shop.fromJson(state.data);
        setState(() {
          _currentShop = shop;
          _titleController.text = shop.title;
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _shopBlocSubscription?.cancel(); // 👈 ОТПИСКА
    super.dispose();
  }

  void _initBloc() {
    final dio = Dio(
      BaseOptions(
        baseUrl: 'https://hashtagg.ru',
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      ),
    );
    final repository = ShopApiRepository(dio);
    _shopPublicBloc = ShopPublicBloc(repository);
  }

  void _loadShopData() {
    print('🔄 [ShopEdit] _loadShopData() called');
    _shopPublicBloc.add(LoadPublicShop(shopId: widget.shopId));
  }

  // ===== МЕТОДЫ РЕДАКТИРОВАНИЯ =====

  void _pickBannerImage() async {
    print('📸📸📸 [ShopEdit] _pickBannerImage() START');

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    print('📸 [ShopEdit] Image picked: ${image?.path}');

    if (image == null) {
      print('⚠️ [ShopEdit] No image selected');
      return;
    }

    if (_currentShop == null) {
      print('⚠️ [ShopEdit] _currentShop is null');
      return;
    }

    print(
      '👤 [ShopEdit] Current shop: ${_currentShop!.id} - ${_currentShop!.title}',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final box = Hive.box('user');
      final userData = box.get('user');
      final token = box.get('auth_token');
      final userId = userData?['id'] as int? ?? 0;

      print('🔑 [ShopEdit] userId: $userId');
      print('🔑 [ShopEdit] token: ${token?.substring(0, 10)}...');
      print('📂 [ShopEdit] filePath: ${image.path}');

      // 1. Загружаем баннер на сервер
      print('📤 [ShopEdit] Uploading banner...');
      final result = await _shopPublicBloc.repository.uploadShopImage(
        filePath: image.path,
        userId: userId,
        token: token,
        shopHash: _currentShop!.idHash,
        type: 'banner',
      );

      print('📦 [ShopEdit] upload result: $result');

      Navigator.pop(context); // Закрываем индикатор

      if (result['status'] == true && result['path'] != null) {
        print('✅ [ShopEdit] Banner uploaded successfully!');

        // ✅ ФОРМИРУЕМ ПОЛНЫЙ URL
        final baseUrl = 'https://hashtagg.ru';
        final fullPath = result['path']; // /media/users/474/shop/.../banner.jpg
        final fullUrl = '$baseUrl$fullPath';

        print('🔄 [ShopEdit] New banner URL: $fullUrl');
        // ✅ ОЧИЩАЕМ КЭШ ПЕРЕД ОБНОВЛЕНИЕМ
        await CachedNetworkImage.evictFromCache(fullUrl);
        print('🗑️ [ShopEdit] Cache evicted for: $fullUrl');

        // ✅ ОБНОВЛЯЕМ _currentShop СРАЗУ
        setState(() {
          _currentShop = _currentShop!.copyWith(
            sliders: [ShopSlider(name: 'Баннер', link: fullUrl)],
          );
          print('✅ [ShopEdit] _currentShop updated with new banner');
          print('   sliders: ${_currentShop?.sliders}');
        });

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Баннер обновлен!')));
      } else {
        print('🔍🔍🔍 [ShopEdit] BUILD - _currentShop:');
        print('   title: ${_currentShop?.title}');
        print('   logo: ${_currentShop?.logo}');
        print('   sliders: ${_currentShop?.sliders}');
        print(
          '   sliders[0]?.link: ${_currentShop?.sliders?.firstOrNull?.link}',
        );
        print('❌ [ShopEdit] upload failed: ${result['error']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Ошибка загрузки баннера'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌❌❌ [ShopEdit] ERROR: $e');
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _pickAvatarImage() async {
    print('📸📸📸 [ShopEdit] _pickAvatarImage() START');

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    print('📸 [ShopEdit] Avatar image picked: ${image?.path}');

    if (image == null) {
      print('⚠️ [ShopEdit] No avatar image selected');
      return;
    }

    if (_currentShop == null) {
      print('⚠️ [ShopEdit] _currentShop is null');
      return;
    }

    print(
      '👤 [ShopEdit] Current shop: ${_currentShop!.id} - ${_currentShop!.title}',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final box = Hive.box('user');
      final userData = box.get('user');
      final token = box.get('auth_token');
      final userId = userData?['id'] as int? ?? 0;

      print('🔑 [ShopEdit] userId: $userId');
      print('🔑 [ShopEdit] token: ${token?.substring(0, 10)}...');
      print('📂 [ShopEdit] filePath: ${image.path}');

      // 1. Загружаем аватар на сервер
      print('📤 [ShopEdit] Uploading avatar...');
      final result = await _shopPublicBloc.repository.uploadShopImage(
        filePath: image.path,
        userId: userId,
        token: token,
        shopHash: _currentShop!.idHash,
        type: 'avatar',
      );

      print('📦 [ShopEdit] upload result: $result');

      Navigator.pop(context); // Закрываем индикатор

      if (result['status'] == true && result['path'] != null) {
        print('✅ [ShopEdit] Avatar uploaded successfully!');

        // ✅ ФОРМИРУЕМ ПОЛНЫЙ URL
        final baseUrl = 'https://hashtagg.ru';
        final fullPath = result['path']; // /media/users/474/shop/.../avatar.jpg
        final fullUrl = '$baseUrl$fullPath';

        print('🔄 [ShopEdit] New avatar URL: $fullUrl');
        // ✅ ОЧИЩАЕМ КЭШ ПЕРЕД ОБНОВЛЕНИЕМ
        await CachedNetworkImage.evictFromCache(fullUrl);
        print('🗑️ [ShopEdit] Cache evicted for: $fullUrl');

        // ✅ ОБНОВЛЯЕМ _currentShop СРАЗУ
        setState(() {
          _currentShop = _currentShop!.copyWith(logo: fullUrl);
          print('✅ [ShopEdit] _currentShop updated with new avatar');
          print('   logo: ${_currentShop?.logo}');
        });

        print('🔍🔍🔍 [ShopEdit] BUILD - _currentShop:');
        print('   title: ${_currentShop?.title}');
        print('   logo: ${_currentShop?.logo}');
        print('   sliders: ${_currentShop?.sliders}');
        print(
          '   sliders[0]?.link: ${_currentShop?.sliders?.firstOrNull?.link}',
        );
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Аватарка обновлена!')));
      } else {
        print('❌ [ShopEdit] upload failed: ${result['error']}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Ошибка загрузки аватарки'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌❌❌ [ShopEdit] ERROR: $e');
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _editTitle() {
    if (_currentShop == null) return;

    final controller = TextEditingController(text: _currentShop?.title ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Редактировать название'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(hintText: 'Введите название магазина'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newTitle = controller.text.trim();
              if (newTitle.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Название не может быть пустым'),
                  ),
                );
                return;
              }

              Navigator.pop(context);

              print('📝📝📝 [ShopEdit] _editTitle() START');
              print('   newTitle: $newTitle');

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                final box = Hive.box('user');
                final userData = box.get('user');
                final token = box.get('auth_token');
                final userId = userData?['id'] as int? ?? 0;

                print('🔑 [ShopEdit] userId: $userId');
                print('🔑 [ShopEdit] token: ${token?.substring(0, 10)}...');

                final result = await _shopPublicBloc.repository
                    .updateShop(
                      userId: userId,
                      token: token,
                      shopId: _currentShop!.id,
                      title: newTitle,
                      description: _currentShop!.description,
                      links: _currentShop!.links, // 👈 ДОБАВИТЬ!
                    )
                    .timeout(
                      const Duration(seconds: 30),
                      onTimeout: () {
                        throw Exception('Превышено время ожидания');
                      },
                    );

                print('📦 [ShopEdit] updateShop result: $result');

                Navigator.pop(context); // Закрываем индикатор

                if (result['status'] == true) {
                  print('✅ [ShopEdit] Title updated successfully!');

                  // ✅ ОБНОВЛЯЕМ _currentShop
                  setState(() {
                    _currentShop = _currentShop!.copyWith(title: newTitle);
                  });

                  // ✅ ВМЕСТО _loadShopData() ИСПОЛЬЗУЕМ forceRefresh
                  _shopPublicBloc.add(
                    LoadPublicShop(shopId: widget.shopId, forceRefresh: true),
                  );

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Название обновлено!')),
                  );
                } else {
                  print('❌ [ShopEdit] updateShop failed: ${result['error']}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(result['error'] ?? 'Ошибка обновления'),
                    ),
                  );
                }
              } catch (e) {
                print('❌❌❌ [ShopEdit] ERROR: $e');
                Navigator.pop(context);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
              }
            },
            child: Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  void _addPage() {
    print('📄 [ShopEdit] Add new page');

    final shopId = _currentShop?.id;
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка: магазин не загружен')),
      );
      return;
    }

    // Открываем экран создания страницы
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ShopPageEditScreen(
          shopId: shopId,
          page: null, // null = создание новой
        ),
      ),
    ).then((result) {
      if (result == true && mounted) {
        print('✅ [ShopEdit] Page created');
        print(
          '🔄 [ShopEdit] _addPage: calling LoadPublicShop with forceRefresh=true',
        );
        print('✅ [ShopEdit] Page created, reloading shop data');

        // ✅ ПРИНУДИТЕЛЬНО ПЕРЕЗАГРУЖАЕМ
        _shopPublicBloc.add(
          LoadPublicShop(shopId: widget.shopId, forceRefresh: true),
        );

        // ✅ ПОКАЗЫВАЕМ СООБЩЕНИЕ
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Страница создана!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  List<ShopLink>? _getCurrentLinks() {
    return _currentShop?.links;
  }

  void _saveShop() async {
    print('💾 [ShopEdit] Save changes');

    final newTitle = _titleController.text.trim();

    if (newTitle.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Название не может быть пустым')),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final box = Hive.box('user');
      final userData = box.get('user');
      final token = box.get('auth_token');
      final userId = userData?['id'] as int? ?? 0;

      // ✅ ОТПРАВЛЯЕМ НА МОДЕРАЦИЮ (status = 0)
      final result = await _shopPublicBloc.repository.updateShop(
        userId: userId,
        token: token,
        shopId: _currentShop!.id,
        title: newTitle,
        description: _currentShop!.description,
        links: _getCurrentLinks(), // 👈 ДОБАВИТЬ!
        // 👇 ДОБАВЛЯЕМ СТАТУС
        status: 0, // 0 - на модерации
      );

      Navigator.pop(context); // Закрываем индикатор

      if (result['status'] == true) {
        print('✅ [ShopEdit] Shop sent to moderation!');

        setState(() {
          _currentShop = _currentShop!.copyWith(title: newTitle, status: 0);
        });

        // ✅ ЖДЕМ ОБНОВЛЕНИЯ ShopPublicBloc
        print('🔄 [ShopEdit] Waiting for ShopPublicBloc refresh...');

        final completer = Completer<void>();
        late final StreamSubscription<ShopPublicState> subscription;

        subscription = _shopPublicBloc.stream.listen((state) {
          if (state is ShopPublicLoaded) {
            print(
              '✅ [ShopEdit] ShopPublicBloc refreshed, status: ${state.shop.status}',
            );
            subscription.cancel();
            completer.complete();
          }
        });
        print(
          '🔄 [ShopEdit] _saveShop: calling LoadPublicShop with forceRefresh=true',
        );
        _shopPublicBloc.add(
          LoadPublicShop(shopId: widget.shopId, forceRefresh: true),
        );
        print('✅ [ShopEdit] _saveShop: LoadPublicShop event sent');

        await completer.future.timeout(const Duration(seconds: 5));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Изменения сохранены! Магазин отправлен на модерацию',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Ошибка сохранения')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Редактирование магазина',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          // ✅ КНОПКА СОХРАНИТЬ (вместо Управления)
          ElevatedButton(
            onPressed: _saveShop,
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF8956FF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: Text(
              'Сохранить',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
      body: BlocBuilder<ShopPublicBloc, ShopPublicState>(
        bloc: _shopPublicBloc,
        builder: (context, state) {
          if (state is ShopPublicLoading) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF8956FF),
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Загрузка магазина...',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                ],
              ),
            );
          }

          if (state is ShopPublicLoaded) {
            print('🔍🔍🔍 [ShopEdit] BUILD - state is ShopPublicLoaded');
            print('   state.shop.logo: ${state.shop.logo}');
            print('   state.shop.avatarUrl: ${state.shop.avatarUrl}');
            print('   _currentShop?.logo: ${_currentShop?.logo}');
            print('   _currentShop?.avatarUrl: ${_currentShop?.avatarUrl}');
            if (_currentShop == null) {
              print('🔄 [ShopEdit] Setting _currentShop from state');
              _currentShop = state.shop;
              _titleController.text = state.shop.title;
            }
            final shop = _currentShop!; // 👈 ВАЖНО!
            print('✅ [ShopEdit] Using _currentShop:');
            print('   shop.logo: ${shop.logo}');
            print('   shop.avatarUrl: ${shop.avatarUrl}');
            final ads = state.ads; // Товары берем из state

            return CustomScrollView(
              slivers: [
                // 1. Баннер (кликабельный)
                SliverToBoxAdapter(
                  child: ShopBanner(
                    shop: shop,
                    isEditing: true,
                    onBannerTap: _pickBannerImage,
                  ),
                ),
                // 2. Профиль (кликабельный)
                SliverToBoxAdapter(
                  child: ShopProfile(
                    shop: shop,
                    isEditing: true,
                    onAvatarTap: _pickAvatarImage,
                    onTitleTap: _editTitle,
                    titleController: _titleController,
                  ),
                ),
                // 3. Статистика
                SliverToBoxAdapter(child: ShopStats(shop: shop)),
                // 4. Соцсети (кликабельные)
                SliverToBoxAdapter(
                  child: ShopActions(
                    shop: shop,
                    isEditing: true,
                    onSocialEdit: _editSocialLinks,
                  ),
                ),
                // 5. Навигация (Главная + страницы + кнопка Добавить страницу)
                SliverToBoxAdapter(
                  child: ShopNavigation(
                    shop: shop,
                    isEditing: true,
                    onAddPage: _addPage,
                    onPageSelected: _onPageSelected,
                    onPageEdit: _onPageEdit,
                    currentPageId: _selectedPageId,
                  ),
                ),
                // 6. Контент страницы (если выбрана)
                if (_selectedPageId != null &&
                    _selectedPageId != 0 &&
                    _selectedPageContent != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          _selectedPageContent!,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.6,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),

                // 7. Товары (только если на главной)
                if (_selectedPageId == null || _selectedPageId == 0)
                  SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    sliver: ShopAdsGrid(ads: ads),
                  ),
              ],
            );
          }

          if (state is ShopPublicError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey.shade400,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Ошибка загрузки',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    state.message,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _loadShopData,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF8956FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    child: Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _onPageSelected(int pageId) {
    print('📄 [ShopEdit] _onPageSelected: $pageId');

    setState(() {
      _selectedPageId = pageId;
    });

    if (pageId == 0) {
      // Главная - показываем товары
      setState(() {
        _selectedPageContent = null;
      });
    } else {
      // Ищем страницу по id
      final page = _currentShop?.pages?.firstWhere(
        (p) => p.id == pageId,
        orElse: () => null as ShopPage, // 👈 ИСПРАВЛЕНО!
      );

      if (page != null) {
        setState(() {
          _selectedPageContent = page.text;
        });
        print('📄 [ShopEdit] Page content length: ${page.text.length}');
      } else {
        setState(() {
          _selectedPageContent = null;
        });
        print('⚠️ [ShopEdit] Page not found: $pageId');
      }
    }
  }

  void _onPageEdit(int pageId) {
    print('✏️ [ShopEdit] _onPageEdit: $pageId');

    final page = _currentShop?.pages?.firstWhere(
      (p) => p.id == pageId,
      orElse: () => null as ShopPage,
    );

    if (page != null) {
      print('📄 [ShopEdit] Editing page: ${page.name}');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              ShopPageEditScreen(shopId: _currentShop!.id, page: page),
        ),
      ).then((result) {
        if (result == true && mounted) {
          print('✅ [ShopEdit] Page updated');
          print(
            '🔄 [ShopEdit] _onPageEdit: calling LoadPublicShop with forceRefresh=true',
          );
          print('✅ [ShopEdit] Page updated, reloading ALL shop data');

          // ✅ ПРИНУДИТЕЛЬНО ПЕРЕЗАГРУЖАЕМ ShopPublicBloc (forceRefresh = true)
          _shopPublicBloc.add(
            LoadPublicShop(
              shopId: widget.shopId,
              forceRefresh: true, // 👈 ВАЖНО!
            ),
          );
          print('✅ [ShopEdit] _onPageEdit: LoadPublicShop event sent');

          // ✅ ОБНОВЛЯЕМ _currentShop через ShopBloc
          final box = Hive.box('user');
          final userData = box.get('user');
          final token = box.get('auth_token');
          final userId = userData?['id'] as int? ?? 0;

          context.read<ShopBloc>().add(
            LoadShop(userId: userId, token: token, shopId: _currentShop!.id),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Страница обновлена!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      });
    } else {
      print('❌ [ShopEdit] Page not found: $pageId');
    }
  }

  void _editSocialLinks() {
    print('🔗 [ShopEdit] Edit social links');

    if (_currentShop == null) return;

    print('   _currentShop.links: ${_currentShop?.links}');

    showDialog(
      context: context,
      builder: (_) => ShopSocialEditModal(
        shop: _currentShop!,
        repository: _shopPublicBloc.repository,
      ),
    ).then((result) async {
      if (result == true && mounted) {
        print('✅ [ShopEdit] Social links updated');

        // ✅ ПРИНУДИТЕЛЬНО ОБНОВЛЯЕМ _currentShop
        _shopPublicBloc.add(
          LoadPublicShop(shopId: widget.shopId, forceRefresh: true),
        );

        // ✅ ЖДЕМ ОБНОВЛЕНИЯ И ОБНОВЛЯЕМ _currentShop
        final completer = Completer<void>();
        late final StreamSubscription<ShopPublicState> subscription;

        subscription = _shopPublicBloc.stream.listen((state) {
          if (state is ShopPublicLoaded) {
            print('✅ [ShopEdit] ShopPublicBloc refreshed for social links');
            setState(() {
              _currentShop = state.shop;
            });
            print('   _currentShop.links: ${_currentShop?.links}');
            subscription.cancel();
            completer.complete();
          }
        });

        await completer.future.timeout(const Duration(seconds: 5));

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Соцсети обновлены!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }
}
