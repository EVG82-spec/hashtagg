import Flutter
import UIKit
import UserNotifications
import YandexMapsMobile

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  
  var apnsTokenChannel: FlutterMethodChannel?
  var pendingApnsToken: String?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

      // 👇 СБРОС BADGE ПРИ СТАРТЕ
      if #available(iOS 16.0, *) {
          UNUserNotificationCenter.current().setBadgeCount(0) { error in
              if let error = error {
                  print("❌ [Badge] Reset error: \(error)")
              } else {
                  print("✅ [Badge] Reset to 0")
              }
          }
      } else {
          UIApplication.shared.applicationIconBadgeNumber = 0
          print("✅ [Badge] Reset to 0 (legacy)")
      }

      YMKMapKit.setApiKey("4aab5e00-30ab-4a8a-b428-63d00203f440")
      YMKMapKit.sharedInstance()

      if #available(iOS 10.0, *) {
          UNUserNotificationCenter.current().delegate = self
          let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
      UNUserNotificationCenter.current().requestAuthorization(
        options: authOptions,
        completionHandler: { _, _ in }
      )
    } else {
      let settings: UIUserNotificationSettings =
        UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
      application.registerUserNotificationSettings(settings)
    }
    
    application.registerForRemoteNotifications()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    
    // ✅ Правильный способ получить messenger в Flutter 3.47+
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "ApnsTokenPlugin") {
      print("✅ [APNs] Registrar получен")
      
      self.apnsTokenChannel = FlutterMethodChannel(
        name: "apns_token",
        binaryMessenger: registrar.messenger()
      )
      
      // Если токен уже получен — отправляем
      if let token = self.pendingApnsToken {
        print("📤 [APNs] Отправляем накопленный токен: \(token)")
        self.apnsTokenChannel?.invokeMethod("onToken", arguments: token)
      } else {
        print("⏳ [APNs] Токен ещё не получен")
      }
    } else {
      print("❌ [APNs] Registrar не получен")
    }
  }
  
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
    let token = tokenParts.joined()
    print("📱 APNs Token: \(token)")
    
    pendingApnsToken = token
    
    if let channel = apnsTokenChannel {
      print("📤 [APNs] Отправляем токен (канал готов)")
      channel.invokeMethod("onToken", arguments: token)
    } else {
      print("⏳ [APNs] Канал не готов, сохраняем токен")
    }
  }
  
  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("❌ APNs registration failed: \(error.localizedDescription)")
  }

    // ✅ Юзер тапнул по пушу (приложение было в фоне / закрыто)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo
    print("🔔 [Push] Тап по уведомлению: \(userInfo)")

    // Извлекаем data
    if let data = userInfo["data"] as? [String: Any] {
      print("🔔 [Push] data: \(data)")

      // Отправляем во Flutter через MethodChannel
      if let channel = self.apnsTokenChannel {
        channel.invokeMethod("onNotificationTap", arguments: data)
      }
    }

    completionHandler()
  }

  // ✅ Пуш пришёл, когда приложение ОТКРЫТО (на переднем плане)
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo
    print("🔔 [Push] Пришёл на переднем плане: \(userInfo)")

    // Показываем баннер, звук, badge
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge, .list])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }
}