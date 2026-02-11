import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<bool> requestBroadcastPermissions() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return true;
    }

    final statuses = await [
      Permission.microphone,
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.notification,
    ].request();

    final denied = statuses.values.any((status) => status.isDenied || status.isPermanentlyDenied);
    return !denied;
  }
}
