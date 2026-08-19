// lib/features/shop/screens/shop_edit_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_state.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_event.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/features/shop/widgets/shop_banner.dart';
import 'package:hashtagg/features/shop/widgets/shop_profile.dart';
import 'package:hashtagg/features/shop/widgets/shop_stats.dart';
import 'package:hashtagg/features/shop/widgets/shop_actions.dart';
import 'package:hashtagg/features/shop/widgets/shop_navigation.dart';
import 'package:hashtagg/features/shop/widgets/shop_ads_grid.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive/hive.dart';
import 'package:dio/dio.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';

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

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _initBloc();
    _loadShopData();
  }

  @override
  void dispose() {
    _titleController.dispose();
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

              // Закрываем диалог с названием
              Navigator.pop(context);

              print('📝📝📝 [ShopEdit] _editTitle() START');
              print('   newTitle: $newTitle');

              // Показываем индикатор загрузки
              final loadingDialog = showDialog(
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

                // ✅ ДОБАВЛЯЕМ TIMEOUT
                final result = await _shopPublicBloc.repository
                    .updateShop(
                      userId: userId,
                      token: token,
                      shopId: _currentShop!.id,
                      title: newTitle,
                      description: _currentShop!.description,
                    )
                    .timeout(
                      const Duration(seconds: 30),
                      onTimeout: () {
                        throw Exception('Превышено время ожидания');
                      },
                    );

                print('📦 [ShopEdit] updateShop result: $result');

                // ✅ ЗАКРЫВАЕМ ИНДИКАТОР ЗАГРУЗКИ
                Navigator.pop(context); // Закрываем loadingDialog

                if (result['status'] == true) {
                  print('✅ [ShopEdit] Title updated successfully!');
                  _loadShopData();
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
                // ✅ ЗАКРЫВАЕМ ИНДИКАТОР ЗАГРУЗКИ (ЕСЛИ ОН ЕЩЁ ОТКРЫТ)
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

  void _editSocialLinks() {
    print('🔗 [ShopEdit] Edit social links');
    // TODO: Открыть модалку редактирования соцсетей
  }

  void _addPage() {
    print('📄 [ShopEdit] Add new page');
    // TODO: Открыть редактор страниц
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
        // 👇 ДОБАВЛЯЕМ СТАТУС
        status: 0, // 0 - на модерации
      );

      Navigator.pop(context); // Закрываем индикатор

      if (result['status'] == true) {
        print('✅ [ShopEdit] Shop sent to moderation!');

        // ✅ ОБНОВЛЯЕМ _currentShop
        setState(() {
          _currentShop = _currentShop!.copyWith(
            title: newTitle,
            status: 0, // 👈 СТАТУС "НА МОДЕРАЦИИ"
          );
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Изменения сохранены! Магазин отправлен на модерацию',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // ✅ ВОЗВРАЩАЕМСЯ НА СТРАНИЦУ МАГАЗИНА
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
            _currentShop = state.shop;
            _titleController.text = state.shop.title; // 👈 УСТАНАВЛИВАЕМ ТЕКСТ
            final shop = _currentShop!; // 👈 ВАЖНО!
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
                // 4. Соцсети (кликабельные) — БЕЗ кнопок Управление и Добавить товар
                SliverToBoxAdapter(
                  child: ShopActions(
                    shop: shop,
                    isEditing: true,
                    onSocialEdit: _editSocialLinks,
                  ),
                ),
                // 5. Навигация + кнопка "Добавить страницу"
                SliverToBoxAdapter(
                  child: ShopNavigation(
                    shop: shop,
                    isEditing: true,
                    onAddPage: _addPage,
                  ),
                ),
                // 6. Товары
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
}
