import 'package:flutter_background/flutter_background.dart';

class AndroidBackgroundService {
  static Future<bool> initialize() async {
    bool hasPermissions = await FlutterBackground.hasPermissions;
    if (!hasPermissions) {
      hasPermissions = await FlutterBackground.initialize();
    }
    return hasPermissions;
  }

  static Future<bool> enableBackgroundExecution() async {
    return await FlutterBackground.enableBackgroundExecution();
  }

  static Future<void> disableBackgroundExecution() async {
    await FlutterBackground.disableBackgroundExecution();
  }
}
