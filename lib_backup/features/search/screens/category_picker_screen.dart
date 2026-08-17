import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/core/network/categories_api_repository.dart';
import 'package:hashtagg/core/network/api_config.dart';

class CategoryModel {
  final int id;
  final String name;
  final String imageUrl;
  final int parentId;
  final bool hasSubcategories;
  final String breadcrumb;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.parentId,
    required this.hasSubcategories,
    required this.breadcrumb,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      id: _parseInt(json['category_board_id']),
      name: json['category_board_name'] ?? '',
      imageUrl: json['category_board_image'] ?? '',
      parentId: _parseInt(json['category_board_id_parent']),
      hasSubcategories: json['subcategory'] ?? false,
      breadcrumb: json['breadcrumb'] ?? '',
    );
  }
  
  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}

class CategoryPickerScreen extends StatefulWidget {
  final int? selectedCategoryId;
  final String? selectedCategory;
  final String? initialCategory;
  final bool returnId; // Если true, возвращает Map с id и name

  const CategoryPickerScreen({
    super.key,
    this.selectedCategoryId,
    this.selectedCategory,
    this.initialCategory,
    this.returnId = false,
  });

  @override
  State<CategoryPickerScreen> createState() => _CategoryPickerScreenState();
}

class _CategoryPickerScreenState extends State<CategoryPickerScreen> {
  final CategoriesApiRepository _categoriesApi = CategoriesApiRepository();
  
  List<CategoryModel> _categories = [];
  CategoryModel? _selectedTop;
  bool _isLoading = true;
  int _currentParentId = 0;
  String _currentTitle = 'Категории';
  bool _initialLoadDone = false;
  int? _selectedCategoryParentId; // Родительская категория выбранной категории

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories({int parentId = 0}) async {
    setState(() => _isLoading = true);
    
    try {
      final result = await _categoriesApi.getCategories(parentId: parentId);
      
      if (result['status'] == true) {
        final data = result['data'] as List;
        setState(() {
          _categories = data.map((json) => CategoryModel.fromJson(json)).toList();
          _currentParentId = parentId;
          _currentTitle = result['title'] ?? 'Категории';
          _isLoading = false;
        });
        print('✅ [CategoryPicker] Loaded ${_categories.length} categories for parent: $parentId');
        
        // При первой загрузке проверяем, нужно ли открыть подкатегорию
        if (!_initialLoadDone && widget.selectedCategoryId != null && parentId == 0) {
          _initialLoadDone = true;
          await _navigateToSelectedCategory();
        }
      } else {
        throw Exception(result['error'] ?? 'Failed to load categories');
      }
    } catch (e) {
      print('🔴 [CategoryPicker] Error loading categories: $e');
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки категорий: $e')),
        );
      }
    }
  }

  Future<void> _navigateToSelectedCategory() async {
    // Проверяем, есть ли выбранная категория в текущем списке
    final selectedCat = _categories.firstWhere(
      (cat) => cat.id == widget.selectedCategoryId,
      orElse: () => CategoryModel(
        id: 0,
        name: '',
        imageUrl: '',
        parentId: 0,
        hasSubcategories: false,
        breadcrumb: '',
      ),
    );
    
    if (selectedCat.id == 0) {
      // Категория не найдена на верхнем уровне, ищем в подкатегориях
      for (final cat in _categories) {
        if (cat.hasSubcategories) {
          // Загружаем подкатегории и проверяем
          final result = await _categoriesApi.getCategories(parentId: cat.id);
          if (result['status'] == true) {
            final subData = result['data'] as List;
            final subCategories = subData.map((json) => CategoryModel.fromJson(json)).toList();
            
            // Проверяем, есть ли выбранная категория в подкатегориях
            final foundInSub = subCategories.any((subCat) => subCat.id == widget.selectedCategoryId);
            if (foundInSub) {
              // Открываем эту подкатегорию
              print('🔵 [CategoryPicker] Found selected category in subcategory of: ${cat.name}');
              setState(() {
                _selectedTop = cat;
                _categories = subCategories;
                _currentParentId = cat.id;
                _currentTitle = result['title'] ?? cat.name;
                _selectedCategoryParentId = cat.id; // Сохраняем родителя выбранной категории
              });
              return;
            }
          }
        }
      }
    } else {
      // Категория найдена на верхнем уровне
      _selectedCategoryParentId = 0;
    }
  }

  void _selectCategory(CategoryModel cat) {
    if (cat.hasSubcategories) {
      // Загружаем подкатегории
      _loadCategories(parentId: cat.id);
      setState(() => _selectedTop = cat);
    } else {
      // Возвращаем выбранную категорию
      if (widget.returnId) {
        Navigator.pop(context, {'id': cat.id, 'name': cat.name});
      } else {
        Navigator.pop(context, cat.name);
      }
    }
  }

  void _goBack() {
    if (_selectedTop != null) {
      // Возвращаемся к родительской категории
      final parentId = _selectedTop!.parentId;
      _loadCategories(parentId: parentId);
      setState(() => _selectedTop = null);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff151e27) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    
    return PopScope(
      canPop: _selectedTop == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectedTop != null) {
          _goBack();
        }
      },
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          backgroundColor: bgColor,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: _goBack,
          ),
          title: Text(
            _currentTitle,
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xff917dfa)),
              )
            : _buildCategoryGrid(),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xff233040) : const Color(0xFFF5F7FA);
    final selectedCardBgColor = isDark ? const Color(0xff917dfa).withOpacity(0.3) : const Color(0xFFEDE9FF);
    final textColor = isDark ? Colors.white : Colors.black;
    
    if (_categories.isEmpty) {
      return Center(
        child: Text(
          'Категории не найдены',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: _categories.length + (_currentParentId == 0 ? 1 : 0),
      itemBuilder: (context, index) {
        // "Все категории" только на главном уровне
        if (_currentParentId == 0 && index == 0) {
          return GestureDetector(
            onTap: () {
              if (widget.returnId) {
                Navigator.pop(context, {'id': 0, 'name': 'Все категории'});
              } else {
                Navigator.pop(context, null);
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Все\nкатегории',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Icon(Icons.arrow_forward, color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ],
              ),
            ),
          );
        }

        final catIndex = _currentParentId == 0 ? index - 1 : index;
        final cat = _categories[catIndex];
        
        // Подсвечиваем только если:
        // 1. ID совпадает И
        // 2. Мы находимся на том же уровне, где была выбрана категория
        final isSelected = widget.selectedCategoryId == cat.id &&
            (_selectedCategoryParentId == null || _selectedCategoryParentId == _currentParentId);

        return GestureDetector(
          onTap: () => _selectCategory(cat),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? selectedCardBgColor
                  : cardBgColor,
              borderRadius: BorderRadius.circular(12),
              border: isSelected
                  ? Border.all(color: const Color(0xff917dfa), width: 1.5)
                  : null,
            ),
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    cat.name,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: cat.imageUrl.isNotEmpty
                      ? SizedBox(
                          width: 48,
                          height: 48,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Builder(
                              builder: (context) {
                                final imageUrl = ApiConfig.replaceMediaUrl(cat.imageUrl);
                                print('🔵 [CategoryPicker] Loading image: $imageUrl');
                                return Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, error, ___) {
                                    print('🔴 [CategoryPicker] Image load error: $error');
                                    return const Icon(
                                      Icons.category,
                                      color: Color(0xff917dfa),
                                      size: 32,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        )
                      : const Icon(
                          Icons.category,
                          color: Color(0xff917dfa),
                          size: 32,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
