import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_event.dart';
import 'package:hashtagg/features/shop/bloc/shop_state.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:hashtagg/core/utils/shop_access_checker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class ShopEditScreen extends StatefulWidget {
  final int shopId;

  const ShopEditScreen({super.key, required this.shopId});

  @override
  State<ShopEditScreen> createState() => _ShopEditScreenState();
}

class _ShopEditScreenState extends State<ShopEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _shopIdController = TextEditingController();

  int? _selectedCategoryId;
  List<ShopCategory> _categories = [];
  String? _logoUrl;
  File? _newLogoFile;
  String? _newLogoTempName;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadShopData();
  }

  void _loadShopData() {
    final authState = context.read<AuthBloc>().state;
    final user = authState.user;

    if (user != null) {
      context.read<ShopBloc>().add(LoadShopForEdit(
            userId: user.id,
            token: user.token ?? '',
            shopId: widget.shopId,
          ));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _shopIdController.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _newLogoFile = File(pickedFile.path);
      });

      // Загружаем во временную папку
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

  void _saveShop() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final authState = context.read<AuthBloc>().state;
    final user = authState.user;

    if (user == null) return;

    List<Map<String, String>>? logoData;
    if (_newLogoTempName != null) {
      logoData = [
        {'name': _newLogoTempName!}
      ];
    }

    context.read<ShopBloc>().add(UpdateShop(
          userId: user.id,
          token: user.token ?? '',
          shopId: widget.shopId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty
              ? _descriptionController.text.trim()
              : null,
          themeCategoryId: _selectedCategoryId,
          shopIdHash: _shopIdController.text.trim().isNotEmpty
              ? _shopIdController.text.trim()
              : null,
          logo: logoData,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthBloc>().state;
    final user = authState.user;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Редактирование магазина',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: BlocConsumer<ShopBloc, ShopState>(
        listener: (context, state) {
          if (state is ShopError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            setState(() => _isLoading = false);
          } else if (state is ShopUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Магазин успешно обновлен')),
            );
            context.pop(true); // Возвращаемся с флагом обновления
          } else if (state is ShopImageUploaded) {
            setState(() {
              _newLogoTempName = state.imageName;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Изображение загружено')),
            );
          } else if (state is ShopEditDataLoaded) {
            _populateForm(state.data, state.categories);
          }
        },
        builder: (context, state) {
          if (state is ShopLoading && _categories.isEmpty) {
            return Center(child: CircularProgressIndicator(color: Color(0xff917dfa)));
          }

          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Логотип
                  _buildLogoSection(isDark),
                  SizedBox(height: 24),

                  // Название
                  _buildTextField(
                    controller: _titleController,
                    label: 'Название магазина',
                    hint: 'Введите название',
                    required: true,
                    maxLength: 100,
                    isDark: isDark,
                  ),
                  SizedBox(height: 16),

                  // Описание
                  _buildTextField(
                    controller: _descriptionController,
                    label: 'Описание',
                    hint: 'Краткое описание магазина',
                    maxLines: 4,
                    maxLength: 500,
                    isDark: isDark,
                  ),
                  SizedBox(height: 16),

                  // Категория
                  _buildCategoryDropdown(isDark),
                  SizedBox(height: 16),

                  // Уникальный адрес (если есть доступ)
                  if (ShopAccessChecker.hasUniqueShopAddress(user)) ...[
                    _buildTextField(
                      controller: _shopIdController,
                      label: 'Уникальный адрес',
                      hint: 'my-shop',
                      prefix: 'hashtagg.ru/shop/',
                      isDark: isDark,
                      validator: _validateShopId,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Только латинские буквы, цифры, дефис и подчеркивание',
                      style: GoogleFonts.montserrat(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                    SizedBox(height: 24),
                  ],

                  // Кнопка сохранения
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveShop,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xff917dfa),
                        padding: EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Сохранить',
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogoSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Логотип',
          style: GoogleFonts.montserrat(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        SizedBox(height: 12),
        Center(
          child: GestureDetector(
            onTap: _pickLogo,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: isDark ? Colors.grey[850] : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: _newLogoFile != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(
                        _newLogoFile!,
                        fit: BoxFit.cover,
                      ),
                    )
                  : _logoUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: _logoUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: CircularProgressIndicator(
                                color: Color(0xff917dfa),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.store,
                              size: 40,
                              color: Colors.grey,
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_photo_alternate,
                              size: 40,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Добавить фото',
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
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    bool required = false,
    int maxLines = 1,
    int? maxLength,
    String? prefix,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
            children: [
              if (required)
                TextSpan(
                  text: ' *',
                  style: TextStyle(color: Colors.red),
                ),
            ],
          ),
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: hint,
            prefixText: prefix,
            hintStyle: GoogleFonts.montserrat(color: Colors.grey),
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xff917dfa), width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.red),
            ),
            counterStyle: GoogleFonts.montserrat(fontSize: 12),
          ),
          validator: validator ??
              (value) {
                if (required && (value == null || value.trim().isEmpty)) {
                  return 'Это поле обязательно';
                }
                return null;
              },
        ),
      ],
    );
  }

  Widget _buildCategoryDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Тематическая категория',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
            children: [
              TextSpan(
                text: ' *',
                style: TextStyle(color: Colors.red),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        DropdownButtonFormField<int>(
          value: _selectedCategoryId,
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.grey[850] : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Color(0xff917dfa), width: 2),
            ),
          ),
          dropdownColor: isDark ? Colors.grey[850] : Colors.white,
          style: GoogleFonts.montserrat(
            color: isDark ? Colors.white : Colors.black,
          ),
          hint: Text(
            'Выберите категорию',
            style: GoogleFonts.montserrat(color: Colors.grey),
          ),
          items: _categories.map((category) {
            return DropdownMenuItem<int>(
              value: category.id,
              child: Text(category.name),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedCategoryId = value;
            });
          },
          validator: (value) {
            if (value == null) {
              return 'Выберите категорию';
            }
            return null;
          },
        ),
      ],
    );
  }

  String? _validateShopId(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Необязательное поле
    }

    final regex = RegExp(r'^[a-z0-9_-]+$');
    if (!regex.hasMatch(value)) {
      return 'Только латиница, цифры, дефис и подчеркивание';
    }

    return null;
  }

  void _populateForm(Map<String, dynamic> data, List<ShopCategory> categories) {
    setState(() {
      _categories = categories;
      _titleController.text = data['title'] ?? '';
      _descriptionController.text = data['text'] ?? '';
      _shopIdController.text = data['id_hash'] ?? '';
      _selectedCategoryId = data['id_theme_category'];
      _logoUrl = data['logo'];
    });
  }
}
