import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'services/cloud_sync_service.dart';
import 'services/local_api_server.dart';
import 'services/print_queue_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Start local API server for waiter stations (port 7070)
  await LocalApiServer.instance.start();

  // Start kitchen/bar print queue worker (durable + retry, no skip)
  PrintQueueService.instance.start();

  // Start cloud sync worker (push outbox → cloud-pos, jika diaktifkan)
  await CloudSyncService.instance.start();

  // Hide system UI (status bar + navigation bar) — immersive sticky mode
  // System UI will temporarily appear on edge swipe, then auto-hide again
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Lock orientation to landscape for POS tablet use
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const PosRestoApp());
}
