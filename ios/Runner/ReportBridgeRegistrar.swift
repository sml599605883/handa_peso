import AdSupport
import AppTrackingTransparency
import CFNetwork
import CoreLocation
import CoreTelephony
import Darwin
import Flutter
import NetworkExtension
import SystemConfiguration
import SystemConfiguration.CaptiveNetwork
import UIKit
import UserNotifications

/// 数据上报通道：向 Dart 侧提供风控埋点所需的设备事实。
///
/// 通道名 `handa_peso/report_bridge`，与签名用的 `handa_peso/device_bridge`
/// 分开：前者给风控画像（电池、网络、存储、定位），后者只给签名公有
/// 参数，两者的生命周期与失败容忍度不同。
///
/// 取不到的值一律返回空串或 0，绝不用占位数据冒充真实设备信息——服务端拿到
/// 编造的风控画像会造成误判。
final class ReportBridgeRegistrar: NSObject, FlutterStreamHandler, CLLocationManagerDelegate {
  static let shared = ReportBridgeRegistrar()

  private let channelName = "handa_peso/report_bridge"
  private let eventChannelName = "handa_peso/report_events"

  private var eventSink: FlutterEventSink?
  private var pushToken = ""
  private var queuedNotificationTargets: [String] = []
  private var locationManager: CLLocationManager?
  private var locationResult: FlutterResult?
  private var locationPermissionResult: FlutterResult?
  private var reverseGeocoder: CLGeocoder?
  private var isRegistered = false

  private override init() {
    super.init()
  }

  func register(with messenger: FlutterBinaryMessenger) {
    guard !isRegistered else { return }
    isRegistered = true

    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: messenger)
    let events = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
    events.setStreamHandler(self)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "getDeviceSnapshot":
        self.deviceSnapshot { result($0) }
      case "getLocation":
        self.collectLocation(result)
      case "requestLocationPermission":
        self.requestLocationPermission(result)
      case "getPushToken":
        result(self.pushToken)
      case "getTrackingStatus":
        result(self.trackingStatus())
      case "requestNotificationPermission":
        self.requestNotificationPermission(result)
      case "requestTrackingPermission":
        self.requestTrackingPermission(result)
      case "registerForRemoteNotifications":
        DispatchQueue.main.async {
          UIApplication.shared.registerForRemoteNotifications()
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  // MARK: - 原生事件

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    if !pushToken.isEmpty {
      events(["type": "push_token", "token": pushToken])
    }
    while !queuedNotificationTargets.isEmpty {
      let target = queuedNotificationTargets.removeFirst()
      events(["type": "push_route", "url": target])
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }

  /// APNs 回传的真实 token；空 token 不向外发事件，避免 Dart 侧上报空串。
  func updatePushToken(_ token: String) {
    let normalized = token.trimmingCharacters(in: .whitespacesAndNewlines)
    pushToken = normalized
    guard !normalized.isEmpty else { return }
    eventSink?(["type": "push_token", "token": normalized])
  }

  /// 读取通知里的跳转地址；Dart 尚未监听时先缓存，订阅后按顺序补发。
  @discardableResult
  func acceptNotificationPayload(_ payload: [AnyHashable: Any]) -> Bool {
    guard let target = notificationTarget(from: payload) else {
      return false
    }
    if let eventSink {
      eventSink(["type": "push_route", "url": target])
    } else {
      queuedNotificationTargets.append(target)
    }
    return true
  }

  private func notificationTarget(from payload: [AnyHashable: Any]) -> String? {
    if let target = normalizedTarget(payload["url"]) {
      return target
    }
    if let params = payload["params"] as? [AnyHashable: Any] {
      return normalizedTarget(params["url"])
    }
    if
      let params = payload["params"] as? String,
      let data = params.data(using: .utf8),
      let object = try? JSONSerialization.jsonObject(with: data),
      let map = object as? [String: Any]
    {
      return normalizedTarget(map["url"])
    }
    return nil
  }

  private func normalizedTarget(_ value: Any?) -> String? {
    guard let value = value as? String else { return nil }
    let target = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return target.isEmpty ? nil : target
  }

  // MARK: - 授权

  private func requestNotificationPermission(_ result: @escaping FlutterResult) {
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { _, _ in
      // 授权结果不决定 APNs 注册：iOS 只在状态未决时弹窗，注册与 token 上报
      // 由 Dart 侧在授权流程结束后统一发起。
      DispatchQueue.main.async { result(nil) }
    }
  }

  private func requestTrackingPermission(_ result: @escaping FlutterResult) {
    ATTrackingManager.requestTrackingAuthorization { [weak self] status in
      DispatchQueue.main.async {
        self?.eventSink?(["type": "tracking_status_changed", "status": self?.trackingStatus() ?? ""])
        result(nil)
      }
    }
  }

  private func trackingStatus() -> String {
    switch ATTrackingManager.trackingAuthorizationStatus {
    case .authorized: return "authorized"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "not_determined"
    @unknown default: return ""
    }
  }

  // MARK: - 定位

  private func collectLocation(_ result: @escaping FlutterResult) {
    guard CLLocationManager.locationServicesEnabled() else {
      result(["permissionStatus": "service_disabled"])
      return
    }

    let manager = CLLocationManager()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    locationManager = manager
    locationResult = result

    let status = manager.authorizationStatus
    guard status == .authorizedWhenInUse || status == .authorizedAlways else {
      finishLocation(["permissionStatus": statusText(status)])
      return
    }
    manager.requestLocation()
  }

  /// 弹一次系统定位授权弹窗，并在用户做出选择（或权限本就已决定）后返回状态。
  ///
  /// 调用方必须等用户做出真实选择，不能在弹窗一出现就返回 `not_determined`：
  /// 用户点「不允许」时也要把明确结果交回 Dart。
  private func requestLocationPermission(_ result: @escaping FlutterResult) {
    guard CLLocationManager.locationServicesEnabled() else {
      result("service_disabled")
      return
    }

    let manager = CLLocationManager()
    manager.delegate = self
    let status = manager.authorizationStatus
    guard status == .notDetermined else {
      // 弹窗已经弹过（授权或拒绝过）：不再弹，直接给结果。
      result(statusText(status))
      return
    }

    locationManager = manager
    locationPermissionResult = result
    manager.requestWhenInUseAuthorization()
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let coordinate = locations.last?.coordinate else {
      finishLocation(["permissionStatus": "empty"])
      return
    }

    var payload: [String: Any] = [
      "latitude": String(format: "%.6f", coordinate.latitude),
      "longitude": String(format: "%.6f", coordinate.longitude),
      "permissionStatus": "authorized",
    ]

    // 逆地理编码是补充信息：拿不到国家/省市时仍然上报经纬度。
    let geocoder = CLGeocoder()
    reverseGeocoder = geocoder
    geocoder.reverseGeocodeLocation(
      CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    ) { [weak self] placemarks, _ in
      DispatchQueue.main.async {
        if let placemark = placemarks?.first {
          payload["country"] = placemark.country ?? ""
          payload["countryCode"] = placemark.isoCountryCode ?? ""
          payload["province"] = placemark.administrativeArea ?? ""
          payload["city"] = placemark.locality ?? ""
          payload["district"] = placemark.subLocality ?? ""
          payload["street"] = placemark.thoroughfare ?? ""
          // 设备详情要的是完整地址，逐级拼出来比只给街道更贴近文档语义。
          payload["fullAddress"] = [
            placemark.subThoroughfare,
            placemark.thoroughfare,
            placemark.subLocality,
            placemark.locality,
            placemark.administrativeArea,
            placemark.postalCode,
            placemark.country,
          ]
          .compactMap { $0 }
          .filter { !$0.isEmpty }
          .joined(separator: ", ")
        }
        self?.reverseGeocoder = nil
        self?.finishLocation(payload)
      }
    }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    finishLocation(["permissionStatus": "failed"])
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let status = manager.authorizationStatus
    if let permissionResult = locationPermissionResult, status != .notDetermined {
      // 授权弹窗结束：先把结果交回 Dart，再决定要不要继续取一次定位。
      // 同一条委托回调可能同时服务两种请求，因此这里不直接 return。
      locationPermissionResult = nil
      if locationResult == nil { locationManager = nil }
      permissionResult(statusText(status))
    }
    guard locationResult != nil else { return }
    switch status {
    case .authorizedWhenInUse, .authorizedAlways:
      manager.requestLocation()
    case .denied, .restricted:
      finishLocation(["permissionStatus": statusText(status)])
    default:
      // 仍在未决/受限状态：等委托回调，不要提前返回空结果。
      break
    }
  }

  private func finishLocation(_ payload: [String: Any]) {
    guard let result = locationResult else { return }
    locationResult = nil
    locationManager = nil
    result(payload)
  }

  private func statusText(_ status: CLAuthorizationStatus) -> String {
    switch status {
    case .authorizedAlways: return "authorized_always"
    case .authorizedWhenInUse: return "authorized_when_in_use"
    case .denied: return "denied"
    case .restricted: return "restricted"
    case .notDetermined: return "not_determined"
    @unknown default: return ""
    }
  }

  // MARK: - 设备快照

  private func deviceSnapshot(completion: @escaping ([String: Any]) -> Void) {
    // SSID/BSSID 在 iOS 上只能异步取（`NEHotspotNetwork` 是回调式），因此整份
    // 快照改成回调式：Dart 侧的方法调用结果等 Wi-Fi 结果回来再回传。
    currentWifi { [weak self] wifi in
      guard let self else {
        completion([:])
        return
      }
      completion(self.buildSnapshot(wifi: wifi))
    }
  }

  private func buildSnapshot(
    wifi: (ssid: String, bssid: String, count: Int)
  ) -> [String: Any] {
    UIDevice.current.isBatteryMonitoringEnabled = true
    let screen = UIScreen.main
    let bounds = screen.bounds
    let network = networkInfo()
    let memory = memoryStats()
    let storage = storageStats()
    let interfaces = ipv4Interfaces()

    return [
      "idfv": DeviceBridgeRegistrar.shared.stableVendorIdentifier(),
      "advertisingId": advertisingIdentifier(),
      "riskDeviceId": "",
      "macAddress": "",
      "systemVersion": UIDevice.current.systemVersion,
      "packageName": Bundle.main.bundleIdentifier ?? "",
      "batteryLevel": batteryLevel(),
      "isCharging": batteryCharging(),
      "innerIp": interfaces.first { $0.0 == "en0" }?.1 ?? interfaces.first?.1 ?? "",
      "wifiName": wifi.ssid,
      "wifiBssid": wifi.bssid,
      "wifiCount": wifi.count,
      "isUsingProxy": isUsingProxy() ? 1 : 0,
      "isUsingVpn": isUsingVpn(interfaces: interfaces) ? 1 : 0,
      "isJailbroken": isJailbroken() ? 1 : 0,
      "isEmulator": isEmulator() ? 1 : 0,
      "language": Locale.preferredLanguages.first ?? "",
      "carrier": carrierName(),
      "networkType": network,
      "timeZoneId": TimeZone.current.identifier,
      "uptimeMillis": uptimeMillis(),
      "bootMillis": bootMillis(),
      "cpuCoreCount": ProcessInfo.processInfo.processorCount,
      "board": boardModel(),
      "brand": UIDevice.current.model,
      "deviceName": UIDevice.current.name,
      "model": hardwareModel(),
      "screenHeight": Int(bounds.height.rounded()),
      "screenWidth": Int(bounds.width.rounded()),
      "physicalSize": physicalSize(bounds: bounds, scale: screen.scale),
      "availableStorage": "\(storage.available)",
      "totalStorage": "\(storage.total)",
      "totalMemory": "\(memory.total)",
      "availableMemory": "\(memory.available)",
    ]
  }

  private func batteryLevel() -> Int {
    let level = UIDevice.current.batteryLevel
    guard level >= 0 else { return 0 }
    return Int((level * 100).rounded())
  }

  private func batteryCharging() -> Int {
    switch UIDevice.current.batteryState {
    case .charging, .full: return 1
    default: return 0
    }
  }

  /// IDFA 只在用户明确授权跟踪后才有意义；其余情况返回空串。
  private func advertisingIdentifier() -> String {
    guard ATTrackingManager.trackingAuthorizationStatus == .authorized else { return "" }
    let identifier = ASIdentifierManager.shared().advertisingIdentifier.uuidString
    return identifier.isEmpty || identifier == "00000000-0000-0000-0000-000000000000"
      ? ""
      : identifier
  }

  /// 形如 `iPhone15,2` 的硬件标识；`uname` 不可用时退回设备类别。
  private func hardwareModel() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    let identifier = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(validatingUTF8: $0) ?? ""
      }
    }
    return identifier.isEmpty ? UIDevice.current.model : identifier
  }

  /// 主板标识，对应文档里的 `capitulating`（Android 的 Build.BOARD）。
  ///
  /// iOS 上最接近的是 `hw.model`（如 D79AP）；`hw.machine` 已经作为设备型号上报，
  /// 两者不重复取同一个值。
  private func boardModel() -> String {
    var size = 0
    guard sysctlbyname("hw.model", nil, &size, nil, 0) == 0, size > 0 else { return "" }
    var buffer = [CChar](repeating: 0, count: size)
    guard sysctlbyname("hw.model", &buffer, &size, nil, 0) == 0 else { return "" }
    return String(cString: buffer)
  }

  private func uptimeMillis() -> Int {
    Int((ProcessInfo.processInfo.systemUptime * 1000).rounded())
  }

  private func bootMillis() -> Int {
    Int(Date().timeIntervalSince1970 * 1000) - uptimeMillis()
  }

  private func physicalSize(bounds: CGRect, scale: CGFloat) -> String {
    let diagonalPoints = (bounds.width * bounds.width + bounds.height * bounds.height).squareRoot()
    guard diagonalPoints > 0 else { return "" }
    // 163 ppi 是 iPhone 系列的常见像素密度，换算出来的对角线英寸与机型标称值接近。
    return String(format: "%.1f", diagonalPoints * scale / 163.0)
  }

  /// 当前 Wi-Fi 的 SSID / BSSID，以及当前连着的网络数（对应接口文档 `mannose`）。
  ///
  /// iOS 13 起系统要求同时满足三条才会返回热点信息，缺任何一条都只能拿到 nil：
  /// 1. App 具备 `com.apple.developer.networking.wifi-info` 能力（见
  ///    `Runner.entitlements`，且描述文件里也要打开 Access Wi-Fi Information）；
  /// 2. 用户已授予「使用 App 期间」定位权限；
  /// 3. 设备确实连着 Wi-Fi（模拟器永远拿不到）。
  ///
  /// 这里先用 `CNCopyCurrentNetworkInfo`；iOS 14 起再用
  /// `NEHotspotNetwork.fetchCurrent` 兜底——参考端 Salmon Loan 在 iOS 26 上
  /// 就是直接走这个接口，说明 CNCopy 系列在新系统上已经不可靠。
  private func currentWifi(
    completion: @escaping ((ssid: String, bssid: String, count: Int)) -> Void
  ) {
    let legacy = legacyWifi()
    guard legacy.ssid.isEmpty && legacy.bssid.isEmpty else {
      completion(legacy)
      return
    }
    guard #available(iOS 14.0, *) else {
      completion(legacy)
      return
    }

    // 回调和超时都落在主队列，`finished` 只可能被主队列读写；
    // fetchCurrent 在系统内部异常时不保证一定回调，超时就按“取不到”返回，
    // 不能让 Dart 侧一直等这份快照。
    var finished = false
    let finish: ((ssid: String, bssid: String, count: Int)) -> Void = { wifi in
      guard !finished else { return }
      finished = true
      completion(wifi)
    }

    NEHotspotNetwork.fetchCurrent { network in
      let ssid = network?.ssid ?? ""
      let bssid = network?.bssid ?? ""
      DispatchQueue.main.async {
        finish((ssid, bssid, ssid.isEmpty && bssid.isEmpty ? 0 : 1))
      }
    }
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
      finish(legacy)
    }
  }

  /// 老接口：仅 iOS 13+ 且能力、定位权限都具备时才拿得到值。
  private func legacyWifi() -> (ssid: String, bssid: String, count: Int) {
    guard let interfaces = CNCopySupportedInterfaces() as? [String] else {
      return ("", "", 0)
    }
    for name in interfaces {
      guard let info = CNCopyCurrentNetworkInfo(name as CFString) as? [String: Any] else {
        continue
      }
      let ssid = info[kCNNetworkInfoKeySSID as String] as? String ?? ""
      let bssid = info[kCNNetworkInfoKeyBSSID as String] as? String ?? ""
      if !ssid.isEmpty || !bssid.isEmpty {
        return (ssid, bssid, 1)
      }
    }
    // 能力/定位权限缺失，或当前没连 Wi-Fi：如实留空，不用占位数据。
    return ("", "", 0)
  }

  private func ipv4Interfaces() -> [(String, String)] {
    var results: [(String, String)] = []
    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return results }
    defer { freeifaddrs(ifaddr) }

    var pointer: UnsafeMutablePointer<ifaddrs>? = first
    while let current = pointer {
      let interface = current.pointee
      if let address = interface.ifa_addr, address.pointee.sa_family == UInt8(AF_INET) {
        var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let length = socklen_t(address.pointee.sa_len)
        if getnameinfo(address, length, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
          results.append((String(cString: interface.ifa_name), String(cString: host)))
        }
      }
      pointer = interface.ifa_next
    }
    return results
  }

  private func isUsingVpn(interfaces: [(String, String)]) -> Bool {
    let tunnelPrefixes = ["utun", "tap", "tun", "ppp", "ipsec"]
    return interfaces.contains { entry in
      tunnelPrefixes.contains { entry.0.hasPrefix($0) }
    }
  }

  private func isUsingProxy() -> Bool {
    guard
      let settings = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any]
    else { return false }

    // iOS 只暴露 HTTP 代理与自动代理配置两组键；HTTPS/SOCKS 那两套键在
    // iOS 上不可用，写了也编译不过。
    let enabledKeys = [
      (kCFNetworkProxiesHTTPEnable as String, kCFNetworkProxiesHTTPProxy as String),
      (kCFNetworkProxiesProxyAutoConfigEnable as String, kCFNetworkProxiesProxyAutoConfigURLString as String),
    ]
    return enabledKeys.contains { enableKey, valueKey in
      let enabled = (settings[enableKey] as? NSNumber)?.boolValue ?? false
      let value = settings[valueKey] as? String ?? ""
      return enabled && !value.isEmpty
    }
  }

  private func isJailbroken() -> Bool {
    let paths = [
      "/Applications/Cydia.app",
      "/Library/MobileSubstrate/MobileSubstrate.dylib",
      "/bin/bash",
      "/usr/sbin/sshd",
      "/etc/apt",
      "/private/var/lib/apt/",
    ]
    if paths.contains(where: { FileManager.default.fileExists(atPath: $0) }) {
      return true
    }
    if let url = URL(string: "cydia://package/com.example.package"),
       UIApplication.shared.canOpenURL(url) {
      return true
    }
    return false
  }

  private func isEmulator() -> Bool {
    #if targetEnvironment(simulator)
    return true
    #else
    return false
    #endif
  }

  private func carrierName() -> String {
    let info = CTTelephonyNetworkInfo()
    let providers = info.serviceSubscriberCellularProviders ?? [:]
    for provider in providers.values {
      let name = provider.carrierName?.trimmingCharacters(in: .whitespaces) ?? ""
      if !name.isEmpty { return name }
    }
    return ""
  }

  /// 网络类型按接口文档的取值上报：2G / 3G / 4G / 5G / WIFI / OTHER。
  private func networkInfo() -> String {
    if isReachableViaWifi() { return "WIFI" }
    let info = CTTelephonyNetworkInfo()
    guard let technology = info.serviceCurrentRadioAccessTechnology?.values.first else {
      return "OTHER"
    }
    switch technology {
    case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge,
         CTRadioAccessTechnologyCDMA1x:
      return "2G"
    case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA,
         CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyCDMAEVDORev0,
         CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB,
         CTRadioAccessTechnologyeHRPD:
      return "3G"
    case CTRadioAccessTechnologyLTE:
      return "4G"
    default:
      if #available(iOS 14.1, *),
         technology == CTRadioAccessTechnologyNR || technology == CTRadioAccessTechnologyNRNSA {
        return "5G"
      }
      return "OTHER"
    }
  }

  private func isReachableViaWifi() -> Bool {
    var address = sockaddr_in()
    address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
    address.sin_family = sa_family_t(AF_INET)
    guard let reachability = withUnsafePointer(to: &address, { pointer in
      pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) {
        SCNetworkReachabilityCreateWithAddress(nil, $0)
      }
    }) else { return false }

    var flags = SCNetworkReachabilityFlags()
    guard SCNetworkReachabilityGetFlags(reachability, &flags) else { return false }
    return flags.contains(.reachable) && !flags.contains(.isWWAN)
  }

  private func memoryStats() -> (total: UInt64, available: UInt64) {
    let total = ProcessInfo.processInfo.physicalMemory
    var stats = vm_statistics64()
    var count = mach_msg_type_number_t(
      MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
    )
    let result = withUnsafeMutablePointer(to: &stats) { pointer in
      pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
        host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
      }
    }
    guard result == KERN_SUCCESS else { return (total, 0) }
    let pageSize = UInt64(getpagesize())
    let free = UInt64(stats.free_count + stats.inactive_count + stats.speculative_count)
    return (total, free * pageSize)
  }

  private func storageStats() -> (total: UInt64, available: UInt64) {
    let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
    let total = (attributes?[.systemSize] as? NSNumber)?.uint64Value ?? 0
    let available = (attributes?[.systemFreeSize] as? NSNumber)?.uint64Value ?? 0
    return (total, available)
  }
}
