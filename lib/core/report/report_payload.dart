import 'dart:convert';

import 'report_models.dart';

/// 上报请求体的组装。
///
/// 字段名一律取接口文档里登记的不透明键名；这里的常量是**协议契约**，
/// 改动前必须回查 MyTools 的 `ph_handa_peso_ios` 文档，不能按字面猜语义。
abstract final class ReportPayload {
  // --- 上报位置信息 /dropcloth/farle -----------------------------------------
  static const _province = 'sardonic';
  static const _countryCode = 'psychrometry';
  static const _country = 'eyehole';
  static const _street = 'widemouthed';
  static const _latitude = 'carnets';
  static const _longitude = 'polyembryonies';
  static const _city = 'marbleizes';
  static const _district = 'unoccupied';

  // --- 上报风控埋点(新) /dropcloth/disgruntle ---------------------------------
  static const _productId = 'knife';
  static const _sceneType = 'proves';
  static const _orderNo = 'redecorates';
  static const _riskDeviceId = 'apicultures';
  static const _advertisingId = 'decayer';
  static const _startTime = 'sparkler';
  static const _endTime = 'spectacled';

  // --- 设备信息上报 /dropcloth/unglove（整体加密后放进信封锁载荷字段）---------
  static const _systemVersion = 'litigiousness';
  static const _lastLoginAt = 'scribbling';
  static const _packageName = 'tamarinds';
  static const _battery = 'squares';
  static const _batteryLevel = 'purselike';
  static const _charging = 'merganser';
  static const _gps = 'shrouded';
  // gps_info 与定位接口用的是两组不同的键：这里不能用 carnets / polyembryonies /
  // widemouthed，那些只属于 `/dropcloth/farle`。
  static const _gpsLongitude = 'apteria';
  static const _gpsLatitude = 'parasiticidal';
  static const _gpsAddress = 'blackthorns';
  static const _gpsArea = 'gadgeteers';
  static const _device = 'ruddling';
  static const _deviceIdfv = 'tunesmith';
  static const _deviceAdvertisingId = 'colickiest';
  static const _deviceMac = 'issei';
  static const _nowMillis = 'marathoners';
  static const _uptimeMillis = 'effloresced';
  static const _usingProxy = 'amylopsin';
  static const _usingVpn = 'cygnet';
  static const _jailbroken = 'unsated';
  static const _emulator = 'outflowing';
  static const _language = 'shrimper';
  static const _carrier = 'propitiators';
  static const _networkType = 'counterblockade';
  static const _sensors = 'overhard';
  static const _timeZone = 'roister';
  static const _bootMillis = 'disrelished';
  static const _hardware = 'interterm';
  static const _hardwareBoard = 'capitulating';
  static const _brand = 'leucocytes';
  static const _cpuCores = 'vanguards';
  static const _screenHeight = 'scrimshanders';
  static const _deviceName = 'buncombes';
  static const _screenWidth = 'passionflowers';
  static const _model = 'duckie';
  static const _physicalSize = 'transudates';
  static const _hardwareSystemVersion = 'sonications';
  static const _network = 'colossus';
  static const _innerIp = 'correspondence';
  static const _interfaces = 'vesper';
  static const _interfaceName = 'definitively';
  static const _interfaceAddress = 'tagmemes';
  static const _interfaceMac = 'issei';
  static const _interfaceSsid = 'actinoids';
  static const _currentWifi = 'stomped';
  static const _wifiCount = 'mannose';
  static const _storage = 'biogenetically';
  static const _storageFree = 'guardhouses';
  static const _storageTotal = 'wobblinesses';
  static const _memoryTotal = 'overwarms';
  static const _memoryFree = 'ineffabilities';

  /// 位置上报的请求体；文档把经纬度列为必填，缺失时由调用方跳过整次上报。
  static Map<String, dynamic> locationBody(ReportLocation location) =>
      <String, dynamic>{
        _province: location.province,
        _countryCode: location.countryCode,
        _country: location.country,
        _street: location.street,
        _latitude: location.latitude,
        _longitude: location.longitude,
        _city: location.city,
      };

  /// 风控埋点的请求体；时间戳按文档示例以秒为单位。
  static Map<String, dynamic> riskBody({
    required String productId,
    required String sceneType,
    required String startTimeSeconds,
    required String endTimeSeconds,
    String orderNo = '',
    String riskDeviceId = '',
    String advertisingId = '',
    ReportLocation? location,
  }) => <String, dynamic>{
    _productId: productId,
    _sceneType: sceneType,
    _orderNo: orderNo,
    _riskDeviceId: riskDeviceId,
    _advertisingId: advertisingId,
    _longitude: location?.longitude ?? '',
    _latitude: location?.latitude ?? '',
    _startTime: startTimeSeconds,
    _endTime: endTimeSeconds,
  };

  /// 设备详情明文（调用方加密后再发送）。
  static String deviceJson({
    required DeviceSnapshot snapshot,
    required ReportLocation? location,
    required int lastLoginAtMillis,
    required int nowMillis,
  }) {
    final payload = <String, Object?>{
      _systemVersion: snapshot.systemVersion,
      _lastLoginAt: lastLoginAtMillis,
      _packageName: snapshot.packageName,
      _battery: <String, Object?>{
        _batteryLevel: snapshot.batteryLevel,
        _charging: snapshot.isCharging,
      },
      _gps: <String, Object?>{
        _gpsLongitude: location?.longitude ?? '',
        _gpsLatitude: location?.latitude ?? '',
        _gpsAddress: location?.fullAddress ?? '',
        _gpsArea: <String, Object?>{
          _country: location?.country ?? '',
          _countryCode: location?.countryCode ?? '',
          _province: location?.province ?? '',
          _city: location?.city ?? '',
          _district: location?.district ?? '',
          _street: location?.street ?? '',
        },
      },
      _device: <String, Object?>{
        _deviceIdfv: snapshot.idfv,
        _deviceAdvertisingId: snapshot.advertisingId,
        _deviceMac: snapshot.macAddress,
        _nowMillis: nowMillis,
        _uptimeMillis: snapshot.uptimeMillis,
        _usingProxy: snapshot.isUsingProxy,
        _usingVpn: snapshot.isUsingVpn,
        _jailbroken: snapshot.isJailbroken,
        _emulator: snapshot.isEmulator,
        _language: snapshot.language,
        _carrier: snapshot.carrier,
        _networkType: snapshot.networkType,
        // 传感器清单：本端没有采集能力时按空数组上报，不用占位数据冒充。
        _sensors: const <Object?>[],
        _timeZone: snapshot.timeZoneId,
        _bootMillis: snapshot.bootMillis,
      },
      _hardware: <String, Object?>{
        _hardwareBoard: snapshot.board,
        _brand: snapshot.brand,
        _cpuCores: snapshot.cpuCoreCount,
        _screenHeight: snapshot.screenHeight,
        _deviceName: snapshot.deviceName,
        _screenWidth: snapshot.screenWidth,
        _model: snapshot.model,
        _physicalSize: snapshot.physicalSize,
        _hardwareSystemVersion: snapshot.systemVersion,
      },
      _network: <String, Object?>{
        _innerIp: snapshot.innerIp,
        _interfaces: <Object?>[
          if (snapshot.wifiBssid.isNotEmpty || snapshot.wifiName.isNotEmpty)
            <String, Object?>{
              _interfaceName: snapshot.wifiName,
              _interfaceAddress: snapshot.wifiBssid,
              _interfaceMac: snapshot.macAddress,
              _interfaceSsid: snapshot.wifiName,
            },
        ],
        _currentWifi: <String, Object?>{
          _interfaceName: snapshot.wifiName,
          _interfaceAddress: snapshot.wifiBssid,
          _interfaceMac: snapshot.macAddress,
          _interfaceSsid: snapshot.wifiName,
        },
        _wifiCount: snapshot.wifiCount,
      },
      _storage: <String, Object?>{
        _storageFree: snapshot.availableStorage,
        _storageTotal: snapshot.totalStorage,
        _memoryTotal: snapshot.totalMemory,
        _memoryFree: snapshot.availableMemory,
      },
    };
    return jsonEncode(payload);
  }
}
