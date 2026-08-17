import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'package:hashtagg/features/listing/screens/listing_screen.dart';
import 'package:hashtagg/features/user_profile/screens/user_profile_screen.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:hashtagg/shared/presentation/utils.dart';
import 'package:hashtagg/features/chats/bloc/chat_bloc.dart';
import 'package:hashtagg/shared/domain/entities/chat.dart';

// ── Модели ───────────────────────────────────────────────────────────────────
class ChatListing {
  final String title;
  final String price;
  final String status;
  final String? imageUrl;
  final String? listingId;

  const ChatListing({
    required this.title,
    required this.price,
    required this.status,
    this.imageUrl,
    this.listingId,
  });
}

// ── Экран чата ────────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  final String userName;
  final String lastSeen;
  final String? avatarUrl;
  final ChatListing listing;
  final String dialogId;
  final int userId;
  final bool isSupport;
  final bool isShop;
  final bool shouldScrollToBottom; // Прокрутить к последнему сообщению при открытии

  const ChatScreen({
    super.key,
    required this.userName,
    required this.lastSeen,
    required this.listing,
    required this.dialogId,
    this.avatarUrl,
    this.userId = 0,
    this.isSupport = false,
    this.isShop = false,
    this.shouldScrollToBottom = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<String> _selectedImageFileNames = []; // Имена загруженных файлов
  final List<String> _selectedImagePaths = []; // Пути для превью
  bool _hasScrolledToBottom = false; // Флаг для однократной прокрутки

  @override
  void initState() {
    super.initState();
    // Загружаем диалог при открытии
    context.read<ChatBloc>().add(LoadDialog(
      dialogId: widget.dialogId,
      isSupport: widget.isSupport,
    ));
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    context.read<ChatBloc>().add(CloseDialog());
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImageFileNames.isEmpty) return;

    print('🔵 [ChatScreen] Sending message with ${_selectedImageFileNames.length} attachments');
    print('🔵 [ChatScreen] Attachments: $_selectedImageFileNames');

    // Сохраняем копию списка вложений перед очисткой
    final attachmentsCopy = _selectedImageFileNames.isNotEmpty 
        ? List<String>.from(_selectedImageFileNames) 
        : null;

    // Отправляем через ChatBloc
    context.read<ChatBloc>().add(SendMessage(
      dialogId: widget.dialogId,
      text: text,
      attachments: attachmentsCopy,
      isSupport: widget.isSupport,
    ));
    
    _messageController.clear();
    setState(() {
      _selectedImageFileNames.clear();
      _selectedImagePaths.clear();
    });

    // Прокручиваем вниз после отправки
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Меню (···) ────────────────────────────────────────────────────────────

  void _showOptionsMenu() {
    final isBlocked = context.read<ChatBloc>().state.currentDialog?.blockedUser ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xff233040) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: bgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ручка
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Пожаловаться
            _menuItem(
              icon: Icons.warning_amber_rounded,
              label: 'Пожаловаться',
              color: textColor,
              onTap: () {
                Navigator.pop(context);
                _showReportModal();
              },
            ),
            // Заблокировать / Разблокировать
            _menuItem(
              icon: isBlocked ? Icons.lock_open_outlined : Icons.lock_outline,
              label: isBlocked ? 'Разблокировать' : 'Заблокировать',
              color: textColor,
              onTap: () {
                Navigator.pop(context);
                if (isBlocked) {
                  _unblockUser();
                } else {
                  _blockUser();
                }
              },
            ),
            // Удалить диалог
            _menuItem(
              icon: Icons.delete_outline,
              label: 'Удалить диалог',
              color: Colors.red,
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color color = Colors.black87,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.montserrat(fontSize: 16, color: color),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportModal() {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 
                  MediaQuery.of(ctx).padding.bottom,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Опишите причину жалобы',
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      maxLines: 5,
                      style: GoogleFonts.montserrat(fontSize: 14),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xffF0F0F0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Опишите причину жалобы',
                                  style: GoogleFonts.montserrat(),
                                ),
                              ),
                            );
                            return;
                          }

                          final userToId = context.read<ChatBloc>().state.currentDialog?.user?.id;
                          if (userToId == null) return;

                          // Отправляем жалобу
                          context.read<ChatBloc>().add(ReportUser(
                            userToId: userToId,
                            text: text,
                          ));

                          Navigator.pop(ctx);

                          // Ждем результат
                          await Future.delayed(const Duration(milliseconds: 500));

                          if (!mounted) return;

                          final error = context.read<ChatBloc>().state.error;
                          if (error != null) {
                            // Показываем ошибку
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  error,
                                  style: GoogleFonts.montserrat(),
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          } else {
                            // Показываем успех
                            _showReportSuccessModal();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xff917dfa),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          'Отправить',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showReportSuccessModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: Color(0xff4CAF50),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: 16),
              Text(
                'Обращение принято',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Мы рассмотрим вашу жалобу в ближайшее время.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: const Color(0xff666666),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff917dfa),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: Text(
                    'Закрыть',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _blockUser() {
    final userToId = context.read<ChatBloc>().state.currentDialog?.user?.id;
    if (userToId == null) return;
    
    context.read<ChatBloc>().add(BlockUser(userToId));
    
    showSwipeDownNotification(
      context,
      message:
          'Пользователь заблокирован. Он не сможет вам писать сообщения и просматривать номер телефона.',
    );
  }

  void _unblockUser() {
    final userToId = context.read<ChatBloc>().state.currentDialog?.user?.id;
    if (userToId == null) return;
    
    context.read<ChatBloc>().add(BlockUser(userToId));
    
    showSwipeDownNotification(
      context,
      message: 'Пользователь разблокирован.',
    );
  }

  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Удалить диалог?',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Диалог будет удален только у вас.',
          style: GoogleFonts.montserrat(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: GoogleFonts.montserrat(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              context.read<ChatBloc>().add(DeleteDialog(widget.dialogId));
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: Text(
              'Удалить',
              style: GoogleFonts.montserrat(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  void _openMediaPicker() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      // Показываем выбор источника
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text('Галерея (несколько)', style: GoogleFonts.montserrat()),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: Text('Камера', style: GoogleFonts.montserrat()),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
            ],
          ),
        ),
      );
      
      if (source == null) return;
      
      List<XFile> images = [];
      
      if (source == ImageSource.gallery) {
        // Множественный выбор из галереи
        images = await picker.pickMultiImage() ?? [];
      } else {
        // Одно фото с камеры
        final image = await picker.pickImage(source: source);
        if (image != null) images = [image];
      }
      
      if (images.isEmpty || !mounted) return;
      
      try {
        final chatBloc = context.read<ChatBloc>();
        
        // Загружаем все изображения
        for (final image in images) {
          final bytes = await image.readAsBytes();
          final base64Image = base64Encode(bytes);
          
          final result = await chatBloc.uploadChatFile(base64Image);
          
          if (result.success && result.data != null) {
            final fileName = result.data!['name'];
            _selectedImageFileNames.add(fileName);
            _selectedImagePaths.add(image.path);
          }
        }
        
        if (mounted) {
          setState(() {}); // Обновляем UI
        }
        
        if (_selectedImageFileNames.length < images.length && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Загружено ${_selectedImageFileNames.length} из ${images.length} изображений'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка выбора изображения: $e')),
        );
      }
    }
  }


  int _previousMessagesCount = 0;
  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final dialog = state.currentDialog;
        final isBlocked = dialog?.blockedUser ?? false;
        final messages = dialog?.messages ?? [];
        final isDark = Theme.of(context).brightness == Brightness.dark;

        if (messages.length > _previousMessagesCount) {
          _previousMessagesCount = messages.length;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }

        // Прокручиваем к последнему сообщению после загрузки диалога
        if (!_hasScrolledToBottom && messages.isNotEmpty) {
          _hasScrolledToBottom = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Небольшая задержка, чтобы ListView гарантированно завершил построение
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted && _scrollController.hasClients) {
                _scrollController.animateTo(
                  _scrollController.position.maxScrollExtent,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut,
                );
              }
            });
          });
        }


        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, result) {
            context.read<ChatBloc>().add(CloseDialog());
          },
          child:  Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0.5,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Theme.of(context).appBarTheme.backgroundColor,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
              onPressed: () {
                context.read<ChatBloc>().add(CloseDialog());
                Navigator.pop(context);
              },
            ),
        title: GestureDetector(
          onTap: () => Navigator.push(
            context,
            createSwipeableRoute(
              builder: (_) => UserProfileScreen(userId: widget.userId),
            ),
          ),
          child: Row(
            children: [
              // Аватар
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xffE0E0E0),
                backgroundImage: widget.avatarUrl != null && !widget.avatarUrl!.contains('no_avatar')
                    ? NetworkImage(widget.avatarUrl!)
                    : null,
                child: widget.avatarUrl == null || widget.avatarUrl!.contains('no_avatar')
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.userName,
                        style: GoogleFonts.montserrat(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      if (widget.isShop) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xff4CAF50),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Магазин',
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  Text(
                    widget.lastSeen,
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      color: const Color(0xff999999),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
            actions: [
              IconButton(
                icon: Icon(
                  Icons.more_horiz, 
                  color: isDark ? Colors.white : Colors.black,
                ),
                onPressed: _showOptionsMenu,
              ),
            ],
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // ── Карточка объявления ────────────────────────────────────────
                    // Не показываем карточку для чата поддержки и для магазинов
                    if (!widget.isSupport && !widget.isShop)
                      if (dialog?.ad != null)
                        _ListingCard(
                          listing: ChatListing(
                            title: dialog!.ad!.title,
                            price: dialog.ad!.price ?? '',
                            status: dialog.ad!.statusName ?? 'Активно',
                            imageUrl: dialog.ad!.image,
                            listingId: dialog.ad!.id.toString(),
                          ),
                        )
                      else
                        _ListingCard(listing: widget.listing),

                    // ── Сообщения ──────────────────────────────────────────────────
                    Expanded(
                      child: messages.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.chat_bubble_outline,
                                    size: 64,
                                    color: Color(0xffE0E0E0),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Напишите первое сообщение',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      color: const Color(0xffAAAAAA),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index];
                                
                                if (msg.isDate) {
                                  return _DateDivider(date: msg.date!);
                                }
                                
                                if (msg.isNotification) {
                                  return _NotificationMessage(
                                    text: msg.text ?? '',
                                    time: msg.date ?? '',
                                    imageUrl: msg.image,
                                  );
                                }
                                
                                if (msg.isOutgoing) {
                                  return _OutgoingMessage(
                                    text: msg.text ?? '',
                                    time: msg.date ?? '',
                                    attachments: msg.attach,
                                  );
                                }
                                
                                return _IncomingMessage(
                                  text: msg.text ?? '',
                                  time: msg.date ?? '',
                                  attachments: msg.attach,
                                );
                              },
                            ),
                    ),

                    // ── Поле ввода / Заблокировано ────────────────────────────────
                    if (isBlocked)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 16,
                          horizontal: 20,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xff233040) : Colors.white,
                          border: Border(
                            top: BorderSide(
                              color: isDark ? const Color(0xff151e27) : const Color(0xffEEEEEE),
                            ),
                          ),
                        ),
                        child: SafeArea(
                          top: false,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Вы внесли пользователя в черный список',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.montserrat(
                                  fontSize: 14,
                                  color: isDark ? Colors.white70 : const Color(0xff666666),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _unblockUser,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xff917dfa),
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                    ),
                                  ),
                                  child: Text(
                                    'Разблокировать',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      _MessageInput(
                        controller: _messageController,
                        onSend: state.isSending ? () {} : _sendMessage,
                        onAttach: _openMediaPicker,
                        isSending: state.isSending,
                        selectedImagePaths: _selectedImagePaths,
                        onRemoveImage: (index) {
                          setState(() {
                            _selectedImageFileNames.removeAt(index);
                            _selectedImagePaths.removeAt(index);
                          });
                        },
                      ),
                  ],
                ),
        )
        );
      },
    );
  }
}

// ── Карточка объявления ───────────────────────────────────────────────────────
class _ListingCard extends StatelessWidget {
  final ChatListing listing;

  const _ListingCard({required this.listing});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: listing.listingId != null
          ? () {
              // Используем GoRouter для навигации
              context.push('/listing/${listing.listingId}');
            }
          : null,
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Color(0xff233040) : const Color(0xFFF0F4FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Фото объявления
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: listing.imageUrl != null
                  ? Image.network(
                      listing.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(),
                    )
                  : _imagePlaceholder(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Статус
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xff4CAF50),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      listing.status,
                      style: GoogleFonts.montserrat(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    listing.title,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    listing.price,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: isDark ? Colors.white : const Color(0xff666666),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xffE0E0E0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.image_outlined, color: Colors.grey),
    );
  }
}

// ── Разделитель даты ──────────────────────────────────────────────────────────
class _DateDivider extends StatelessWidget {
  final String date;

  const _DateDivider({required this.date});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xff233040) : const Color(0xffEEEEEE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            date,
            style: GoogleFonts.montserrat(
              fontSize: 12,
              color: isDark ? Colors.white70 : const Color(0xff666666),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Баннер безопасности ───────────────────────────────────────────────────────
class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text('📣', style: GoogleFonts.montserrat(fontSize: 36)),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              style: GoogleFonts.montserrat(fontSize: 13, color: Colors.black),
              children: [
                const TextSpan(
                  text:
                      'Не переходите по внешним ссылкам и в другие мессенджеры. Гид по безопасности: ',
                ),
                TextSpan(
                  text: 'link.hashtagg.ru/safety',
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: Colors.blue,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Исходящее сообщение ───────────────────────────────────────────────────────
class _OutgoingMessage extends StatelessWidget {
  final String text;
  final String time;
  final List<String>? attachments;

  const _OutgoingMessage({
    required this.text,
    required this.time,
    this.attachments,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff233040) : const Color(0xFFF0F0F0),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (attachments != null && attachments!.isNotEmpty)
              ...attachments!.map((url) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 200,
                          height: 150,
                          color: const Color(0xffE0E0E0),
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  )),
            if (text.isNotEmpty)
              Text(
                text,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              time,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: const Color(0xff999999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Входящее сообщение ────────────────────────────────────────────────────────
class _IncomingMessage extends StatelessWidget {
  final String text;
  final String time;
  final List<String>? attachments;

  const _IncomingMessage({
    required this.text,
    required this.time,
    this.attachments,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8, right: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xff233040) : const Color(0xFFE8E3FF),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (attachments != null && attachments!.isNotEmpty)
              ...attachments!.map((url) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        width: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 200,
                          height: 150,
                          color: const Color(0xffE0E0E0),
                          child: const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  )),
            if (text.isNotEmpty)
              Text(
                text,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            const SizedBox(height: 4),
            Text(
              time,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                color: const Color(0xff999999),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Системное уведомление ─────────────────────────────────────────────────────
class _NotificationMessage extends StatelessWidget {
  final String text;
  final String time;
  final String? imageUrl;

  const _NotificationMessage({
    required this.text,
    required this.time,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Color(0xff233040) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          if (imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Image.network(
                imageUrl!,
                width: 32,
                height: 32,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.notifications_outlined,
                  size: 32,
                  color: Color(0xff917dfa),
                ),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(
                Icons.notifications_outlined,
                size: 32,
                color: Color(0xff917dfa),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: GoogleFonts.montserrat(
                    fontSize: 13,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    color: const Color(0xff999999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Поле ввода ────────────────────────────────────────────────────────────────
class _MessageInput extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final bool isSending;
  final List<String> selectedImagePaths;
  final Function(int)? onRemoveImage;

  const _MessageInput({
    required this.controller,
    required this.onSend,
    required this.onAttach,
    this.isSending = false,
    this.selectedImagePaths = const [],
    this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff233040) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xff151e27) : const Color(0xffEEEEEE),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Превью изображений
            if (selectedImagePaths.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                height: 100,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: selectedImagePaths.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(selectedImagePaths[index]),
                              height: 100,
                              width: 100,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => onRemoveImage?.call(index),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
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
                  },
                ),
              ),
            // Поле ввода
            Row(
              children: [
                // Кнопка прикрепить
                GestureDetector(
                  onTap: onAttach,
                  child: Icon(
                    Icons.attach_file,
                    color: isDark ? Colors.white : const Color(0xff999999),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 8),
                // Поле ввода
                Expanded(
                  child: TextField(
                    controller: controller,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Сообщение',
                      filled: true,                              
                      fillColor: isDark ? Color(0xff233040) : Colors.white,
                      hintStyle: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: const Color(0xffBBBBBB),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => onSend(),
                  ),
                ),
                const SizedBox(width: 8),
                // Кнопка отправить
                GestureDetector(
                  onTap: isSending ? null : onSend,
                  child: isSending
                      ? const SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xff917dfa),
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Color(0xff917dfa),
                          size: 26,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Медиапикер для чата ───────────────────────────────────────────────────────
class _ChatMediaPickerScreen extends StatefulWidget {
  const _ChatMediaPickerScreen();

  @override
  State<_ChatMediaPickerScreen> createState() => _ChatMediaPickerScreenState();
}

class _ChatMediaPickerScreenState extends State<_ChatMediaPickerScreen> {
  int? _selectedIndex;

  final List<String> _stubImages = [
    'https://picsum.photos/seed/a1/300/300',
    'https://picsum.photos/seed/b2/300/300',
    'https://picsum.photos/seed/c3/300/300',
    'https://picsum.photos/seed/d4/300/300',
    'https://picsum.photos/seed/e5/300/300',
    'https://picsum.photos/seed/f6/300/300',
    'https://picsum.photos/seed/g7/300/300',
    'https://picsum.photos/seed/h8/300/300',
    'https://picsum.photos/seed/i9/300/300',
    'https://picsum.photos/seed/j10/300/300',
    'https://picsum.photos/seed/k11/300/300',
    'https://picsum.photos/seed/l12/300/300',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.white,
          statusBarIconBrightness: Brightness.dark,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Выбрать фото',
          style: GoogleFonts.montserrat(color: Colors.black),
        ),
        actions: [
          if (_selectedIndex != null)
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _stubImages[_selectedIndex!]),
              child: Text(
                'Готово',
                style: GoogleFonts.montserrat(
                  color: Color(0xff917dfa),
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xff917dfa).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 16, color: Color(0xff917dfa)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Это заглушка. В реальной версии здесь будут ваши медиафайлы с устройства.',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      color: Color(0xff917dfa),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
              ),
              itemCount: _stubImages.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedIndex == index;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedIndex = isSelected ? null : index;
                  }),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.network(
                        _stubImages[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: const Color(0xfff0f0f0),
                            child: const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xff917dfa),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => Container(
                          color: const Color(0xfff0f0f0),
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Color(0xffaaaaaa),
                          ),
                        ),
                      ),
                      if (isSelected)
                        Container(
                          color: const Color(0xff917dfa).withValues(alpha: 0.4),
                          child: const Center(
                            child: Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 36,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
