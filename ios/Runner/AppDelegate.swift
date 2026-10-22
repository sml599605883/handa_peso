import Flutter
import TDMobRisk
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    let launched = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    if let payload = launchOptions?[.remoteNotification] as? [AnyHashable: Any] {
      ReportBridgeRegistrar.shared.acceptNotificationPayload(payload)
    }
    return launched
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    DeviceBridgeRegistrar.shared.register(
      with: engineBridge.applicationRegistrar.messenger()
    )
    FaceLivenessRegistrar.shared.register(
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

  /// 前台收到带目标地址的通知时直接走 App 内路由，不再重复展示系统横幅。
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let routed = ReportBridgeRegistrar.shared.acceptNotificationPayload(
      notification.request.content.userInfo
    )
    completionHandler(routed ? [] : [.banner, .badge, .sound])
  }

  /// App 已运行或在后台时点击通知。
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    ReportBridgeRegistrar.shared.acceptNotificationPayload(
      response.notification.request.content.userInfo
    )
    completionHandler()
  }
}

/// TrustDecision face liveness entry point.
///
/// The method names and response keys are kept aligned with
/// `lib/core/face/face_liveness_bridge.dart`.
private final class FaceLivenessRegistrar: NSObject {
  static let shared = FaceLivenessRegistrar()

  private static let channelName = "handa_peso/face_bridge"
  private static let partnerCode = "boqin_ph"
  private static let partnerKey = "1dc25522f2adc77f5347816c0f7fa31b"
  private static let livenessSuccessCode = 200
  private lazy var riskManager = TDMobRiskManager.sharedManager()
  private var configured = false

  private override init() {
    super.init()
  }

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "showTrustDecisionLiveness":
        self.start(call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func start(_ arguments: Any?, result: @escaping FlutterResult) {
    DispatchQueue.main.async { [weak self] in
      guard let self else {
        result(Self.failure(message: "Face verification is unavailable."))
        return
      }
      guard
        let license = arguments as? String,
        !license.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      else {
        result(Self.failure(message: "Face verification license is missing."))
        return
      }
      self.configureIfNeeded()
      guard let controller = Self.topViewController() else {
        result(Self.failure(message: "Unable to present face verification."))
        return
      }
      self.riskManager?.pointee.showLivenessWithShowStyle(
        controller,
        license,
        TDLivenessShowStylePresent,
        { payload in result(Self.result(payload)) },
        { payload in result(Self.result(payload)) }
      )
    }
  }

  private func configureIfNeeded() {
    guard !configured else { return }
    configured = true
    riskManager?.pointee.initWithOptions([
      "partner": Self.partnerCode,
      "appKey": Self.partnerKey,
      "country": "sg",
      "language": "en",
      "showReadyPage": false,
      "runningTasks": false,
      "readPhonoe": false,
      "installPackageList": false,
      "playAudio": true
    ])
  }

  private static func result(_ payload: [AnyHashable: Any]?) -> [String: Any] {
    let raw = (payload as? [String: Any]) ?? [:]
    let code: Int
    if let number = raw["code"] as? NSNumber {
      code = number.intValue
    } else if let text = raw["code"] as? String, let parsed = Int(text) {
      code = parsed
    } else {
      code = -1
    }
    let rawData = try? JSONSerialization.data(withJSONObject: raw)
    let rawJson = rawData.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    return [
      "success": code == livenessSuccessCode,
      "code": code,
      "message": raw["message"] as? String ?? "",
      "image": raw["image"] as? String ?? "",
      "liveness_id": raw["liveness_id"] as? String ?? "",
      "request_id": raw["request_id"] as? String ?? "",
      "raw_json": rawJson
    ]
  }

  private static func failure(message: String) -> [String: Any] {
    [
      "success": false,
      "code": -1,
      "message": message,
      "image": "",
      "liveness_id": "",
      "request_id": "",
      "raw_json": "{}"
    ]
  }

  private static func topViewController(
    from controller: UIViewController? = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap(\.windows)
      .first(where: \.isKeyWindow)?
      .rootViewController
  ) -> UIViewController? {
    if let navigation = controller as? UINavigationController {
      return topViewController(from: navigation.visibleViewController)
    }
    if let tab = controller as? UITabBarController {
      return topViewController(from: tab.selectedViewController)
    }
    if let presented = controller?.presentedViewController {
      return topViewController(from: presented)
    }
    return controller
  }
}
