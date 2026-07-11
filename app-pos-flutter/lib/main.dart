import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app.dart';
import 'services/device_role_service.dart';
import 'services/logo_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Muat logo struk dari penyimpanan lokal ke cache (untuk cetak offline).
  await LogoService.instance.init();

  // Server API 7070 + print queue + cloud sync HANYA untuk Main POS.
  // Mode Station (atau peran belum dipilih) tidak membuka port apa pun.
  final role = await DeviceRoleService.instance.getRole();
  if (role == DeviceRole.mainPos) {
    await DeviceRoleService.instance.startMainPosServices();
  }

  // Hide system UI (status bar + navigation bar) — immersive sticky mode
  // System UI will temporarily appear on edge swipe, then auto-hide again
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  // Semua orientasi didukung: tablet biasanya landscape, HP bisa portrait.
  // Layout menyesuaikan otomatis via helper responsif (context.isPhone dll).
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  runApp(const PosRestoApp());
}
