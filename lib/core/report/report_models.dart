/// 上报载荷里所有字段都按字符串发送，缺失值统一收敛成空串。
///
/// 原生层回传的是 plist 可序列化类型（`nil` / `NSNumber` / `String` 混用），
/// 因此读取时先归一化，业务代码不必到处判空。
String reportText(Object? value, [String fallback = '']) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty || text == 'null') return fallback;
  return text;
}

int reportInt(Object? value, [int fallback = 0]) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is bool) return value ? 1 : 0;
  return int.tryParse(reportText(value)) ?? fallback;
}

/// 一次定位快照。
///
/// 经纬度是必填项：接口文档把它们列为必填，缺任意一项时整段上报都该跳过，
/// 所以 [isValid] 只看向这两项。
class ReportLocation {
  const ReportLocation({
    this.province = '',
    this.countryCode = '',
    this.country = '',
    this.street = '',
    this.latitude = '',
    this.longitude = '',
    this.city = '',
    this.district = '',
    this.fullAddress = '',
    this.permissionStatus = '',
  });

  factory ReportLocation.fromMap(Map<Object?, Object?> raw) => ReportLocation(
    province: reportText(raw['province'] ?? raw['sardonic']),
    countryCode: reportText(raw['countryCode'] ?? raw['psychrometry']),
    country: reportText(raw['country'] ?? raw['eyehole']),
    street: reportText(raw['street'] ?? raw['widemouthed']),
    latitude: reportText(raw['latitude'] ?? raw['carnets']),
    longitude: reportText(raw['longitude'] ?? raw['polyembryonies']),
    city: reportText(raw['city'] ?? raw['marbleizes']),
    district: reportText(raw['district'] ?? raw['unoccupied']),
    fullAddress: reportText(raw['fullAddress'] ?? raw['blackthorns']),
    permissionStatus: reportText(raw['permissionStatus']),
  );

  final String province;
  final String countryCode;
  final String country;
  final String street;
  final String latitude;
  final String longitude;
  final String city;

  /// 区/县；接口文档的 `unoccupied`，iOS 侧一般拿不到，允许为空。
  final String district;

  /// 反地理编码得到的完整地址；设备详情里的 `blackthorns` 用它，而不是自己拼。
  final String fullAddress;

  /// 原生系统授权的原始状态，仅用于排查，不进请求体。
  final String permissionStatus;

  bool get isValid => latitude.isNotEmpty && longitude.isNotEmpty;

  /// `/dropcloth/farle` 的 `widemouthed`（字段映射里的 `feature_name`）。
  ///
  /// 原生侧这一项取的是 `placemark.thoroughfare`，空旷地带/园区坐标经常为空，
  /// 而同一份 placemark 拼出来的 [fullAddress] 几乎总有值；文档把该字段标成
  /// 必填，所以街道缺失时用完整地址兜底，避免把空串发上去。
  String get streetLabel => street.isNotEmpty ? street : fullAddress;

  /// 定位上报（`/dropcloth/farle`）的必填项是否齐全。
  ///
  /// 文档里必填的是 `psychrometry`（国家 code）、`eyehole`（国家）、
  /// `widemouthed`（街道）、`carnets`（纬度）、`polyembryonies`（经度）、
  /// `marbleizes`（市）；`sardonic`（省）可选。CLGeocoder 反地理编码失败时
  /// 原生只能给出经纬度，此时不能把其余必填项以空串上报。
  bool get hasCompleteAddress =>
      isValid &&
      countryCode.isNotEmpty &&
      country.isNotEmpty &&
      city.isNotEmpty &&
      streetLabel.isNotEmpty;
}

/// 设备快照：上报所需的全部本机事实。
///
/// 字段与接口文档「设备信息上报详细信息」逐项对应；取不到的值保持空串/0，
/// 绝不用编造的数据填充，否则服务端拿到的风控画像就是错的。
class DeviceSnapshot {
  const DeviceSnapshot({
    this.idfv = '',
    this.advertisingId = '',
    this.riskDeviceId = '',
    this.macAddress = '',
    this.systemVersion = '',
    this.packageName = '',
    this.batteryLevel = 0,
    this.isCharging = 0,
    this.innerIp = '',
    this.wifiName = '',
    this.wifiBssid = '',
    this.wifiCount = 0,
    this.isUsingProxy = 0,
    this.isUsingVpn = 0,
    this.isJailbroken = 0,
    this.isEmulator = 0,
    this.language = '',
    this.carrier = '',
    this.networkType = '',
    this.timeZoneId = '',
    this.uptimeMillis = 0,
    this.bootMillis = 0,
    this.cpuCoreCount = 0,
    this.board = '',
    this.brand = '',
    this.deviceName = '',
    this.model = '',
    this.screenHeight = 0,
    this.screenWidth = 0,
    this.physicalSize = '',
    this.availableStorage = '',
    this.totalStorage = '',
    this.totalMemory = '',
    this.availableMemory = '',
  });

  factory DeviceSnapshot.fromMap(Map<Object?, Object?> raw) => DeviceSnapshot(
    idfv: reportText(raw['idfv']),
    advertisingId: reportText(raw['advertisingId']),
    riskDeviceId: reportText(raw['riskDeviceId']),
    macAddress: reportText(raw['macAddress']),
    systemVersion: reportText(raw['systemVersion']),
    packageName: reportText(raw['packageName']),
    batteryLevel: reportInt(raw['batteryLevel']),
    isCharging: reportInt(raw['isCharging']),
    innerIp: reportText(raw['innerIp']),
    wifiName: reportText(raw['wifiName']),
    wifiBssid: reportText(raw['wifiBssid']),
    wifiCount: reportInt(raw['wifiCount']),
    isUsingProxy: reportInt(raw['isUsingProxy']),
    isUsingVpn: reportInt(raw['isUsingVpn']),
    isJailbroken: reportInt(raw['isJailbroken']),
    isEmulator: reportInt(raw['isEmulator']),
    language: reportText(raw['language']),
    carrier: reportText(raw['carrier']),
    networkType: reportText(raw['networkType']),
    timeZoneId: reportText(raw['timeZoneId']),
    uptimeMillis: reportInt(raw['uptimeMillis']),
    bootMillis: reportInt(raw['bootMillis']),
    cpuCoreCount: reportInt(raw['cpuCoreCount']),
    board: reportText(raw['board']),
    brand: reportText(raw['brand']),
    deviceName: reportText(raw['deviceName']),
    model: reportText(raw['model']),
    screenHeight: reportInt(raw['screenHeight']),
    screenWidth: reportInt(raw['screenWidth']),
    physicalSize: reportText(raw['physicalSize']),
    availableStorage: reportText(raw['availableStorage']),
    totalStorage: reportText(raw['totalStorage']),
    totalMemory: reportText(raw['totalMemory']),
    availableMemory: reportText(raw['availableMemory']),
  );

  /// Keychain 稳定的 IDFV，同时也是签名公有参数的设备标识。
  final String idfv;

  /// 广告标识 IDFA；用户未授权跟踪时为空串。
  final String advertisingId;

  /// 风控 SDK 生成的新设备号（本端暂无第三方风控 SDK 时为空串）。
  final String riskDeviceId;
  final String macAddress;

  /// 主板标识（接口文档的 `capitulating`）；iOS 取 `hw.model`。
  final String board;
  final String systemVersion;
  final String packageName;
  final int batteryLevel;
  final int isCharging;
  final String innerIp;
  final String wifiName;
  final String wifiBssid;
  final int wifiCount;
  final int isUsingProxy;
  final int isUsingVpn;
  final int isJailbroken;
  final int isEmulator;
  final String language;
  final String carrier;
  final String networkType;
  final String timeZoneId;
  final int uptimeMillis;
  final int bootMillis;
  final int cpuCoreCount;
  final String brand;
  final String deviceName;
  final String model;
  final int screenHeight;
  final int screenWidth;
  final String physicalSize;
  final String availableStorage;
  final String totalStorage;
  final String totalMemory;
  final String availableMemory;
}
