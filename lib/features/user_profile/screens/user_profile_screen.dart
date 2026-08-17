import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hashtagg/features/profile/bloc/profile_bloc.dart';
import 'package:hashtagg/core/network/profile_api_repository.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/shared/domain/entities/listing.dart';
import 'package:hashtagg/shared/presentation/bloc/subscriptions_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/favorites_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/presentation/widgets/profile_stats.dart';
import 'package:hashtagg/shared/presentation/widgets/listing.dart'
    as ListingWidget;
import 'package:hashtagg/features/listing/screens/listing_screen.dart'
    show AnimatedImageSlider;
//import 'package:hashtagg/shared/presentation/test_data.dart';
//import 'package:hashtagg/shared/presentation/test_users.dart';

class UserProfileScreen extends StatefulWidget {
  final int userId;

  const UserProfileScreen({super.key, required this.userId});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool _showActiveListings = true; // true = Активные, false = Завершённые

  @override
  void initState() {
    super.initState();
    // Загружаем публичный профиль при инициализации
    context.read<ProfileBloc>().add(LoadPublicProfile(widget.userId));
  }
  
  String _getAuthToken() {
    var box = Hive.box('user');
    return box.get('auth_token', defaultValue: '') as String;
  }
  
  Future<void> _refreshProfile() async {
    context.read<ProfileBloc>().add(LoadPublicProfile(widget.userId));
    // Небольшая задержка для визуального эффекта
    await Future.delayed(const Duration(milliseconds: 500));
  }
  
  Future<void> _shareProfile(String userLink) async {
    try {
      if (userLink.isNotEmpty) {
        await Share.share(
          userLink,
          subject: 'Профиль пользователя',
        );
      }
    } catch (e) {
      print('🔴 [UserProfile] Error sharing: $e');
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка при отправке ссылки',
              style: GoogleFonts.montserrat(color: Colors.white),
            ),
            backgroundColor: isDark ? const Color(0xff233040) : null,
          ),
        );
      }
    }
  }
  
  Future<void> _toggleBlockUser(BuildContext context, bool currentlyBlocked) async {
    try {
      print('🔵 [UserProfile] _toggleBlockUser called');
      print('🔵 [UserProfile] currentlyBlocked: $currentlyBlocked');
      
      final authState = context.read<AuthBloc>().state;
      final token = _getAuthToken();
      
      print('🔵 [UserProfile] authState.user: ${authState.user}');
      print('🔵 [UserProfile] token from Hive: ${token.isNotEmpty ? "${token.substring(0, 20)}..." : "empty"}');
      
      if (authState.user == null || token.isEmpty) {
        print('🔴 [UserProfile] User or token is null/empty');
        if (mounted) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Необходима авторизация',
                style: GoogleFonts.montserrat(color: Colors.white),
              ),
              backgroundColor: isDark ? const Color(0xff233040) : null,
            ),
          );
        }
        return;
      }
      
      print('🔵 [UserProfile] Calling blockUser API');
      print('🔵 [UserProfile] idUserFrom: ${authState.user!.id}');
      print('🔵 [UserProfile] idUserTo: ${widget.userId}');
      
      final response = await ProfileApiRepository().blockUser(
        idUserFrom: authState.user!.id,
        token: token,
        idUserTo: widget.userId,
      );
      
      print('🔵 [UserProfile] blockUser response: $response');
      
      if (response['status'] == 'added' || response['status'] == 'delete') {
        final message = currentlyBlocked 
            ? 'Пользователь разблокирован' 
            : 'Пользователь заблокирован';
        
        print('✅ [UserProfile] Block/unblock successful: $message');
        
        if (mounted) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                message,
                style: GoogleFonts.montserrat(color: Colors.white),
              ),
              backgroundColor: isDark ? const Color(0xff233040) : null,
            ),
          );
          
          // Обновляем профиль
          context.read<ProfileBloc>().add(LoadPublicProfile(widget.userId));
        }
      } else {
        print('⚠️ [UserProfile] Unexpected response status: ${response['status']}');
      }
    } catch (e, stackTrace) {
      print('🔴 [UserProfile] Error blocking user: $e');
      print('🔴 [UserProfile] Stack trace: $stackTrace');
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка при блокировке пользователя',
              style: GoogleFonts.montserrat(color: Colors.white),
            ),
            backgroundColor: isDark ? const Color(0xff233040) : null,
          ),
        );
      }
    }
  }
  
  void _showComplaintDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textController = TextEditingController();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
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
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      maxLines: 5,
                      style: GoogleFonts.montserrat(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: isDark ? const Color(0xff151e27) : const Color(0xffF0F0F0),
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
                          final text = textController.text.trim();
                          if (text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Опишите причину жалобы',
                                  style: GoogleFonts.montserrat(color: Colors.white),
                                ),
                                backgroundColor: isDark ? const Color(0xff233040) : null,
                              ),
                            );
                            return;
                          }
                          
                          Navigator.pop(ctx);
                          await _submitComplaint(text);
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
  
  Future<void> _submitComplaint(String text) async {
    try {
      final authState = context.read<AuthBloc>().state;
      final token = _getAuthToken();
      
      if (authState.user == null || token.isEmpty) {
        if (mounted) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Необходима авторизация',
                style: GoogleFonts.montserrat(color: Colors.white),
              ),
              backgroundColor: isDark ? const Color(0xff233040) : null,
            ),
          );
        }
        return;
      }
      
      final response = await ProfileApiRepository().complainUser(
        idUserFrom: authState.user!.id,
        token: token,
        idUserTo: widget.userId,
        text: text,
      );
      
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final message = response['answer'] ?? 'Жалоба отправлена';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: GoogleFonts.montserrat(color: Colors.white),
            ),
            backgroundColor: isDark ? const Color(0xff233040) : null,
          ),
        );
      }
    } catch (e) {
      print('🔴 [UserProfile] Error submitting complaint: $e');
      if (mounted) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Ошибка при отправке жалобы',
              style: GoogleFonts.montserrat(color: Colors.white),
            ),
            backgroundColor: isDark ? const Color(0xff233040) : null,
          ),
        );
      }
    }
  }

  /// Безопасный парсинг double из dynamic (может быть String, int, double)
  double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  /// Безопасный парсинг int из dynamic (может быть String, int)
  int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  /// Замена localhost на настроенный mediaUrl
  String? _fixImageUrl(String? url) {
    if (url == null) return null;
    return ApiConfig.replaceMediaUrl(url);
  }

  String _formatRegistrationDate(String? dateStr) {
    if (dateStr == null) return '';
    
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'янв', 'фев', 'мар', 'апр', 'май', 'июн',
        'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
      ];
      final day = date.day.toString().padLeft(2, '0');
      final month = months[date.month - 1];
      return '$day $month';
    } catch (e) {
      return '';
    }
  }

  Widget _buildAdCard({
    required int adId,
    required String title,
    required String price,
    required String location,
    required String date,
    required int views,
    required List<String> images,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        context.push("/listing/$adId");
      },
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 1,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Слайдер изображений
            Expanded(
              child: images.isNotEmpty
                  ? AnimatedImageSlider(
                      imageUrls: images,
                      maxDots: 5,
                      activeDotWidth: 20,
                      inactiveDotSize: 7,
                      dotHeight: 7,
                    )
                  : Container(
                      color: isDark ? const Color(0xff151e27) : const Color(0xfff0f0f0),
                      child: Icon(
                        Icons.image,
                        size: 50,
                        color: isDark ? const Color(0xff808080) : const Color(0xffcccccc),
                      ),
                    ),
            ),
            // Информационный блок фиксированной высоты
            SizedBox(
              height: 132,
              child: Container(
                color: isDark ? const Color(0xff233040) : Colors.white,
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                        BlocBuilder<FavoritesBloc, FavoritesState>(
                          builder: (context, state) {
                            final isFavorite = state.ids.contains(adId);
                            return GestureDetector(
                              onTap: () {
                                if (isFavorite) {
                                  context.read<FavoritesBloc>().add(
                                    RemoveFavorite(adId),
                                  );
                                } else {
                                  // Создаем Listing объект для избранного со всеми данными
                                  final listing = Listing(
                                    id: adId,
                                    title: title,
                                    price: int.tryParse(price.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0,
                                    location: location,
                                    publishedAt: date,
                                    images: images,
                                    description: '',
                                    status: ListingStatus.active,
                                    userId: 0,
                                  );
                                  context.read<FavoritesBloc>().add(
                                    AddFavorite(adId, listing),
                                  );
                                }
                              },
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border_outlined,
                                color: const Color(0xff917dfa),
                                size: 24,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      price,
                      style: GoogleFonts.montserrat(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Spacer(),
                    // Просмотры
                    Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 11,
                          color: isDark ? Colors.white70 : const Color(0xff808080),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          views.toString(),
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: isDark ? Colors.white70 : const Color(0xff808080),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      location,
                      style: GoogleFonts.montserrat(
                        fontSize: 10,
                        color: isDark ? Colors.white70 : const Color(0xff808080),
                      ),
                    ),
                    // Дата публикации (если есть)
                    if (date.isNotEmpty)
                      Text(
                        date,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.montserrat(
                          fontSize: 10,
                          color: isDark ? Colors.white70 : const Color(0xff808080),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOptionsBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = context.read<ProfileBloc>().state;
    
    if (state is! PublicProfileLoaded) return;
    
    final userData = state.profileData['data'];
    if (userData == null) return;
    
    final isBlocked = userData['is_blocked'] == true;
    final userLink = _fixImageUrl(userData['link']) ?? '';
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xff233040) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(sheetContext).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Полоска сверху
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // Кнопка "Поделиться"
              InkWell(
                onTap: () async {
                  Navigator.pop(sheetContext);
                  await _shareProfile(userLink);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.share, color: isDark ? Colors.white : Colors.black87, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Поделиться',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              // Кнопка "Пожаловаться"
              InkWell(
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showComplaintDialog(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(Icons.flag, color: isDark ? Colors.white : Colors.black87, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        'Пожаловаться',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              // Кнопка "Заблокировать/Разблокировать"
              InkWell(
                onTap: () {
                  // Сохраняем контекст родительского виджета перед закрытием
                  final parentContext = context;
                  Navigator.pop(sheetContext);
                  // Используем сохраненный контекст
                  _toggleBlockUser(parentContext, isBlocked);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        isBlocked ? Icons.check_circle : Icons.block,
                        color: Colors.red,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        isBlocked ? 'Разблокировать' : 'Заблокировать',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Theme.of(context).appBarTheme.backgroundColor,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.more_vert, color: isDark ? Colors.white : Colors.black),
            onPressed: () => _showOptionsBottomSheet(context),
          ),
        ],
      ),
      body: BlocBuilder<ProfileBloc, ProfileStateOld>(
        builder: (context, state) {
          if (state is ProfileLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (state is ProfileError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Ошибка загрузки профиля',
                    style: GoogleFonts.montserrat(fontSize: 16),
                  ),
                  SizedBox(height: 10),
                  Text(
                    state.message,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      context.read<ProfileBloc>().add(
                        LoadPublicProfile(widget.userId),
                      );
                    },
                    child: Text('Повторить'),
                  ),
                ],
              ),
            );
          }

          if (state is! PublicProfileLoaded) {
            return Center(child: CircularProgressIndicator());
          }

          final userData = state.profileData['data'];
          if (userData == null) {
            return Center(child: Text('Профиль не найден'));
          }

          return RefreshIndicator(
            onRefresh: _refreshProfile,
            color: const Color(0xff917dfa),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
              children: [
              // Аватар с датой регистрации
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(50),
                        color: const Color(0xfff0f0f0),
                        image: userData['avatar'] != null
                            ? DecorationImage(
                                image: NetworkImage(_fixImageUrl(userData['avatar'])!),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: userData['avatar'] == null
                          ? const Icon(
                              Icons.person,
                              size: 50,
                              color: Color(0xffcccccc),
                            )
                          : null,
                    ),
                    if (userData['registration_date'] != null)
                      Positioned(
                        bottom: -5,
                        right: -5,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xff917dfa),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _formatRegistrationDate(userData['date']),
                            style: GoogleFonts.montserrat(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Имя пользователя
              Center(
                child: Text(
                  userData['display_name'] ?? 'Пользователь',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Название компании (если есть)
              if (userData['name_company'] != null && userData['name_company'].toString().isNotEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      userData['name_company'],
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

              const SizedBox(height: 20),

              // Статистика
              ProfileStats(
                rating: _parseDouble(userData['rating']),
                reviews: _parseInt(userData['reviews']),
                listings: _parseInt(userData['count_ads']),
                subscribers: _parseInt(userData['subscribers_count']),
                userId: widget.userId,
              ),

              const SizedBox(height: 20),

              // Кнопка подписки
              BlocListener<ProfileBloc, ProfileStateOld>(
                listener: (context, state) {
                  if (state is SubscribeToggled) {
                    final message = state.status == 'added' 
                        ? 'Вы подписались на пользователя' 
                        : 'Вы отписались от пользователя';
                    final isDark = Theme.of(context).brightness == Brightness.dark;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          message,
                          style: GoogleFonts.montserrat(color: Colors.white),
                        ),
                        backgroundColor: isDark ? const Color(0xff233040) : const Color(0xff917dfa),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                    
                    // Перезагружаем данные профиля после изменения подписки
                    context.read<ProfileBloc>().add(LoadPublicProfile(widget.userId));
                  }
                },
                child: BlocBuilder<SubscriptionsBloc, SubscriptionsState>(
                  builder: (context, subscriptionState) {
                    final isSubscribed = subscriptionState.ids.contains(widget.userId);

                    return GestureDetector(
                      onTap: () {
                        // Используем новый ProfileBloc метод
                        context.read<ProfileBloc>().add(ToggleSubscribe(widget.userId));
                        
                        // Также обновляем локальный SubscriptionsBloc для UI
                        final bloc = context.read<SubscriptionsBloc>();
                        if (isSubscribed) {
                          bloc.add(RemoveSubscription(widget.userId));
                        } else {
                          final user = User(
                            id: widget.userId,
                            name: userData['display_name'] ?? 'Пользователь',
                            avatar: userData['avatar'],
                          );
                          bloc.add(AddSubscription(widget.userId, user));
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSubscribed
                              ? const Color(0xfff0f0f0)
                              : const Color(0xff917dfa),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          isSubscribed ? 'Отписаться' : 'Подписаться',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isSubscribed
                                ? const Color(0xff666666)
                                : Colors.white,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 25),

              // Табы "Активные" / "Завершённые"
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff233040) : const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showActiveListings = true;
                          });
                        },
                        splashColor: const Color(0xff917dfa).withOpacity(0.3),
                        highlightColor: const Color(0xff917dfa).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Активные',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: _showActiveListings
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: _showActiveListings
                                  ? const Color(0xff917dfa)
                                  : (isDark ? Colors.white54 : Colors.black54),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showActiveListings = false;
                          });
                        },
                        splashColor: const Color(0xff917dfa).withOpacity(0.3),
                        highlightColor: const Color(0xff917dfa).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Завершённые',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 15,
                              fontWeight: !_showActiveListings
                                  ? FontWeight.w600
                                  : FontWeight.w500,
                              color: !_showActiveListings
                                  ? const Color(0xff917dfa)
                                  : (isDark ? Colors.white54 : Colors.black54),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Сетка объявлений
              FutureBuilder<Map<String, dynamic>>(
                future: ProfileApiRepository().getUserAds(
                  userId: widget.userId,
                  status: _showActiveListings ? 'active' : 'sold',
                ),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          'Ошибка загрузки объявлений',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }

                  final ads = snapshot.data!['data'] as List? ?? [];
                  
                  if (ads.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(40.0),
                        child: Text(
                          _showActiveListings
                              ? 'Нет активных объявлений'
                              : 'Нет завершённых объявлений',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    );
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.6,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                    ),
                    itemCount: ads.length,
                    itemBuilder: (context, index) {
                      final ad = ads[index];
                      
                      // Получаем цену как строку (уже отформатирована на бэкенде)
                      String? priceString;
                      if (ad['ads_price'] is Map) {
                        priceString = ad['ads_price']['now']?.toString();
                      } else {
                        priceString = ad['ads_price']?.toString();
                      }
                      
                      // Получаем изображения
                      final images = ad['ads_images'] != null 
                          ? (ad['ads_images'] as List).map((img) => _fixImageUrl(img.toString()) ?? '').toList()
                          : <String>[];
                      
                      return _buildAdCard(
                        adId: _parseInt(ad['ads_id']),
                        title: ad['ads_title'] ?? '',
                        price: priceString ?? 'Цена не указана',
                        location: ad['city_name'] ?? '',
                        date: ad['ads_datetime_add'] ?? '',
                        views: _parseInt(ad['count_view']),
                        images: images,
                      );
                    },
                  );
                },
              ),

              const SizedBox(height: 100),
            ],
          ),
          );
        },
      ),
    );
  }
}
