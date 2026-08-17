import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_event.dart';
import 'package:hashtagg/features/shop/bloc/shop_state.dart';
import 'package:hashtagg/features/shop/models/shop.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:io';

class ShopSettingsScreen extends StatefulWidget {
  final int shopId;
  final List<ShopLink> initialLinks;

  const ShopSettingsScreen({
    super.key,
    required this.shopId,
    required this.initialLinks,
  });

  @override
  State<ShopSettingsScreen> createState() => _ShopSettingsScreenState();
}

class _ShopSettingsScreenState extends State<ShopSettingsScreen> {
  static const int maxLinks = 3;
  final List<_LinkData> _links = [];
  bool _hasChanges = false;
  bool _isLoading = false;
  int? _uploadingLinkIndex;
  Shop? _currentShop; // Сохраняем данные магазина

  @override
  void initState() {
    super.initState();
    _initializeLinks();
    _loadShopData();
  }

  void _loadShopData() {
    final authState = context.read<AuthBloc>().state;
    final user = authState.user;

    if (user != null) {
      context.read<ShopBloc>().add(LoadShop(
            userId: user.id,
            token: user.token ?? '',
            shopId: widget.shopId,
          ));
    }
  }

  void _initializeLinks() {
    // Инициализируем 3 слота для ссылок
    for (int i = 0; i < maxLinks; i++) {
      if (i < widget.initialLinks.length) {
        final link = widget.initialLinks[i];
        _links.add(_LinkData(
          textController: TextEditingController(text: link.text ?? ''),
          urlController: TextEditingController(text: link.link ?? ''),
          imageUrl: link.image,
        ));
      } else {
        _links.add(_LinkData(
          textController: TextEditingController(),
          urlController: TextEditingController(),
        ));
      }
    }
  }

  @override
  void dispose() {
    for (var link in _links) {
      link.textController.dispose();
      link.urlController.dispose();
    }
    super.dispose();
  }

  Future<void> _pickImage(int index) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      final authState = context.read<AuthBloc>().state;
      final user = authState.user;

      if (user != null) {
        // Сохраняем индекс для которого загружаем изображение
        setState(() {
          _uploadingLinkIndex = index;
          _links[index].isUploading = true;
        });

        context.read<ShopBloc>().add(UploadShopImage(
              filePath: pickedFile.path,
              userId: user.id,
              token: user.token ?? '',
            ));
      }
    }
  }

  void _clearLink(int index) {
    setState(() {
      _links[index].textController.clear();
      _links[index].urlController.clear();
      _links[index].imageUrl = null;
      _links[index].newImageFile = null;
      _links[index].newImageName = null;
      _links[index].newImageUrl = null;
      _hasChanges = true;
    });
  }

  void _saveLinks() {
    // Валидация
    for (int i = 0; i < _links.length; i++) {
      final link = _links[i];
      final hasText = link.textController.text.trim().isNotEmpty;
      final hasUrl = link.urlController.text.trim().isNotEmpty;
      final hasImage = link.imageUrl != null || link.newImageName != null || link.newImageUrl != null;

      if ((hasText || hasUrl || hasImage) && (!hasText || !hasUrl)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ссылка ${i + 1}: заполните текст и URL')),
        );
        return;
      }
    }

    // Собираем ссылки для отправки
    final linksToSave = <ShopLink>[];
    for (var link in _links) {
      final text = link.textController.text.trim();
      final url = link.urlController.text.trim();
      
      if (text.isNotEmpty && url.isNotEmpty) {
        // Определяем какое изображение использовать
        String? imageToSave;
        if (link.newImageName != null && link.newImageName!.isNotEmpty) {
          // Используем имя нового загруженного файла
          imageToSave = link.newImageName;
        } else if (link.imageUrl != null && link.imageUrl!.isNotEmpty) {
          // Используем существующее изображение (извлекаем имя файла из URL)
          if (link.imageUrl!.startsWith('http')) {
            imageToSave = link.imageUrl!.split('/').last;
          } else {
            imageToSave = link.imageUrl;
          }
        }
        
        linksToSave.add(ShopLink(
          text: text,
          link: url,
          image: imageToSave,
        ));
      }
    }

    final authState = context.read<AuthBloc>().state;
    final user = authState.user;

    if (user != null) {
      // Проверяем, что данные магазина загружены
      if (_currentShop == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: данные магазина не загружены')),
        );
        return;
      }
      
      context.read<ShopBloc>().add(UpdateShop(
        userId: user.id,
        token: user.token ?? '',
        shopId: widget.shopId,
        title: _currentShop!.title,
        description: _currentShop!.description,
        themeCategoryId: _currentShop!.themeCategoryId,
        links: linksToSave,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          'Ссылки магазина',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: BlocConsumer<ShopBloc, ShopState>(
        listener: (context, state) {
          if (state is ShopImageUploaded) {
            // Обновляем ссылку с загруженным изображением
            if (_uploadingLinkIndex != null) {
              setState(() {
                _links[_uploadingLinkIndex!].newImageName = state.imageName;
                _links[_uploadingLinkIndex!].newImageUrl = state.imageUrl;
                _links[_uploadingLinkIndex!].isUploading = false;
                _uploadingLinkIndex = null;
                _hasChanges = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Изображение загружено')),
              );
            }
          } else if (state is ShopError) {
            if (_uploadingLinkIndex != null) {
              setState(() {
                _links[_uploadingLinkIndex!].isUploading = false;
                _uploadingLinkIndex = null;
              });
            }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is ShopUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Ссылки сохранены')),
            );
            context.pop(true);
          } else if (state is ShopLoaded) {
            // Сохраняем данные магазина
            _currentShop = state.shop;
            
            // Обновляем ссылки из загруженных данных
            if (kDebugMode) {
              print('[ShopSettings] Shop loaded, links: ${state.shop.links?.length ?? 0}');
              if (state.shop.links != null) {
                for (var i = 0; i < state.shop.links!.length; i++) {
                  final link = state.shop.links![i];
                  print('[ShopSettings] Link $i: text=${link.text}, link=${link.link}, image=${link.image}');
                }
              }
            }
            
            if (state.shop.links != null && state.shop.links!.isNotEmpty) {
              setState(() {
                for (int i = 0; i < state.shop.links!.length && i < maxLinks; i++) {
                  final link = state.shop.links![i];
                  _links[i].textController.text = link.text ?? '';
                  _links[i].urlController.text = link.link ?? '';
                  _links[i].imageUrl = link.image;
                }
              });
            }
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Добавьте до 3 ссылок на ваши ресурсы',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      SizedBox(height: 24),
                      for (int i = 0; i < maxLinks; i++) ...[
                        _buildLinkCard(i, isDark),
                        if (i < maxLinks - 1) SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
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
                      onPressed: _isLoading ? null : _saveLinks,
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
                              'Сохранить все',
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

  Widget _buildLinkCard(int index, bool isDark) {
    final link = _links[index];
    final hasContent = link.textController.text.isNotEmpty ||
        link.urlController.text.isNotEmpty ||
        link.imageUrl != null ||
        link.newImageName != null ||
        link.newImageUrl != null;

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ссылка ${index + 1}',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              if (hasContent)
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => _clearLink(index),
                  padding: EdgeInsets.zero,
                  constraints: BoxConstraints(),
                ),
            ],
          ),
          SizedBox(height: 16),

          // Иконка/изображение
          Center(
            child: GestureDetector(
              onTap: () => _pickImage(index),
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  ),
                ),
                child: link.isUploading
                    ? Center(
                        child: CircularProgressIndicator(
                          color: Color(0xff917dfa),
                        ),
                      )
                    : (link.newImageUrl != null || link.newImageName != null)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: link.newImageUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: link.newImageUrl!,
                                    width: 80,
                                    height: 80,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xff917dfa),
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Icon(
                                      Icons.error,
                                      color: Colors.red,
                                    ),
                                  )
                                : Icon(Icons.image, size: 40, color: Colors.grey),
                          )
                        : link.imageUrl != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: CachedNetworkImage(
                                  imageUrl: link.imageUrl!,
                                  width: 80,
                                  height: 80,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xff917dfa),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Icon(
                                    Icons.error,
                                    color: Colors.red,
                                  ),
                                ),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate,
                                      size: 32, color: Colors.grey),
                                  SizedBox(height: 4),
                                  Text(
                                    'Иконка',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
              ),
            ),
          ),
          SizedBox(height: 16),

          // Текст ссылки
          TextField(
            controller: link.textController,
            style: GoogleFonts.montserrat(
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              labelText: 'Текст',
              hintText: 'Например: Наш сайт',
              hintStyle: GoogleFonts.montserrat(color: Colors.grey),
              filled: true,
              fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            onChanged: (value) {
              setState(() => _hasChanges = true);
            },
          ),
          SizedBox(height: 12),

          // URL
          TextField(
            controller: link.urlController,
            style: GoogleFonts.montserrat(
              color: isDark ? Colors.white : Colors.black,
            ),
            decoration: InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com',
              hintStyle: GoogleFonts.montserrat(color: Colors.grey),
              filled: true,
              fillColor: isDark ? Colors.grey[800] : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            keyboardType: TextInputType.url,
            onChanged: (value) {
              setState(() => _hasChanges = true);
            },
          ),
        ],
      ),
    );
  }
}

class _LinkData {
  final TextEditingController textController;
  final TextEditingController urlController;
  String? imageUrl;
  File? newImageFile;
  String? newImageName;
  String? newImageUrl;
  bool isUploading = false;

  _LinkData({
    required this.textController,
    required this.urlController,
    this.imageUrl,
  });
}
