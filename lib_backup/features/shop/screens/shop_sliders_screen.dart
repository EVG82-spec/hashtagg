import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_event.dart';
import 'package:hashtagg/features/shop/bloc/shop_state.dart';
import 'package:hashtagg/core/models/shop.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class ShopSlidersScreen extends StatefulWidget {
  final int shopId;
  final String shopTitle;
  final String? shopDescription;
  final int themeCategoryId;
  final List<ShopSlider> initialSliders;

  const ShopSlidersScreen({
    super.key,
    required this.shopId,
    required this.shopTitle,
    this.shopDescription,
    required this.themeCategoryId,
    required this.initialSliders,
  });

  @override
  State<ShopSlidersScreen> createState() => _ShopSlidersScreenState();
}

class _ShopSlidersScreenState extends State<ShopSlidersScreen> {
  static const int maxSliders = 4;
  List<ShopSlider> _sliders = [];
  List<Map<String, String>> _newSliders = [];
  List<String> _slidersToDelete = [];
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _sliders = List.from(widget.initialSliders);
  }

  Future<void> _pickImage() async {
    if (_sliders.length + _newSliders.length >= maxSliders) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Максимум $maxSliders слайдера')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 600,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final authState = context.read<AuthBloc>().state;
      final user = authState.user;

      if (user != null) {
        context.read<ShopBloc>().add(UploadShopImage(
              filePath: pickedFile.path,
              userId: user.id,
              token: user.token ?? '',
            ));
      }
    }
  }

  void _deleteSlider(int index, {bool isNew = false}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить слайдер?'),
        content: Text('Это действие нельзя отменить'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                if (isNew) {
                  _newSliders.removeAt(index);
                } else {
                  final slider = _sliders[index];
                  _slidersToDelete.add(slider.name);
                  _sliders.removeAt(index);
                }
                _hasChanges = true;
              });
            },
            child: Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _saveSliders() {
    final authState = context.read<AuthBloc>().state;
    final user = authState.user;

    if (user == null) return;

    // Собираем все слайдеры (старые + новые)
    final allSliders = <Map<String, String>>[];
    
    // Добавляем существующие слайдеры (которые не удалены)
    for (var slider in _sliders) {
      allSliders.add({'name': slider.link.split('/').last});
    }
    
    // Добавляем новые слайдеры
    allSliders.addAll(_newSliders);

    context.read<ShopBloc>().add(UpdateShop(
          userId: user.id,
          token: user.token ?? '',
          shopId: widget.shopId,
          title: widget.shopTitle, // Используем переданное название
          description: widget.shopDescription,
          themeCategoryId: widget.themeCategoryId,
          sliders: allSliders.isNotEmpty ? allSliders : null,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final totalSliders = _sliders.length + _newSliders.length;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(_hasChanges),
        ),
        title: Text(
          'Слайдеры ($totalSliders/$maxSliders)',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        actions: [
          if (totalSliders < maxSliders)
            IconButton(
              icon: Icon(Icons.add, color: isDark ? Colors.white : Colors.black),
              onPressed: _pickImage,
            ),
        ],
      ),
      body: BlocConsumer<ShopBloc, ShopState>(
        listener: (context, state) {
          if (state is ShopError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is ShopImageUploaded) {
            setState(() {
              _newSliders.add({
                'name': state.imageName,
                'url': state.imageUrl,
              });
              _hasChanges = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Слайдер добавлен')),
            );
          } else if (state is ShopUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Слайдеры сохранены')),
            );
            context.pop(true);
          }
        },
        builder: (context, state) {
          final isLoading = state is ShopLoading;

          return Column(
            children: [
              Expanded(
                child: totalSliders == 0
                    ? _buildEmptyState(isDark)
                    : _buildSliderGrid(isDark),
              ),
              if (_hasChanges)
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[900] : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _saveSliders,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff917dfa),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Сохранить изменения',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            'Нет слайдеров',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Добавьте изображения для слайдера',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _pickImage,
            icon: Icon(Icons.add_photo_alternate, color: Colors.white),
            label: Text(
              'Добавить слайдер',
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xff917dfa),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderGrid(bool isDark) {
    return GridView.builder(
      padding: EdgeInsets.all(16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: _sliders.length + _newSliders.length,
      itemBuilder: (context, index) {
        if (index < _sliders.length) {
          // Существующий слайдер
          final slider = _sliders[index];
          return _buildSliderCard(
            imageUrl: slider.link,
            onDelete: () => _deleteSlider(index),
            isDark: isDark,
          );
        } else {
          // Новый слайдер
          final newIndex = index - _sliders.length;
          final newSlider = _newSliders[newIndex];
          return _buildSliderCard(
            imageUrl: newSlider['url'],
            imageName: newSlider['name'],
            onDelete: () => _deleteSlider(newIndex, isNew: true),
            isDark: isDark,
            isNew: true,
          );
        }
      },
    );
  }

  Widget _buildSliderCard({
    String? imageUrl,
    String? imageName,
    required VoidCallback onDelete,
    required bool isDark,
    bool isNew = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: imageUrl != null
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[300],
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xff917dfa),
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.error, color: Colors.red),
                    ),
                  )
                : Container(
                    color: Colors.grey[300],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.image, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          if (isNew)
                            Text(
                              'Загружено',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
          ),
          // Метка "новое" для новозагруженных изображений
          if (isNew)
            Positioned(
              bottom: 8,
              right: 8,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(0xff917dfa),
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  'новое',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          // Кнопка удаления
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                padding: EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
