import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:provider/provider.dart';
import 'package:yandex_mapkit/yandex_mapkit.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hashtagg/core/network/api_config.dart';
import 'package:hashtagg/shared/application/usecase/get_current_user_usecase.dart';
import 'package:hashtagg/shared/application/usecase/login_usecase.dart';
import 'package:hashtagg/shared/application/usecase/logout_usecase.dart';
import 'package:hashtagg/shared/infrastructure/services/test_auth_service.dart';
import 'package:hashtagg/shared/presentation/bloc/auth_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/favorites_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/subscriptions_bloc.dart';
import 'package:hashtagg/shared/presentation/bloc/loading_notifier.dart';
import 'package:hashtagg/shared/presentation/bloc/navigation_notifier.dart';
import 'package:hashtagg/features/profile/bloc/profile_bloc.dart';
import 'package:hashtagg/features/chats/bloc/chat_bloc.dart';
import 'package:hashtagg/features/reviews/bloc/reviews_bloc.dart';
import 'package:hashtagg/features/home/bloc/blog_bloc.dart';
import 'package:hashtagg/features/wallet/bloc/wallet_bloc.dart';
import 'package:hashtagg/features/shop/bloc/shop_bloc.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';
import 'package:hashtagg/core/network/dio_client.dart';
import 'package:hashtagg/features/welcome/screens/welcome_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hashtagg/core/services/first_launch_service.dart';
import 'package:hashtagg/core/services/deep_link_service.dart';
import 'package:hashtagg/core/services/notification_bloc.dart';
import 'package:hashtagg/core/services/notification_initializer.dart';
import 'package:hashtagg/core/services/notification_background_service.dart';
import 'package:hashtagg/core/services/unread_messages_bloc.dart' as unread;
import 'package:hashtagg/core/services/notification_service.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'core/routes.dart';
import 'core/theme/theme_provider.dart';
import 'core/theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:io';
import 'package:hashtagg/features/home/bloc/categories_bloc.dart';
import 'package:hashtagg/features/home/bloc/stories_bloc.dart';
import 'package:hashtagg/features/home/bloc/banner_bloc.dart';
import 'package:hashtagg/features/home/bloc/feed_bloc.dart';
import 'package:hashtagg/features/shop/bloc/public/shop_public_bloc.dart';
import 'package:hashtagg/core/network/shops_api_repository.dart';
import 'package:hashtagg/core/network/shop_api_repository.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

// Константы для WorkManager (должны быть доступны в изоляте)
const String _kWorkManagerVersion = 'v2.1'; // Версия для отладки
const String _kOneOffTaskName = 'notification_check_oneoff';
const String _kPeriodicTaskName = 'notification_check_periodic';
const String _kShownNotificationsKey = 'shown_notifications';
const String _kLastScheduleKey =
    'last_schedule_time'; // Для защиты от дубликатов
const Duration _kQuickCheckInterval = Duration(
  seconds: 5,
); // Быстрые проверки каждую минуту
// Важно: WorkManager использует этот URL для фоновых запросов
// Используем ApiConfig.baseUrl и ApiConfig.apiKey для корректной работы на проде

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // ✅ ЛОГ В ФАЙЛ (на устройстве)
  final file = File('/sdcard/fcm_log.txt');
  await file.writeAsString(
    '${DateTime.now()}: Уведомление получено: ${message.notification?.title}\n',
    mode: FileMode.append,
  );

  // Этот код выполняется, даже когда приложение закрыто
  print('📨 [FCM] Фоновое уведомление: ${message.notification?.title}');

  // Показать локальное уведомление
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );
  await plugin.show(
    DateTime.now().millisecondsSinceEpoch ~/ 1000,
    message.notification?.title ?? 'Новое уведомление',
    message.notification?.body ?? '',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'chat_messages',
        'Сообщения',
        channelDescription: 'Уведомления о новых сообщениях',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

/// Callback для WorkManager - ДОЛЖЕН быть top-level функцией
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    final timestamp = DateTime.now().toIso8601String();
    print(
      '🔄 [WorkManager $_kWorkManagerVersion] Task started: $task at $timestamp',
    );
    print(
      '🔧 [WorkManager] Quick check interval constant: ${_kQuickCheckInterval.inMinutes} min',
    );

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');
      final authToken = prefs.getString('auth_token');
      final isEnabled = prefs.getBool('background_service_enabled') ?? false;

      if (!isEnabled) {
        print('⚠️ [WorkManager] Service disabled');
        return true;
      }

      if (userId == null || authToken == null) {
        print('❌ [WorkManager] Missing credentials');
        return false;
      }

      // Проверяем уведомления
      await _checkNotifications(userId, authToken, prefs);

      // Планируем следующую задачу ТОЛЬКО если это периодическая задача
      if (task == _kPeriodicTaskName) {
        print('🔄 [WorkManager] Periodic task - scheduling one-off chain');
        await _scheduleNext();
      } else if (task == _kOneOffTaskName) {
        print('🔗 [WorkManager] One-off task completed, scheduling next');
        await _scheduleNext();
      }

      return true;
    } catch (e) {
      print('❌ [WorkManager] Error: $e');
      try {
        await _scheduleNext();
      } catch (_) {}
      return false;
    }
  });
}

Future<void> _scheduleNext() async {
  // Защита от множественного планирования
  final prefs = await SharedPreferences.getInstance();
  final lastSchedule = prefs.getInt(_kLastScheduleKey) ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;

  // Если последнее планирование было менее 1 минуты назад - пропускаем
  if (now - lastSchedule < 5000) {
    print(
      '⚠️ [WorkManager] Skipping schedule - too soon (${(now - lastSchedule) ~/ 1000}s ago)',
    );
    return;
  }

  await prefs.setInt(_kLastScheduleKey, now);

  final uniqueName = 'check_${DateTime.now().millisecondsSinceEpoch}';

  // ВАЖНО: Используем константу для интервала (1 минута)
  const interval = _kQuickCheckInterval;
  print(
    '🔧 [WorkManager] Scheduling with interval: ${interval.inMinutes} min (${interval.inSeconds} sec)',
  );

  await Workmanager().registerOneOffTask(
    uniqueName,
    _kOneOffTaskName,
    initialDelay: interval,
    constraints: Constraints(networkType: NetworkType.connected),
  );
  print(
    '📅 [WorkManager] Next check scheduled for ${interval.inMinutes} min from now',
  );
}

Future<void> _checkNotifications(
  String userId,
  String authToken,
  SharedPreferences prefs,
) async {
  try {
    print('🔍 [WorkManager] Checking for user $userId');

    final shown = prefs.getStringList(_kShownNotificationsKey) ?? [];
    final url =
        '${ApiConfig.baseUrl}/systems/api/controller.php?key=${ApiConfig.apiKey}&route=profile/notifications/getUnread';

    final response = await http
        .post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Authorization': 'Bearer $authToken',
          },
          body: {'id_user': userId, 'token': authToken},
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      print('❌ [WorkManager] API error: ${response.statusCode}');
      print('❌ [WorkManager] API error: ${response.body}');
      return;
    }

    final data = jsonDecode(response.body);
    if (data['status'] != true) return;

    final notifications = data['notifications'] as List<dynamic>;
    print('📬 [WorkManager] Found ${notifications.length} notifications');

    final newShown = <String>[];
    var shownCount = 0;

    for (final notif in notifications) {
      final id = notif['id'] as String;
      if (shown.contains(id)) continue;

      await _showNotification(notif);
      newShown.add(id);
      shownCount++;

      // Небольшая задержка между уведомлениями чтобы не перегружать систему
      if (shownCount < notifications.length) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    final updated = [...shown, ...newShown].take(100).toList();
    await prefs.setStringList(_kShownNotificationsKey, updated);

    print('✅ [WorkManager] Showed $shownCount new notifications');
  } catch (e) {
    print('❌ [WorkManager] Check error: $e');
  }
}

Future<void> _showNotification(Map<String, dynamic> notif) async {
  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  await plugin.show(
    notif['timestamp'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    notif['sender_name'] ?? 'Новое сообщение',
    notif['message'] ?? '',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'chat_messages',
        'Сообщения',
        channelDescription: 'Уведомления о новых сообщениях',
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    payload: jsonEncode({
      'dialog_id': notif['dialog_id'],
      'is_support': notif['is_support'] ?? false,
    }),
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('user');
  await Hive.openBox('favorites');
  await Hive.openBox('subscriptions');
  await Hive.openBox('chats');
  await Hive.openBox('chat_messages');
  await Hive.openBox('settings');

  await Workmanager().initialize(callbackDispatcher, isInDebugMode: true);
  await Workmanager().registerPeriodicTask(
    'notification_periodic_unique',
    _kPeriodicTaskName,
    frequency: const Duration(minutes: 15),
    existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
  );
  await Workmanager().registerOneOffTask(
    'notification_first_check',
    _kOneOffTaskName,
    initialDelay: const Duration(minutes: 1),
    existingWorkPolicy: ExistingWorkPolicy.keep,
    constraints: Constraints(networkType: NetworkType.connected),
  );

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  final deepLinkService = DeepLinkService();
  await deepLinkService.init();

  runApp(MainApp(deepLinkService: deepLinkService));
}

class MainApp extends StatefulWidget {
  final DeepLinkService deepLinkService;
  const MainApp({super.key, required this.deepLinkService});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> {
  bool _showWelcome = true;

  // Все bloc’и, которые нужны и Welcome, и Home, создаются один раз
  late final AuthBloc _authBloc;
  late final CategoriesBloc _categoriesBloc;
  late final StoriesBloc _storiesBloc;
  late final BannerBloc _bannerBloc;
  late final FeedBloc _feedBloc;

  @override
  void initState() {
    super.initState();

    final authService = TestAuthService();
    _authBloc = AuthBloc(
      loginUseCase: LoginUseCase(authService),
      logoutUseCase: LogoutUseCase(authService),
      getCurrentUserUseCase: GetCurrentUserUseCase(authService),
    );

    _categoriesBloc = CategoriesBloc();
    _storiesBloc = StoriesBloc();
    _bannerBloc = BannerBloc();
    final dio = DioClient.createDio();
    final repository = ShopsApiRepository(dio: dio);
    _feedBloc = FeedBloc(
      ShopApiRepository(DioClient.createDio()),
    ); // 👈 ПЕРЕДАЁМ РЕПОЗИТОРИЙ

    // Настройка OAuth deep links на уже созданный authBloc
    widget.deepLinkService.onOAuthSuccess = (token, userId) {
      _authBloc.add(OAuthCallbackReceived(token: token, userId: userId));
    };
    widget.deepLinkService.onOAuthError = (error) {
      _authBloc.add(OAuthCallbackError(error: error));
    };
  }

  @override
  void dispose() {
    _authBloc.close();
    _categoriesBloc.close();
    _storiesBloc.close();
    _bannerBloc.close();
    _feedBloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_showWelcome) {
      // WelcomeScreen получает все необходимые bloc’и (включая auth)
      return MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authBloc),
          BlocProvider.value(value: _categoriesBloc),
          BlocProvider.value(value: _storiesBloc),
          BlocProvider.value(value: _bannerBloc),
          BlocProvider.value(value: _feedBloc),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: WelcomeScreen(
            onComplete: () {
              setState(() => _showWelcome = false);
            },
          ),
        ),
      );
    }

    // Основное приложение – используем те же экземпляры
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LoadingNotifier()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NavigationNotifier()),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: _authBloc),
          BlocProvider.value(value: _categoriesBloc),
          BlocProvider.value(value: _storiesBloc),
          BlocProvider.value(value: _bannerBloc),
          BlocProvider.value(value: _feedBloc),
          BlocProvider<FavoritesBloc>(
            create: (_) => FavoritesBloc(authBloc: _authBloc),
          ),
          BlocProvider<SubscriptionsBloc>(create: (_) => SubscriptionsBloc()),
          BlocProvider<ProfileBloc>(create: (_) => ProfileBloc()),
          BlocProvider<unread.UnreadMessagesBloc>(
            create: (_) => unread.UnreadMessagesBloc(),
          ),
          Provider<ShopApiRepository>(
            create: (_) => ShopApiRepository(DioClient.createDio()),
          ),
          BlocProvider<ChatBloc>(
            create: (context) {
              final unreadBloc = context.read<unread.UnreadMessagesBloc>();
              final bloc = ChatBloc(
                authBloc: _authBloc,
                unreadBloc: unreadBloc,
              );
              Future.microtask(() {
                NotificationService().onMessageReceived = (data) {
                  bloc.add(MessageReceivedFromSocket(data));
                };
              });
              return bloc;
            },
          ),
          BlocProvider<ReviewsBloc>(create: (_) => ReviewsBloc()),
          BlocProvider<BlogBloc>(create: (_) => BlogBloc()),
          BlocProvider<WalletBloc>(create: (_) => WalletBloc()),
          BlocProvider<ShopBloc>(
            create: (_) => ShopBloc(ShopApiRepository(DioClient.createDio())),
          ),
          BlocProvider<ShopPublicBloc>(
            create: (_) =>
                ShopPublicBloc(ShopApiRepository(DioClient.createDio())),
          ),
          BlocProvider<NotificationBloc>(
            create: (_) => NotificationBloc(authBloc: _authBloc),
          ),
        ],
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, child) {
            return NotificationInitializer(
              child: MaterialApp.router(
                routerConfig: router,
                title: 'Хештег',
                themeMode: themeProvider.themeMode,
                localizationsDelegates: const [
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                  FlutterQuillLocalizations.delegate,
                ],
                supportedLocales: const [
                  Locale('ru', 'RU'),
                  Locale('en', 'US'),
                ],
                theme: AppTheme.lightTheme.copyWith(
                  textTheme: GoogleFonts.montserratTextTheme(),
                  platform: TargetPlatform.iOS,
                  pageTransitionsTheme: const PageTransitionsTheme(
                    builders: {
                      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                    },
                  ),
                ),
                darkTheme: AppTheme.darkTheme.copyWith(
                  textTheme: GoogleFonts.montserratTextTheme(
                    ThemeData.dark().textTheme,
                  ),
                  platform: TargetPlatform.iOS,
                  pageTransitionsTheme: const PageTransitionsTheme(
                    builders: {
                      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                    },
                  ),
                ),
                builder: (context, child) {
                  return MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaleFactor: 1.0),
                    child: child!,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
