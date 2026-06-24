import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

import 'services/wear_comm_service.dart';
import 'ui/wear/wear_app.dart';

/// Entry point for the Wear OS companion app.
/// Kept minimal — no audio handler, no library controllers, no downloader.
/// All playback happens on the phone; the watch just sends commands and
/// displays state received via watch_connectivity.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initHive();
  _registerServices();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  runApp(const WearApp());
}

Future<void> _initHive() async {
  final dir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(dir.path);
  await Hive.openBox("AppPrefs");
}

void _registerServices() {
  // Only register the wear comm service — everything else lives on the phone
  Get.put(WearCommService(), permanent: true);
}
