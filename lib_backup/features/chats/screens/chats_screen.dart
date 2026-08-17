import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hashtagg/features/chats/bloc/chat_bloc.dart';
import 'package:hashtagg/shared/domain/entities/chat.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/core/navigation/swipeable_route.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'chat_screen.dart';

// ── Тестовые данные диалогов ─────────────────────────────────────────────────
// Удалены - теперь используем реальные данные с сервера

// ── Экран диалогов ───────────────────────────────────────────────────────────
class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  @override
  void initState() {
    super.initState();
    // Загружаем диалоги при открытии экрана
    context.read<ChatBloc>().add(LoadDialogs());
  }

  void _showMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xffE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Черный список
              ListTile(
                leading: Icon(
                  Icons.lock_outline,
                  color: isDark ? Colors.white : Colors.black,
                ),
                title: Text(
                  'Черный список',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/blacklist');
                },
              ),
              // Очистить чат
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: isDark ? Colors.white : Colors.black,
                ),
                title: Text(
                  'Очистить чаты',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _clearChats();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _clearChats() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Подтверждение',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Вы действительно хотите удалить все диалоги?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Отмена',
              style: GoogleFonts.montserrat(color: Colors.grey),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<ChatBloc>().add(ClearAllDialogs());
            },
            child: Text(
              'Очистить',
              style: GoogleFonts.montserrat(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final dialogs = state.dialogs;
        final support = state.support;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            systemOverlayStyle: SystemUiOverlayStyle(
              statusBarColor: Theme.of(context).appBarTheme.backgroundColor,
              statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Диалоги',
              style: GoogleFonts.montserrat(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.more_horiz, color: isDark ? Colors.white : Colors.black, size: 28),
                onPressed: _showMenu,
              ),
            ],
          ),
          body: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : dialogs.isEmpty && support == null
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
                            'Нет диалогов',
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              color: const Color(0xffAAAAAA),
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        context.read<ChatBloc>().add(LoadDialogs());
                      },
                      color: Color(0xff917dfa),
                      edgeOffset: 40.0,
                      displacement: 20.0,
                      strokeWidth: 3.0,
                      child: ListView(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        children: [
                          // ── Поддержка ──────────────────────────────────────────────────
                          if (support != null) _SupportCard(support: support),
                          if (support != null) const SizedBox(height: 16),

                          // ── Список диалогов ────────────────────────────────────────────
                          ...dialogs.map((dialog) => _DialogItem(dialog: dialog)),
                        ],
                      ),
                    ),
        );
      },
    );
  }
}

// ── Карточка поддержки ───────────────────────────────────────────────────────
class _SupportCard extends StatelessWidget {
  final ChatSupport support;

  const _SupportCard({required this.support});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        // Получаем userId из AuthBloc
        final authBloc = context.read<AuthBloc>();
        final userId = authBloc.state.user?.id;
        
        if (userId == null) return;
        
        // Создаем hash для чата поддержки
        final supportHash = md5.convert(utf8.encode('support$userId')).toString();
        
        final chatBloc = context.read<ChatBloc>();
        final navigator = Navigator.of(context, rootNavigator: true);
        
        // Загружаем диалог поддержки
        chatBloc.add(LoadDialog(
          dialogId: supportHash,
          isSupport: true,
        ));
        
        print('🔵 [SupportCard] Waiting for support dialog to load...');
        
        try {
          // Ждем пока диалог загрузится
          await chatBloc.stream.firstWhere(
            (state) {
              print('🔵 [SupportCard] State changed - isLoading: ${state.isLoading}, hasDialog: ${state.currentDialog != null}');
              return !state.isLoading;
            },
          ).timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              print('🔴 [SupportCard] Timeout waiting for dialog');
              return chatBloc.state;
            },
          );
          
          final state = chatBloc.state;
          
          if (state.currentDialog != null) {
            print('✅ [SupportCard] Support dialog loaded, opening chat screen...');
            
            await navigator.push(
              createSwipeableRoute(
                builder: (_) => ChatScreen(
                  userName: 'Поддержка',
                  lastSeen: 'Будем рады помочь',
                  avatarUrl: '${ApiConfig.mediaUrl}/templates/images/supportChat.png',
                  dialogId: supportHash,
                  listing: const ChatListing(
                    title: '',
                    price: '',
                    status: '',
                  ),
                  userId: 0,
                  isSupport: true,
                ),
              ),
            );
            
            print('✅ [SupportCard] Returned from support chat');
            
            // Обновляем список диалогов после возврата
            chatBloc.add(LoadDialogs());
          } else {
            print('🔴 [SupportCard] Failed to load support dialog');
          }
        } catch (e) {
          print('🔴 [SupportCard] Exception: $e');
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xff233040) 
              : const Color(0xFFEAF4FF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: Color(0xff917dfa),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.headset_mic, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    support.title1,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white 
                          : Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    support.title2,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      color: Theme.of(context).brightness == Brightness.dark 
                          ? Colors.white70 
                          : const Color(0xff666666),
                    ),
                  ),
                ],
              ),
            ),
            if (support.countMessages > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xff917dfa),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${support.countMessages}',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Элемент диалога ──────────────────────────────────────────────────────────
class _DialogItem extends StatelessWidget {
  final ChatDialog dialog;

  const _DialogItem({required this.dialog});

  void _deleteDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Удалить диалог?', style: GoogleFonts.montserrat()),
        content: Text(
          'Диалог будет удален только у вас.',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Отмена', style: GoogleFonts.montserrat()),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Удалить', style: GoogleFonts.montserrat()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      context.read<ChatBloc>().add(DeleteDialog(dialog.id));
    }
  }

  void _openChat(BuildContext context) async {
    print('🔵 [DialogItem] Clicked on dialog: ${dialog.id}');
    
    final chatBloc = context.read<ChatBloc>();
    final navigator = Navigator.of(context, rootNavigator: true);
    
    // Загружаем диалог
    chatBloc.add(LoadDialog(dialogId: dialog.id));
    
    print('🔵 [DialogItem] Waiting for dialog to load...');
    
    try {
      // Ждем пока диалог загрузится (слушаем stream с таймаутом)
      await chatBloc.stream.firstWhere(
        (state) {
          print('🔵 [DialogItem] State changed - isLoading: ${state.isLoading}, hasDialog: ${state.currentDialog != null}, error: ${state.error}');
          return !state.isLoading;
        },
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('🔴 [DialogItem] Timeout waiting for dialog');
          return chatBloc.state;
        },
      );
      
      final state = chatBloc.state;
      
      if (state.currentDialog != null) {
        print('✅ [DialogItem] Dialog loaded, opening chat screen...');
        print('🔵 [DialogItem] Pushing ChatScreen to navigator...');
        
        try {
          await navigator.push(
            createSwipeableRoute(
              builder: (_) {
                print('🔵 [DialogItem] Building ChatScreen...');
                print('🔵 [DialogItem] avatarUrl from dialog.user: ${dialog.user?.avatar}');
                print('🔵 [DialogItem] avatarUrl from currentDialog: ${state.currentDialog!.user?.avatar}');
                return ChatScreen(
                  userName: state.currentDialog!.user?.name ?? dialog.title,
                  lastSeen: state.currentDialog!.user?.statusOnline ?? dialog.date,
                  avatarUrl: state.currentDialog!.user?.avatar,
                  listing: ChatListing(
                    title: state.currentDialog!.ad?.title ?? dialog.title,
                    price: state.currentDialog!.ad?.price ?? '',
                    status: state.currentDialog!.ad?.statusName ?? '',
                    imageUrl: state.currentDialog!.ad?.image ?? dialog.image,
                    listingId: state.currentDialog!.ad?.id.toString(),
                  ),
                  dialogId: dialog.id,
                  userId: state.currentDialog!.user?.id ?? 0,
                  isShop: state.currentDialog!.user?.isShop ?? false,
                );
              },
            ),
          );
          
          print('✅ [DialogItem] Returned from chat screen');
          
          // Обновляем список диалогов после возврата
          chatBloc.add(LoadDialogs());
        } catch (e) {
          print('🔴 [DialogItem] Navigation error: $e');
        }
      } else {
        print('🔴 [DialogItem] Failed to load dialog: ${state.error}');
      }
    } catch (e) {
      print('🔴 [DialogItem] Exception: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Определяем какое изображение показывать
    String? imageUrl;
    if (dialog.ad != null && dialog.ad!.image != null) {
      // Для диалогов с объявлением - показываем фото объявления
      imageUrl = dialog.ad!.image;
      print('🔵 [DialogItem] Using ad image: $imageUrl');
    } else if (dialog.user != null && dialog.user!.avatar != null) {
      // Для диалогов с пользователем - показываем аватар пользователя
      imageUrl = dialog.user!.avatar;
      print('🔵 [DialogItem] Using user avatar: $imageUrl');
    } else if (dialog.image != null) {
      // Fallback на общее изображение диалога
      imageUrl = dialog.image;
      print('🔵 [DialogItem] Using dialog image: $imageUrl');
    } else {
      print('🔴 [DialogItem] No image available for dialog: ${dialog.id}');
      print('  - dialog.ad: ${dialog.ad}');
      print('  - dialog.user: ${dialog.user}');
      print('  - dialog.image: ${dialog.image}');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Dismissible(
        key: Key('chat_${dialog.id}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.delete_outline, color: Colors.white, size: 28),
              const SizedBox(height: 4),
              Text(
                'Удалить',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text('Удалить диалог?', style: GoogleFonts.montserrat()),
              content: Text(
                'Диалог будет удален только у вас.',
                style: GoogleFonts.montserrat(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text('Отмена', style: GoogleFonts.montserrat()),
                ),
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: Text('Удалить', style: GoogleFonts.montserrat()),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) {
          context.read<ChatBloc>().add(DeleteDialog(dialog.id));
        },
        child: InkWell(
          onTap: () => _openChat(context),
          splashColor: const Color(0xff917dfa).withOpacity(0.3),
          highlightColor: const Color(0xff917dfa).withOpacity(0.1),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Аватар
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _avatarPlaceholder(),
                        )
                      : _avatarPlaceholder(),
                ),
                const SizedBox(width: 12),
                // Инфо
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              dialog.title,
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            dialog.date,
                            style: GoogleFonts.montserrat(
                              fontSize: 12,
                              color: const Color(0xff999999),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      if (dialog.ad != null)
                        Text(
                          dialog.ad!.title,
                          style: GoogleFonts.montserrat(
                            fontSize: 13,
                            color: isDark ? Colors.white70 : const Color(0xff444444),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              dialog.text ?? 'Нет сообщений',
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                color: const Color(0xff999999),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (dialog.countMessages > 0)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xff917dfa),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${dialog.countMessages}',
                                style: GoogleFonts.montserrat(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          if (dialog.statusLastMessage == 1)
                            const Icon(
                              Icons.done_all,
                              color: Color(0xff4CAF50),
                              size: 18,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        color: const Color(0xffF5F7FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.person, color: Color(0xffcccccc), size: 30),
    );
  }
}
