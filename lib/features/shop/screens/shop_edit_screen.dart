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
  Shop? _currentShop;

  @override
  void initState() {
    super.initState();
    _initBloc();
    _loadShopData();
  }

  void _initBloc() {
    final dio = Dio(BaseOptions(
      baseUrl: 'https://hashtagg.ru',
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    ));
    final repository = ShopApiRepository(dio);
    _shopPublicBloc = ShopPublicBloc(repository);
  }

  void _loadShopData() {
    _shopPublicBloc.add(LoadPublicShop(shopId: widget.shopId));
  }

  // ===== МЕТОДЫ РЕДАКТИРОВАНИЯ =====

  void _pickBannerImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      print('📸 [ShopEdit] Banner image selected: ${image.path}');
      // TODO: Загрузить баннер через API
    }
  }

  void _pickAvatarImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      print('📸 [ShopEdit] Avatar image selected: ${image.path}');
      // TODO: Загрузить аватарку через API
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
            onPressed: () {
              final newTitle = controller.text.trim();
              if (newTitle.isNotEmpty) {
                Navigator.pop(context);
                print('📝 [ShopEdit] Title: $newTitle');
                // TODO: Сохранить название через API
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

  void _saveShop() {
    print('💾 [ShopEdit] Save changes');
    // TODO: Сохранить все изменения и отправить на модерацию
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Изменения сохранены! Отправлено на модерацию'),
        backgroundColor: Colors.green,
      ),
    );
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
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8956FF)),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Загрузка магазина...',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is ShopPublicLoaded) {
            _currentShop = state.shop;
            final shop = state.shop;
            final ads = state.ads;

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
                  ),
                ),
                // 3. Статистика
                SliverToBoxAdapter(
                  child: ShopStats(shop: shop),
                ),
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
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
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