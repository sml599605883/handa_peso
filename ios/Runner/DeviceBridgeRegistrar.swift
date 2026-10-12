import Flutter
import Security
import UIKit

/// 原生桥接，向网关的签名公有参数暴露设备身份信息。
///
/// Dart 层通过 `handa_peso/device_bridge` 调用 `getPlatformInfo`；返回硬件型号、
/// 系统版本、bundle 版本以及 Keychain 稳定的 IDFV，
/// 从而可用重装后依然保留的数据来签名请求。
final class DeviceBridgeRegistrar: NSObject {
  static let shared = DeviceBridgeRegistrar()

  private let channelName = "handa_peso/device_bridge"
  private let keychainService = "handa_peso.device_bridge"
  private let keychainAccount = "stable_idfv"

  private override init() {
    super.init()
  }

  func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }

      switch call.method {
      case "getPlatformInfo":
        let info = Bundle.main.infoDictionary
        result([
          "platform": self.deviceModelIdentifier(),
          "systemVersion": UIDevice.current.systemVersion,
          "appVersion": info?["CFBundleShortVersionString"] as? String ?? "",
          "buildNumber": info?["CFBundleVersion"] as? String ?? "",
          "deviceId": self.stableVendorIdentifier(),
        ])
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// 形如 `iPhone15,2` 的硬件标识；当 `uname` 不可用时，
  /// 回退为通用的设备型号。
  private func deviceModelIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let identifier = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(validatingUTF8: $0) ?? ""
      }
    }
    return identifier.isEmpty ? UIDevice.current.model : identifier
  }

  /// 缓存在 Keychain 中的 IDFV，使标识在重装应用后依然保留，
  /// 从而让同一设备的签名公有参数保持稳定。
  private func stableVendorIdentifier() -> String {
    if let stored = keychainValue(service: keychainService, account: keychainAccount),
       !stored.isEmpty {
      return stored
    }

    let identifier = UIDevice.current.identifierForVendor?.uuidString ?? ""
    if !identifier.isEmpty {
      saveKeychainValue(identifier, service: keychainService, account: keychainAccount)
    }
    return identifier
  }

  private func keychainValue(service: String, account: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    guard status == errSecSuccess, let data = result as? Data else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  private func saveKeychainValue(_ value: String, service: String, account: String) {
    let data = Data(value.utf8)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: account,
    ]
    let attributes: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]

    let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    if status == errSecItemNotFound {
      var item = query
      item[kSecValueData as String] = data
      item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
      SecItemAdd(item as CFDictionary, nil)
    }
  }
}
