import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';

/// Uses Google Play's system update flow for Android installations from Play.
class AppUpdateService {
  AppUpdateService._();

  static Future<void> checkOnLaunch() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability != UpdateAvailability.updateAvailable) return;
      if (info.immediateUpdateAllowed) {
        await InAppUpdate.performImmediateUpdate();
      } else if (info.flexibleUpdateAllowed) {
        await InAppUpdate.startFlexibleUpdate();
        await InAppUpdate.completeFlexibleUpdate();
      }
    } catch (_) {
      // Local APKs and devices without Google Play do not support this API.
    }
  }
}
