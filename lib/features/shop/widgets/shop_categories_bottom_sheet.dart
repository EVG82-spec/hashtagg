import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';

class ShopCategoriesBottomSheet extends StatefulWidget {
  final Shop shop;

  const ShopCategoriesBottomSheet({Key? key, required this.shop})
    : super(key: key);

  @override
  State<ShopCategoriesBottomSheet> createState() =>
      _ShopCategoriesBottomSheetState();
}

class _ShopCategoriesBottomSheetState extends State<ShopCategoriesBottomSheet> {
  List<ShopCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  void _loadCategories() async {
    try {
      print('📂 [ShopCategories] Loading categories...');
      final repository = context.read<ShopApiRepository>();
      final categories = await repository.getShopCategories(
        shopId: widget.shop.id,
      );
      print('✅ [ShopCategories] Loaded ${categories.length} categories');
      for (var cat in categories) {
        print(
          '   - ${cat.name} (ID: ${cat.id}, hasSub: ${cat.hasSubcategory})',
        );
      }
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    } catch (e) {
      print('❌ [ShopCategories] Error: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Категории магазина',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(Icons.close),
              ),
            ],
          ),
          Divider(),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _categories.isEmpty
                ? Center(
                    child: Text(
                      'Нет категорий',
                      style: TextStyle(color: Colors.grey.shade500),
                    ),
                  )
                : ListView.builder(
                    itemCount: _categories.length,
                    itemBuilder: (context, index) {
                      final category = _categories[index];
                      return _buildCategoryItem(category);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(ShopCategory category) {
    // ✅ ЕСЛИ ЕСТЬ ВЛОЖЕННЫЕ КАТЕГОРИИ
    if (category.nested != null && category.nested!.isNotEmpty) {
      return ExpansionTile(
        title: Text(
          category.name,
          style: TextStyle(fontWeight: FontWeight.w500),
        ),
        children: category.nested!.map((sub) {
          return _buildSubcategoryItem(sub);
        }).toList(),
      );
    } else {
      return ListTile(
        title: Text(category.name),
        onTap: () {
          _onCategorySelected(category.id);
        },
      );
    }
  }

  Widget _buildSubcategoryItem(ShopCategory subcategory) {
    return ListTile(
      title: Text(
        subcategory.name,
        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
      ),
      onTap: () {
        _onCategorySelected(subcategory.id);
      },
    );
  }

  void _onCategorySelected(int categoryId) {
    print('📂 [ShopCategories] Selected category: $categoryId');
    // ✅ ВОЗВРАЩАЕМ categoryId В МОДАЛКУ
    Navigator.pop(context, categoryId);
  }
}
