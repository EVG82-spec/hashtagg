import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:hive/hive.dart';
import 'package:hashtagg/shared/presentation/bloc/favorites_bloc.dart';
import 'package:hashtagg/shared/domain/entities/listing.dart';
import 'package:hashtagg/shared/presentation/bloc/listing_bloc.dart';
import 'package:hashtagg/features/profile/bloc/profile_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/loading_notifier.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/core/network/profile_api_repository.dart';

class ProfileListingCard extends StatelessWidget {
  final Map<String, dynamic> adData;
  final String currentSorting;
  
  // Статический флаг для блокировки множественных операций
  static bool _isProcessing = false;

  const ProfileListingCard({
    super.key,
    required this.adData,
    this.currentSorting = 'active',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Безопасное преобразование - API может вернуть строки
    final adsId = int.tryParse(adData['ads_id']?.toString() ?? '0') ?? 0;
    final title = adData['ads_title']?.toString() ?? 'Без названия';
    final status = int.tryParse(adData['ads_status']?.toString() ?? '1') ?? 1;
    final statusName = adData['ads_status_name']?.toString() ?? 'Активно';
    
    // Обрабатываем цену - может быть объектом {now: "...", old: 0} или строкой
    String priceDisplay = '0';
    int priceValue = 0;
    if (adData['ads_price'] != null) {
      if (adData['ads_price'] is Map) {
        priceDisplay = adData['ads_price']['now']?.toString() ?? '0';
      } else {
        priceDisplay = adData['ads_price'].toString();
      }
      // Извлекаем числовое значение для объекта Listing
      priceValue = int.tryParse(priceDisplay.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    }
    
    final city = adData['city_name'] ?? '';
    final images = adData['ads_images'] as List? ?? [];
    final mainImage = images.isNotEmpty ? images[0] : '';

    // Создаем объект Listing для избранного
    final listing = Listing(
      id: adsId,
      title: title,
      price: priceValue,
      location: city,
      description: adData['ads_text'] ?? '',
      views: adData['count_view'] != null ? int.tryParse(adData['count_view'].toString()) : null,
      publishedAt: adData['ads_datetime_add'],
      status: ListingStatus.active,
      userId: adData['user']?['id_hash'] != null ? int.tryParse(adData['user']['id_hash'].toString()) : null,
      images: images.map((e) => e.toString()).toList(),
    );

    return BlocBuilder<FavoritesBloc, FavoritesState>(
      builder: (context, state) {
        final isFavorite = state.ids.contains(adsId);

        return GestureDetector(
          onTap: () {
            context.push("/listing/$adsId");
          },
          child: Container(
            height: 284,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              boxShadow: isDark ? null : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 1,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Изображение с меню действий
                Expanded(
                  child: Stack(
                    children: [
                      Container(
                        color: isDark ? const Color(0xff151e27) : Colors.grey[200],
                        child: mainImage.isNotEmpty
                            ? Image.network(
                                mainImage,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Icon(
                                      Icons.image_not_supported,
                                      size: 48,
                                      color: isDark ? Colors.grey[600] : Colors.grey[400],
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded /
                                              loadingProgress.expectedTotalBytes!
                                          : null,
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Icon(
                                  Icons.image,
                                  size: 48,
                                  color: isDark ? Colors.grey[600] : Colors.grey[400],
                                ),
                              ),
                      ),
                      // Меню действий
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.more_vert, color: Colors.white, size: 20),
                            onPressed: () => _showAdMenu(context, status, adsId),
                          ),
                        ),
                      ),
                      // Статус объявления
                      if (status != 1)
                        Positioned(
                          bottom: 8,
                          left: 8,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: 150, // Максимальная ширина лейбла
                            ),
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: _getStatusColor(status),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                statusName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.montserrat(
                                  fontSize: 10,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                // Информация
                SizedBox(
                  height: 132,
                  child: Container(
                    color: isDark ? const Color(0xff233040) : Colors.white,
                    padding: EdgeInsets.all(8),
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
                                softWrap: true,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 2,
                                style: GoogleFonts.montserrat(
                                  fontWeight: FontWeight(500),
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                            ),
                            SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                if (isFavorite) {
                                  context.read<FavoritesBloc>().add(
                                        RemoveFavorite(adsId),
                                      );
                                } else {
                                  context.read<FavoritesBloc>().add(
                                        AddFavorite(adsId, listing),
                                      );
                                }
                              },
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite
                                    : Icons.favorite_border_outlined,
                                color: Color(0xff917dfa),
                                size: 24,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        // Просмотры
                        Row(
                          children: [
                            Icon(
                              Icons.visibility_outlined,
                              size: 11,
                              color: isDark ? Colors.white70 : Color(0xff808080),
                            ),
                            SizedBox(width: 3),
                            Text(
                              adData['count_view']?.toString() ?? '0',
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                color: isDark ? Colors.white70 : Color(0xff808080),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4),
                        Text(
                          priceDisplay,
                          style: GoogleFonts.montserrat(
                            fontWeight: FontWeight(700),
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Spacer(),
                        Text(
                          city,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            color: isDark ? Colors.white70 : Color(0xff808080),
                          ),
                        ),
                        // Дата публикации (если есть)
                        if (adData['ads_datetime_add']?.toString().isNotEmpty == true)
                          Text(
                            adData['ads_datetime_add']?.toString() ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.montserrat(
                              fontSize: 10,
                              color: isDark ? Colors.white70 : Color(0xff808080),
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
      },
    );
  }

  void _handleMenuAction(BuildContext context, String action, int adsId) async {
    print('🔵 [ProfileListingCard] _handleMenuAction called: action=$action, adsId=$adsId');
    
    // Устанавливаем флаг обработки
    _isProcessing = true;
    
    // Сохраняем ссылку на ProfileBloc до асинхронных операций
    final profileBloc = context.read<ProfileBloc>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Обработка редактирования
    if (action == 'edit') {
      print('🔵 [ProfileListingCard] Navigating to edit screen');
      await context.push('/listing-edit/$adsId');
      // Перезагружаем объявления профиля после редактирования
      profileBloc.add(LoadMyAds());
      _isProcessing = false;
      return;
    }

    int newStatus;
    String message;

    switch (action) {
      case 'activate':
        newStatus = 1;
        message = 'Объявление опубликовано';
        break;
      case 'sold':
        newStatus = 5;
        message = 'Объявление отмечено как проданное';
        break;
      case 'archive':
        newStatus = 2; // Снято с публикации (архив)
        message = 'Объявление перемещено в архив';
        break;
      case 'delete':
        newStatus = 8;
        message = 'Объявление удалено';
        break;
      default:
        print('❌ [ProfileListingCard] Unknown action: $action');
        _isProcessing = false;
        return;
    }

    print('🔵 [ProfileListingCard] Changing status to $newStatus for ad $adsId');

    // Создаем временный ListingBloc для изменения статуса
    final listingBloc = ListingBloc(
      listing: Listing(
        id: adsId,
        title: '',
        description: '',
        price: 0,
        location: '',
        views: 0,
        status: ListingStatus.active,
        userId: 0,
        publishedAt: '',
      ),
      authBloc: context.read(),
    );

    // Ждем завершения изменения статуса
    final completer = Completer<void>();
    final subscription = listingBloc.stream.listen((state) {
      // Проверяем, что статус изменен (isChangingStatus стал false после true)
      if (!state.isChangingStatus && state.error == null) {
        print('🔵 [ProfileListingCard] Status change confirmed by bloc');
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
    });

    listingBloc.add(ChangeAdStatus(adId: adsId, status: newStatus));

    // Ждем подтверждения изменения статуса
    await completer.future.timeout(
      Duration(seconds: 5),
      onTimeout: () {
        print('⚠️ [ProfileListingCard] Status change timeout');
      },
    );
    
    await subscription.cancel();

    // Показываем уведомление
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.montserrat()),
        backgroundColor: Color(0xff917dfa),
        duration: Duration(seconds: 2),
      ),
    );

    // Перезагружаем список после любого действия из меню
    print('🔵 [ProfileListingCard] Reloading ads after $action');
    profileBloc.add(LoadMyAds(sorting: currentSorting));
    
    // Сбрасываем флаг обработки
    _isProcessing = false;
  }

  void _showAdMenu(BuildContext context, int status, int adsId) {
    // Блокируем если уже идет обработка
    if (_isProcessing) {
      print('⚠️ [ProfileListingCard] Menu blocked - operation in progress');
      return;
    }
    
    print('🔵 [ProfileListingCard] _showAdMenu called: status=$status, adsId=$adsId');
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Закрываем все активные SnackBar'ы перед показом модалки
    ScaffoldMessenger.of(context).clearSnackBars();
    
    // Скрываем bottomNavigationBar
    context.read<LoadingNotifier>().setLoading(true);
    
    showModalBottomSheet(
      context: context,
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
                  color: isDark ? Colors.white24 : const Color(0xffE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Редактировать
              if (status != 2 && status != 6)
                ListTile(
                  leading: Icon(Icons.edit_outlined, color: isDark ? Colors.white : Colors.black),
                  title: Text(
                    'Редактировать',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () {
                    print('🔵 [ProfileListingCard] Edit tapped');
                    Navigator.pop(context);
                    _handleMenuAction(context, 'edit', adsId);
                  },
                ),
              // Опубликовать
              if (status == 2)
                ListTile(
                  leading: Icon(Icons.publish_outlined, color: isDark ? Colors.white : Colors.black),
                  title: Text(
                    'Опубликовать',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () {
                    print('🔵 [ProfileListingCard] Activate tapped');
                    Navigator.pop(context);
                    _handleMenuAction(context, 'activate', adsId);
                  },
                ),
              // Оплатить публикацию
              if (status == 6)
                ListTile(
                  leading: Icon(Icons.payment_outlined, color: isDark ? Colors.white : Colors.black),
                  title: Text(
                    'Оплатить публикацию',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () {
                    print('🔵 [ProfileListingCard] Pay publication tapped');
                    Navigator.pop(context);
                    _showPaymentConfirmSheet(context, adsId);
                  },
                ),
              // Продано
              if (status == 1)
                ListTile(
                  leading: Icon(Icons.sell_outlined, color: isDark ? Colors.white : Colors.black),
                  title: Text(
                    'Продано',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () {
                    print('🔵 [ProfileListingCard] Sold tapped');
                    Navigator.pop(context);
                    _handleMenuAction(context, 'sold', adsId);
                  },
                ),
              // В архив
              if (status == 1)
                ListTile(
                  leading: Icon(Icons.archive_outlined, color: isDark ? Colors.white : Colors.black),
                  title: Text(
                    'В архив',
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                  onTap: () {
                    print('🔵 [ProfileListingCard] Archive tapped');
                    Navigator.pop(context);
                    _handleMenuAction(context, 'archive', adsId);
                  },
                ),
              // Удалить
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: Text(
                  'Удалить',
                  style: GoogleFonts.montserrat(fontSize: 15, color: Colors.red),
                ),
                onTap: () {
                  print('🔵 [ProfileListingCard] Delete tapped for ad $adsId');
                  Navigator.pop(context);
                  _handleMenuAction(context, 'delete', adsId);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    ).whenComplete(() {
      print('🔵 [ProfileListingCard] BottomSheet closed');
      // Показываем bottomNavigationBar обратно после закрытия модалки
      context.read<LoadingNotifier>().setLoading(false);
    });
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case 5: // Продано
        return Colors.orange;
      case 2: // Архив (Снято с публикации)
        return Colors.blue;
      case 3: // Заблокировано
        return Colors.red;
      case 6: // Ждёт оплаты
        return Colors.amber;
      case 7: // Отклонено
        return Colors.red;
      case 8: // Удалено
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Показать модальное окно подтверждения оплаты
  void _showPaymentConfirmSheet(BuildContext context, int adsId) async {
    final authBloc = context.read<AuthBloc>();
    final user = authBloc.state.user;

    if (user == null) return;

    // Получаем информацию о цене из adData и безопасно преобразуем в int
    final categoryPriceRaw = adData['category_price'];
    final categoryPrice = categoryPriceRaw is int 
        ? categoryPriceRaw 
        : (categoryPriceRaw is String 
            ? int.tryParse(categoryPriceRaw) ?? 99 
            : 99);

    // Сохраняем все необходимые ссылки ДО открытия модалки
    final loadingNotifier = context.read<LoadingNotifier>();
    final profileBloc = context.read<ProfileBloc>();
    final navigatorState = Navigator.of(context, rootNavigator: true);

    // Скрываем bottomNavigationBar ПЕРЕД открытием модалки
    loadingNotifier.setLoading(true);

    await showModalBottomSheet(
      context: context,
      useRootNavigator: true, // Открываем поверх всего
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(modalContext).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8DEFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  size: 72,
                  color: Color(0xff917dfa),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Спишется с баланса',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$categoryPrice ₽',
                style: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => _payForPublication(
                    context,
                    modalContext,
                    adsId,
                    categoryPrice,
                    authBloc,
                    loadingNotifier,
                    profileBloc,
                    navigatorState,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff917dfa),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Продолжить',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    
    // Показываем bottomNavigationBar обратно после закрытия модалки
    loadingNotifier.setLoading(false);
  }

  /// Оплата публикации
  Future<void> _payForPublication(
    BuildContext context,
    BuildContext modalContext,
    int adsId,
    int price,
    AuthBloc authBloc,
    LoadingNotifier loadingNotifier,
    ProfileBloc profileBloc,
    NavigatorState navigatorState,
  ) async {
    final user = authBloc.state.user;

    if (user == null) {
      Navigator.pop(modalContext);
      loadingNotifier.setLoading(false);
      return;
    }

    final box = Hive.box('user');
    final token = box.get('auth_token') as String?;

    if (token == null) {
      Navigator.pop(modalContext);
      loadingNotifier.setLoading(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка авторизации')),
        );
      }
      return;
    }

    final balance = user.walletBalance;

    if (balance < price) {
      Navigator.pop(modalContext);
      loadingNotifier.setLoading(false);
      if (context.mounted) {
        _showInsufficientFundsSheet(context, balance);
      }
      return;
    }

    // Создаем экземпляр API
    final profileApi = ProfileApiRepository();

    final result = await profileApi.payCategoryPublication(
      userId: user.id,
      token: token,
      adId: adsId,
    );

    print('🔵 [ProfileListingCard] Payment result: $result');

    if (result['status'] == true) {
      print('✅ [ProfileListingCard] Payment successful, updating balance');
      
      // Обновляем баланс пользователя
      authBloc.add(UserUpdated(user.copyWith(
        walletBalance: balance - price,
      )));

      Navigator.pop(modalContext);
      
      print('🔵 [ProfileListingCard] Modal closed, showing success sheet');
      
      // Небольшая задержка перед показом следующей модалки
      await Future.delayed(Duration(milliseconds: 300));
      
      // Используем сохраненный navigatorState для показа модалки
      print('✅ [ProfileListingCard] Showing success sheet using navigatorState');
      _showSuccessSheetWithNavigator(navigatorState, loadingNotifier);
      
      // Перезагружаем список объявлений
      profileBloc.add(LoadMyAds(sorting: currentSorting));
      
      // Сбрасываем loading после небольшой задержки
      Future.delayed(Duration(milliseconds: 500), () {
        loadingNotifier.setLoading(false);
      });
    } else if (result['error'] == 'insufficient_balance') {
      Navigator.pop(modalContext);
      loadingNotifier.setLoading(false);
      if (context.mounted) {
        _showInsufficientFundsSheet(context, balance);
      }
    } else {
      Navigator.pop(modalContext);
      loadingNotifier.setLoading(false);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Ошибка оплаты')),
        );
      }
    }
  }

  /// Показать модальное окно недостаточно средств
  void _showInsufficientFundsSheet(BuildContext context, int balance) async {
    // Скрываем bottomNavigationBar ПЕРЕД открытием модалки
    final loadingNotifier = context.read<LoadingNotifier>();
    loadingNotifier.setLoading(true);
    
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true, // Открываем поверх всего
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 140,
                height: 140,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8DEFF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.payments_rounded,
                  size: 72,
                  color: Color(0xff917dfa),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Недостаточно средств',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '$balance ₽',
                style: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Баланс кошелька',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/wallet');
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xff917dfa),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Пополнить баланс',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    
    // Показываем bottomNavigationBar обратно после закрытия модалки
    loadingNotifier.setLoading(false);
  }

  /// Показать модальное окно успешной оплаты
  void _showSuccessSheet(BuildContext context) async {
    print('🔵 [ProfileListingCard] _showSuccessSheet called');
    
    // Скрываем bottomNavigationBar ПЕРЕД открытием модалки
    final loadingNotifier = context.read<LoadingNotifier>();
    loadingNotifier.setLoading(true);
    
    print('🔵 [ProfileListingCard] Opening success modal');
    
    await showModalBottomSheet(
      context: context,
      useRootNavigator: true, // Открываем поверх всего
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 60,
                  color: Color(0xFF4CAF8E),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Оплачено!',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Объявление успешно опубликовано',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF8E),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Отлично!',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    
    print('🔵 [ProfileListingCard] Success modal closed');
    
    // Показываем bottomNavigationBar обратно после закрытия модалки
    loadingNotifier.setLoading(false);
  }

  /// Показать модальное окно успешной оплаты используя NavigatorState
  void _showSuccessSheetWithNavigator(NavigatorState navigatorState, LoadingNotifier loadingNotifier) async {
    print('🔵 [ProfileListingCard] _showSuccessSheetWithNavigator called');
    
    // Скрываем bottomNavigationBar ПЕРЕД открытием модалки
    loadingNotifier.setLoading(true);
    
    print('🔵 [ProfileListingCard] Opening success modal with navigatorState');
    
    await showModalBottomSheet(
      context: navigatorState.context,
      useRootNavigator: true, // Открываем поверх всего
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).padding.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 100,
                height: 100,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8F5E9),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 60,
                  color: Color(0xFF4CAF8E),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Оплачено!',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Объявление успешно опубликовано',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF8E),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Отлично!',
                    style: GoogleFonts.montserrat(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    
    print('🔵 [ProfileListingCard] Success modal closed');
    
    // Показываем bottomNavigationBar обратно после закрытия модалки
    loadingNotifier.setLoading(false);
  }
}
