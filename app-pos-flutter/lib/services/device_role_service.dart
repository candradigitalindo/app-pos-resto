import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_sync_service.dart';
import 'local_api_server.dart';
import 'print_queue_service.dart';

/// Peran perangkat. Menentukan apakah device jadi server (Main POS) atau
/// hanya client (Station/tablet pelayan).
enum DeviceRole { mainPos, station }

class DeviceRoleService {
  static final DeviceRoleService instance = DeviceRoleService._();
  DeviceRoleService._();

  static const _key = 'device_role';

  /// Null = belum dipilih (tampilkan pemilih peran).
  Future<DeviceRole?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == 'main_pos') return DeviceRole.mainPos;
    if (raw == 'station') return DeviceRole.station;
    return null;
  }

  Future<void> setRole(DeviceRole role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      role == DeviceRole.mainPos ? 'main_pos' : 'station',
    );
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  // ── Service startup (hanya untuk Main POS) ───────────────────────────────────

  bool _mainPosStarted = false;

  /// Nyalakan server API 7070 + print queue + cloud sync. Idempoten.
  /// Tidak dipanggil di mode station (hemat resource, tak buka port).
  Future<void> startMainPosServices() async {
    if (_mainPosStarted) return;
    _mainPosStarted = true;
    await LocalApiServer.instance.start();
    PrintQueueService.instance.start();
    await CloudSyncService.instance.start();
  }
}
