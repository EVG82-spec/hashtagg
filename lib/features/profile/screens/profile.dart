import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/loading_notifier.dart';
import 'package:hashtagg/features/profile/bloc/profile_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hashtagg/shared/presentation/widgets/profile_card.dart';
import 'package:hashtagg/features/profile/widgets/profile_navigation.dart';
import 'package:hashtagg/features/profile/widgets/profile_listing_card.dart';
import 'package:go_router/go_router.dart';
class ProfileScreen extends StatefulWidget {
  final String? initialSorting;
  
  const ProfileScreen({super.key, this.initialSorting});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with AutomaticKeepAliveClientMixin {
  String _selectedSorting = 'active';
  Map<String, dynamic>? _cachedProfileData;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    
    // Устанавливаем начальную сортировку из параметра, если передан
    if (widget.initialSorting != null && 
        ['active', 'sold', 'archive'].contains(widget.initialSorting)) {
      _selectedSorting = widget.initialSorting!;
    }
    
    // Загружаем данные профиля, объявления и подписки при инициализации
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProfileBloc>().add(LoadMyProfile());
      context.read<ProfileBloc>().add(LoadMyAds(sorting: _selectedSorting));
      context.read<ProfileBloc>().add(LoadSubscriptions());
    });
  }

  void _onSortingChanged(String? newValue) {
    if (newValue != null) {
      setState(() {
        _selectedSorting = newValue;
      });
      // Загружаем объявления с новой сортировкой
      context.read<ProfileBloc>().add(LoadMyAds(sorting: _selectedSorting));
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: BlocBuilder<ProfileBloc, ProfileStateOld>(
        builder: (context, state) {
          // Показываем loading только при первой загрузке профиля (нет кэша)
          // НЕ показываем loading при загрузке объявлений или подписок
          final isInitialLoading = state is ProfileLoading && 
                                   _cachedProfileData == null &&
                                   state is! MyAdsLoaded &&
                                   state is! SubscriptionsLoaded;
          
          // Обновляем состояние загрузки для bottomNavigationBar
          WidgetsBinding.instance.addPostFrameCallback((_) {
            context.read<LoadingNotifier>().setLoading(isInitialLoading);
          });
          
          return Stack(
            children: [
              // Основной контент профиля
              BlocBuilder<ProfileBloc, ProfileStateOld>(
                buildWhen: (previous, current) {
                  // Перерисовываем только при изменении профиля, не при загрузке объявлений
                  if (current is MyProfileLoaded) {
                    // Проверяем, изменились ли данные профиля
                    final hasChanged = _cachedProfileData == null || 
                                      _cachedProfileData != current.profileData;
                    if (hasChanged) {
                      _cachedProfileData = current.profileData;
                      return true;
                    }
                    return false; // Данные не изменились, не перерисовываем
                  }
                  // Перерисовываем только при первой загрузке (когда нет кэша)
                  return (current is ProfileLoading && _cachedProfileData == null) || 
                         current is ProfileError;
                },
                builder: (context, profileState) {
                  // Используем кешированные данные если они есть
                  final profileData = profileState is MyProfileLoaded 
                      ? profileState.profileData 
                      : _cachedProfileData;
              
              return Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: NotificationListener<OverscrollIndicatorNotification>(
                  onNotification: (notification) {
                    notification.disallowIndicator();
                    return true;
                  },
                  child: ListView(
                    physics: ClampingScrollPhysics(), // Отключаем bounce эффект
                    children: [
                    BlocBuilder<AuthBloc, AuthState>(
                      builder: (context, state) {
                        if (state.user == null) {
                      return SizedBox();
                    }
                    return Padding(
                      padding: EdgeInsetsGeometry.only(
                        top: 20,
                        left: 20,
                        right: 20,
                      ),
                      child: ProfileCard(user: state.user!),
                    );
                  },
                ),

                SizedBox(height: 20),

                      // ===== СТАТИСТИКА ИЗ API (С КЛИКАМИ) =====
                      if (profileData != null)
                        Padding(
                          padding: EdgeInsetsGeometry.only(left: 15, right: 15),
                          child: Builder(
                            builder: (context) {
                              // Парсим рейтинг как double
                              double rating = 0.0;
                              if (profileData['rating'] != null) {
                                if (profileData['rating'] is double) {
                                  rating = profileData['rating'];
                                } else if (profileData['rating'] is int) {
                                  rating = (profileData['rating'] as int).toDouble();
                                } else if (profileData['rating'] is String) {
                                  rating = double.tryParse(profileData['rating']) ?? 0.0;
                                }
                              }

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // РЕЙТИНГ
                                  GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Экран рейтинга в разработке')),
                                      );
                                    },
                                    child: Column(
                                      children: [
                                        Text(
                                          rating.toStringAsFixed(1),
                                          style: GoogleFonts.montserrat(
                                            fontSize: 18,
                                            fontWeight: FontWeight(600),
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        Text(
                                          'Рейтинг',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ОТЗЫВЫ
                                  GestureDetector(
                                    onTap: () {
                                      final userId = profileData['user_id'] ?? profileData['id'];
                                      if (userId != null) {
                                        GoRouter.of(context).push('/user/$userId/reviews');
                                      } else {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Ошибка: пользователь не найден')),
                                        );
                                      }
                                    },
                                    child: Column(
                                      children: [
                                        Text(
                                          '${profileData['reviews'] ?? '0'}',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 18,
                                            fontWeight: FontWeight(600),
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        Text(
                                          'Отзывы',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ОБЪЯВЛЕНИЯ
                                  GestureDetector(
                                    onTap: () {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Экран объявлений в разработке')),
                                      );
                                    },
                                    child: Column(
                                      children: [
                                        Text(
                                          '${profileData['count_ads'] ?? '0'}',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 18,
                                            fontWeight: FontWeight(600),
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        Text(
                                          'Объявлений',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // ПОДПИСЧИКИ
                                  GestureDetector(
                                    onTap: () {
                                      GoRouter.of(context).push('/subscriptions');
                                    },
                                    child: Column(
                                      children: [
                                        Text(
                                          '${profileData['subscribers_count'] ?? '0'}',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 18,
                                            fontWeight: FontWeight(600),
                                            color: isDark ? Colors.white : Colors.black,
                                          ),
                                        ),
                                        Text(
                                          'Подписчиков',
                                          style: GoogleFonts.montserrat(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : Colors.black,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        )
                      else
                  Padding(
                    padding: EdgeInsetsGeometry.only(left: 15, right: 15),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          children: [
                            Text(
                              '0.0',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight(600),
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              'Рейтинг',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '0',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight(600),
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              'Отзывы',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '0',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight(600),
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              'Объявлений',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              '0',
                              style: GoogleFonts.montserrat(
                                fontSize: 18,
                                fontWeight: FontWeight(600),
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            Text(
                              'Подписчиков',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                color: isDark ? Colors.white70 : Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                SizedBox(height: 20),

                const ProfileNavigation(),

                SizedBox(height: 15),

                Padding(
                  padding: EdgeInsetsGeometry.only(left: 20, right: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Объявления',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight(500),
                          fontSize: 18,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      DropdownButton<String>(
                        value: _selectedSorting,
                        hint: Text('Выберите пункт'),
                        style: GoogleFonts.montserrat(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 14,
                        ),
                        dropdownColor: isDark ? const Color(0xff233040) : Colors.white,
                        underline: SizedBox(),
                        onChanged: _onSortingChanged,
                        items: [
                          DropdownMenuItem(value: 'active', child: Text('Активные')),
                          DropdownMenuItem(value: 'sold', child: Text('Проданные')),
                          DropdownMenuItem(value: 'archive', child: Text('В архиве')),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 15),

                // Объявления из API
                BlocBuilder<ProfileBloc, ProfileStateOld>(
                  buildWhen: (previous, current) {
                    // Перестраиваем только когда меняется состояние объявлений
                    return current is MyAdsLoaded || current is ProfileLoading;
                  },
                  builder: (context, state) {
                    if (state is MyAdsLoaded) {
                      if (state.ads.isEmpty) {
                        return Padding(
                          padding: EdgeInsetsGeometry.only(left: 20, right: 20),
                          child: Center(
                            child: Column(
                              children: [
                                SizedBox(height: 40),
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'Нет объявлений',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      // Показываем все объявления в сетке 2 колонки
                      return Padding(
                        padding: EdgeInsetsGeometry.only(left: 20, right: 20),
                        child: GridView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 20,
                            mainAxisSpacing: 20,
                            childAspectRatio: 0.6225, // Соотношение ширины к высоте
                          ),
                          itemCount: state.ads.length,
                          itemBuilder: (context, index) {
                            final ad = state.ads[index];
                            final adId = ad['ads_id']?.toString() ?? index.toString();
                            return ProfileListingCard(
                              key: ValueKey('ad_$adId'),
                              adData: ad,
                              currentSorting: _selectedSorting,
                            );
                          },
                        ),
                      );
                    }

                    // Показываем индикатор загрузки или пустое состояние
                    if (state is ProfileLoading) {
                      return Padding(
                        padding: EdgeInsetsGeometry.only(left: 20, right: 20),
                        child: SizedBox(
                          height: 284,
                          child: Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                      );
                    }

                    // Пустое состояние по умолчанию
                    return Padding(
                      padding: EdgeInsetsGeometry.only(left: 20, right: 20),
                      child: SizedBox(
                        height: 284,
                        child: Center(
                          child: Text(
                            'Загрузка объявлений...',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                SizedBox(height: 20),
              ],
            ),
                  ), // Закрываем NotificationListener
          );
                },
              ),
              
              // Слой загрузки поверх контента
              if (isInitialLoading)
                Positioned.fill(
                  child: AbsorbPointer(
                    child: Container(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Color(0xff917dfa),
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
}
