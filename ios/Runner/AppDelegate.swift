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
}