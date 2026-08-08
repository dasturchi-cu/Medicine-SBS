import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class DeviceId {
  static Future<String> getStableDeviceId() async {
    final plugin = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final info = await plugin.androidInfo;
      return info.id; // build id (stable enough for mock)
    }
    if (Platform.isIOS) {
      final info = await plugin.iosInfo;
      return info.identifierForVendor ?? 'ios_unknown';
    }
    if (Platform.isWindows) {
      final info = await plugin.windowsInfo;
      return info.deviceId;
    }
    if (Platform.isMacOS) {
      final info = await plugin.macOsInfo;
      return info.systemGUID ?? 'mac_unknown';
    }
    if (Platform.isLinux) {
      final info = await plugin.linuxInfo;
      return info.machineId ?? 'linux_unknown';
    }
    return 'unknown_device';
  }
}

