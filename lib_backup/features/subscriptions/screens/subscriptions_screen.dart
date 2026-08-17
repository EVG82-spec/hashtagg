import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hashtagg/features/profile/bloc/profile_bloc.dart' as profile;
import 'package:hashtagg/shared/presentation/bloc/subscriptions_bloc.dart';
import 'package:hashtagg/shared/domain/entities/user.dart';
import 'package:hashtagg/core/network/api_config.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key});

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  @override
  void initState() {
    super.initState();
    // Загружаем подписки при инициализации
    context.read<profile.ProfileBloc>().add(profile.LoadSubscriptions());
  }

  String? _fixImageUrl(String? url) {
    if (url == null) return null;
    return ApiConfig.replaceMediaUrl(url);
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
          'Подписки',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
      ),
      body: BlocBuilder<profile.ProfileBloc, profile.ProfileStateOld>(
        builder: (context, state) {
          if (state is profile.ProfileLoading) {
            return Center(
              child: CircularProgressIndicator(
                color: Color(0xff917dfa),
              ),
            );
          }

          if (state is profile.ProfileError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Ошибка загрузки',
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    state.message,
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      context.read<profile.ProfileBloc>().add(profile.LoadSubscriptions());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xff917dfa),
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      'Повторить',
                      style: GoogleFonts.montserrat(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          if (state is! profile.SubscriptionsLoaded) {
            return Center(
              child: CircularProgressIndicator(
                color: Color(0xff917dfa),
              ),
            );
          }

          final subscriptions = state.subscriptions;

          if (subscriptions.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                context.read<profile.ProfileBloc>().add(profile.LoadSubscriptions());
                await Future.delayed(Duration(milliseconds: 500));
              },
              color: Color(0xff917dfa),
              edgeOffset: 40.0,
              displacement: 20.0,
              strokeWidth: 3.0,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: SizedBox(
                  height: MediaQuery.of(context).size.height - 200,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.people_outline,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Нет подписок',
                          style: GoogleFonts.montserrat(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Подпишитесь на пользователей,\nчтобы следить за их объявлениями',
                          style: GoogleFonts.montserrat(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<profile.ProfileBloc>().add(profile.LoadSubscriptions());
              await Future.delayed(Duration(milliseconds: 500));
            },
            color: Color(0xff917dfa),
            edgeOffset: 40.0,
            displacement: 20.0,
            strokeWidth: 3.0,
            child: ListView.separated(
            padding: EdgeInsets.all(20),
            itemCount: subscriptions.length,
            separatorBuilder: (context, index) => SizedBox(height: 12),
            itemBuilder: (context, index) {
              final subscription = subscriptions[index];
              // Безопасное преобразование - API может вернуть строки
              final userId = int.tryParse(subscription['id_user_to']?.toString() ?? '0') ?? 0;
              final userName = subscription['name']?.toString() ?? 'Пользователь';
              final userAvatar = _fixImageUrl(subscription['avatar']?.toString());
              final adsCount = int.tryParse(subscription['count_ads']?.toString() ?? '0') ?? 0;
              final subscriptionId = int.tryParse(subscription['id']?.toString() ?? '0') ?? 0;

              return Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff233040) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Аватар
                    GestureDetector(
                      onTap: () => context.push('/user/$userId'),
                      child: Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          color: Color(0xfff0f0f0),
                        ),
                        child: userAvatar != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(28),
                                child: Image.network(
                                  userAvatar,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(
                                      Icons.person,
                                      size: 32,
                                      color: Colors.grey[400],
                                    );
                                  },
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 32,
                                color: Colors.grey[400],
                              ),
                      ),
                    ),
                    SizedBox(width: 12),
                    // Информация
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/user/$userId'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userName,
                              style: GoogleFonts.montserrat(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              '$adsCount ${_pluralizeAds(adsCount)}',
                              style: GoogleFonts.montserrat(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Кнопка удаления
                    IconButton(
                      icon: Icon(
                        Icons.person_remove_outlined,
                        color: Colors.red,
                      ),
                      onPressed: () {
                        _showDeleteConfirmation(context, subscriptionId, userName);
                      },
                    ),
                  ],
                ),
              );
            },
            ),
          );
        },
      ),
    );
  }

  String _pluralizeAds(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'объявление';
    } else if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'объявления';
    } else {
      return 'объявлений';
    }
  }

  void _showDeleteConfirmation(BuildContext context, int subscriptionId, String userName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Отписаться?',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите отписаться от $userName?',
          style: GoogleFonts.montserrat(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Отмена',
              style: GoogleFonts.montserrat(
                color: Colors.grey[600],
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<profile.ProfileBloc>().add(profile.DeleteSubscription(subscriptionId));
              
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Вы отписались от $userName',
                    style: GoogleFonts.montserrat(),
                  ),
                  backgroundColor: Color(0xff917dfa),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Text(
              'Отписаться',
              style: GoogleFonts.montserrat(
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
