import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    application.registerForRemoteNotifications()
    
    let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    
    // Set up MethodChannel to clear notification badge and delivered tray alerts natively
    if let controller = window?.rootViewController as? FlutterViewController {
      let badgeChannel = FlutterMethodChannel(
        name: "com.nexacode.miriverbs/badge",
        binaryMessenger: controller.binaryMessenger
      )
      badgeChannel.setMethodCallHandler { (call, result) in
        if call.method == "clearBadge" {
          if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
              if let error = error {
                print("DEBUG: Error setting badge count: \(error)")
              }
            }
          } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
          }
          UNUserNotificationCenter.current().removeAllDeliveredNotifications()
          result(true)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
    
    return result
  }
}

