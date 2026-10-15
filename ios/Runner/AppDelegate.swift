import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    DeviceBridgeRegistrar.shared.register(
      with: engineBridge.applicationRegistrar.messenger()
    )
    ReportBridgeRegistrar.shared.register(
      with: engineBridge.applicationRegistrar.messenger()
    )
  }

  /// APNs 回传的真实设备 token 交给上报通道，由 Dart 侧决定何时上报。
  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    let token = deviceToken.map { String(format: "%02x", $0) }.joined()
    ReportBridgeRegistrar.shared.updatePushToken(token)
  }
}
