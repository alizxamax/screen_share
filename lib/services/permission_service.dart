import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestBroadcastPermissions() async {
    if (Platform.isAndroid) {
      final statuses = await [
        Permission.microphone,
        Permission.notification,
      ].request();
      return statuses.values.every((status) => status.isGranted || status.isLimited);
    }

    if (Platform.isIOS) {
      final status = await Permission.microphone.request();
      return status.isGranted || status.isLimited;
    }

    return true;
  }
}
