import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_event.dart';
import 'package:hashtagg/features/shop/bloc/shop_state.dart';
import 'package:hashtagg/core/models/shop.dart';

class ShopPageEditScreen extends StatefulWidget {
  final int shopId;
  final ShopPage? page; // null = создание, не null = редактирование

  const ShopPageEditScreen({
    super.key,
    required this.shopId,
    this.page,
  });

  @override
  State<ShopPageEditScreen> createState() => _ShopPageEditScreenState();
}

class _ShopPageEditScreenState extends State<ShopPageEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _aliasController = TextEditingController();
  late quill.QuillController _quillController;
  final FocusNode _editorFocusNode = FocusNode();
  bool _isActive = true;
  bool _isLoading = false;

  bool get isEditing => widget.page != null;

  @override
  void initState() {
    super.initState();
    
    // Инициализируем Quill контроллер
    if (isEditing && widget.page!.text.isNotEmpty) {
      // Логируем HTML который пришёл от сервера
      print('📄 [ShopPageEdit] HTML from server:');
      print(widget.page!.text);
      print('---');
      
      // Если редактируем, загружаем существующий HTML и конвертируем в Delta
      try {
        final delta = HtmlToDelta().convert(widget.page!.text);
        print('✅ [ShopPageEdit] Successfully converted HTML to Delta');
        _quillController = quill.QuillController(
          document: quill.Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        // Если конвертация не удалась, загружаем как plain text
        print('⚠️ [ShopPageEdit] Failed to convert HTML to Delta: $e');
        _quillController = quill.QuillController(
          document: quill.Document()..insert(0, widget.page!.text.replaceAll(RegExp(r'<[^>]*>'), '')),
          selection: const TextSelection.collapsed(offset: 0),
        );
      }
    } else {
      // Если создаем новую страницу
      print('📝 [ShopPageEdit] Creating new page');
      _quillController = quill.QuillController.basic();
    }
    
    if (isEditing) {
      _nameController.text = widget.page!.name;
      _aliasController.text = widget.page!.alias ?? '';
      _isActive = widget.page!.status == 1;
    }

    // Автогенерация алиаса при вводе названия
    _nameController.addListener(_generateAlias);
  }

  @override
  void dispose() {
    _nameController.removeListener(_generateAlias);
    _nameController.dispose();
    _aliasController.dispose();
    _quillController.dispose();
    _editorFocusNode.dispose();
    super.dispose();
  }

  void _generateAlias() {
    if (!isEditing && _aliasController.text.isEmpty) {
      final name = _nameController.text;
      final alias = _transliterate(name);
      _aliasController.text = alias;
    }
  }

  String _transliterate(String text) {
    const Map<String, String> translitMap = {
      'а': 'a', 'б': 'b', 'в': 'v', 'г': 'g', 'д': 'd', 'е': 'e', 'ё': 'yo',
      'ж': 'zh', 'з': 'z', 'и': 'i', 'й': 'y', 'к': 'k', 'л': 'l', 'м': 'm',
      'н': 'n', 'о': 'o', 'п': 'p', 'р': 'r', 'с': 's', 'т': 't', 'у': 'u',
      'ф': 'f', 'х': 'h', 'ц': 'ts', 'ч': 'ch', 'ш': 'sh', 'щ': 'sch',
      'ъ': '', 'ы': 'y', 'ь': '', 'э': 'e', 'ю': 'yu', 'я': 'ya',
      ' ': '-', '_': '-',
    };

    String result = text.toLowerCase();
    translitMap.forEach((key, value) {
      result = result.replaceAll(key, value);
    });

    // Удаляем все символы кроме букв, цифр и дефиса
    result = result.replaceAll(RegExp(r'[^a-z0-9-]'), '');
    // Заменяем множественные дефисы на один
    result = result.replaceAll(RegExp(r'-+'), '-');
    // Убираем дефисы в начале и конце
    result = result.replaceAll(RegExp(r'^-|-$'), '');

    return result;
  }

  void _savePage() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Получаем текст из Quill редактора
    final plainText = _quillController.document.toPlainText();
    
    if (plainText.trim().length < 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Минимум 50 символов в тексте')),
      );
      return;
    }

    // Конвертируем Delta в HTML
    final delta = _quillController.document.toDelta();
    final converter = QuillDeltaToHtmlConverter(
      delta.toJson(),
      ConverterOptions.forEmail(),
    );
    final htmlText = converter.convert();
    
    // Логируем HTML который отправляем на сервер
    print('📤 [ShopPageEdit] HTML to send to server:');
    print(htmlText);
    print('---');
    print('📊 [ShopPageEdit] Plain text length: ${plainText.trim().length}');

    final authState = context.read<AuthBloc>().state;
    final user = authState.user;

    if (user == null) return;

    setState(() => _isLoading = true);

    if (isEditing) {
      // Редактирование
      print('✏️ [ShopPageEdit] Updating page ID: ${widget.page!.id}');
      context.read<ShopBloc>().add(UpdateShopPage(
            userId: user.id,
            token: user.token ?? '',
            pageId: widget.page!.id,
            name: _nameController.text.trim(),
            text: htmlText,
            alias: _aliasController.text.trim(),
          ));
    } else {
      // Создание
      print('➕ [ShopPageEdit] Creating new page for shop ID: ${widget.shopId}');
      context.read<ShopBloc>().add(AddShopPage(
            userId: user.id,
            token: user.token ?? '',
            shopId: widget.shopId,
            name: _nameController.text.trim(),
            text: htmlText,
            alias: _aliasController.text.trim(),
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
          isEditing ? 'Редактирование страницы' : 'Новая страница',
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
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is ShopPageAdded || state is ShopPageUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  isEditing ? 'Страница обновлена' : 'Страница создана',
                ),
              ),
            );
            context.pop(true);
          }
        },
        builder: (context, state) {
          return SingleChildScrollView(
            padding: EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Название
                  _buildTextField(
                    controller: _nameController,
                    label: 'Название страницы',
                    hint: 'Например: О магазине',
                    required: true,
                    maxLength: 100,
                    isDark: isDark,
                  ),
                  SizedBox(height: 16),

                  // Алиас
                  _buildTextField(
                    controller: _aliasController,
                    label: 'Алиас (URL)',
                    hint: 'o-magazine',
                    required: true,
                    isDark: isDark,
                    validator: _validateAlias,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Используется в URL: hashtagg.ru/shop/[магазин]/[алиас]',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 16),

                  // Текст страницы с Quill редактором
                  _buildQuillEditor(isDark),
                  SizedBox(height: 8),
                  Text(
                    'Минимум 50 символов',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 24),

                  // Статус (активна/неактивна)
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[850] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Статус страницы',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _isActive
                                  ? 'Страница видна посетителям'
                                  : 'Страница скрыта',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        Switch(
                          value: _isActive,
                          onChanged: (value) {
                            setState(() => _isActive = value);
                          },
                          activeColor: Color(0xff917dfa),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24),

                  // Кнопка сохранения
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _savePage,
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
                              isEditing ? 'Сохранить изменения' : 'Создать страницу',
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    bool required = false,
    int maxLines = 1,
    int? maxLength,
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

  String? _validateAlias(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Алиас обязателен';
    }

    final regex = RegExp(r'^[a-z0-9-]+$');
    if (!regex.hasMatch(value)) {
      return 'Только латиница, цифры и дефис';
    }

    if (value.length < 3) {
      return 'Минимум 3 символа';
    }

    return null;
  }
  
  Widget _buildQuillEditor(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: 'Содержимое страницы',
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
        
        // Toolbar
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.grey[100],
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
            ),
          ),
          child: quill.QuillSimpleToolbar(
            controller: _quillController,
            config: quill.QuillSimpleToolbarConfig(
              multiRowsDisplay: false,
              showAlignmentButtons: true,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showStrikeThrough: false,
              showListBullets: true,
              showListNumbers: true,
              showListCheck: false,
              showCodeBlock: false,
              showQuote: false,
              showIndent: false,
              showLink: true,
              showUndo: true,
              showRedo: true,
              showDirection: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              showInlineCode: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: true,
              showHeaderStyle: true,
              showFontFamily: false,
              showFontSize: false,
            ),
          ),
        ),
        
        // Editor
        Container(
          height: 300,
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[850] : Colors.white,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
            border: Border(
              left: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
              right: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
              bottom: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
          ),
          child: quill.QuillEditor.basic(
            controller: _quillController,
            config: quill.QuillEditorConfig(
              padding: EdgeInsets.all(16),
              placeholder: 'Введите текст страницы...',
              customStyles: quill.DefaultStyles(
                paragraph: quill.DefaultTextBlockStyle(
                  GoogleFonts.montserrat(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  quill.HorizontalSpacing.zero,
                  const quill.VerticalSpacing(0, 0),
                  const quill.VerticalSpacing(0, 0),
                  null,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
