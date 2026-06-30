import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import 'printer_service.dart';

/// Mengumpulkan telemetri perangkat untuk dikirim ke cloud (heartbeat):
/// kondisi tablet (baterai, penyimpanan, model, OS, versi app), status tiap
/// printer (online/offline), dan ringkasan konektivitas.
class DeviceHeartbeatService {
  DeviceHeartbeatService._();
  static final DeviceHeartbeatService instance = DeviceHeartbeatService._();

  static const _channel = MethodChannel('pos/device');
  final _printer = PrinterService();

  /// Bangun payload heartbeat. [online]/[pendingSync]/[lastSyncAt] berasal dari
  /// CloudSyncService (status konektivitas terakhir).
  Future<Map<String, dynamic>> build({
    required bool online,
    required int pendingSync,
    DateTime? lastSyncAt,
  }) async {
    final device = await _deviceInfo();
    final printers = await _printerStatus();
    return {
      'device': device,
      'printers': printers,
      'network': {
        'online': online,
        'pending_sync': pendingSync,
        if (lastSyncAt != null)
          'last_sync_at': lastSyncAt.toUtc().toIso8601String(),
      },
      'reported_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  Future<Map<String, dynamic>> _deviceInfo() async {
    final out = <String, dynamic>{};
    try {
      final pkg = await PackageInfo.fromPlatform();
      out['app_version'] = '${pkg.version}+${pkg.buildNumber}';
    } catch (_) {}
    try {
      final battery = Battery();
      out['battery'] = await battery.batteryLevel; // 0..100
      out['battery_state'] = (await battery.batteryState).name; // charging/full/...
    } catch (_) {}
    try {
      final d = await _channel.invokeMethod('deviceInfo');
      if (d is Map) {
        out['model'] = '${d['manufacturer']} ${d['model']}';
        out['os'] =
            'Android ${d['android_release']} (SDK ${d['sdk_int']})';
      }
    } catch (e) {
      debugPrint('Heartbeat deviceInfo error: $e');
    }
    try {
      final s = await _channel.invokeMethod('storage');
      if (s is Map) {
        final total = (s['total'] as num?)?.toInt() ?? 0;
        final free = (s['free'] as num?)?.toInt() ?? 0;
        const mb = 1024 * 1024;
        out['storage_total_mb'] = (total / mb).round();
        out['storage_free_mb'] = (free / mb).round();
      }
    } catch (e) {
      debugPrint('Heartbeat storage error: $e');
    }
    return out;
  }

  Future<List<Map<String, dynamic>>> _printerStatus() async {
    final saved = await _printer.getSavedPrinters();
    if (saved.isEmpty) return const [];

    // Daftar BT yang ter-pairing (best-effort, tanpa connect agar tak ganggu cetak).
    Set<String> pairedBt = {};
    if (saved.any((p) => p.type == PrinterType.bluetooth)) {
      try {
        final paired = await PrintBluetoothThermal.pairedBluetooths;
        pairedBt = paired.map((b) => b.macAdress).toSet();
      } catch (_) {}
    }

    // Ping semua printer PARALEL → total maksimal ~1 detik apa pun jumlahnya
    // (Socket.connect async, non-blocking; tidak membekukan UI).
    return Future.wait(saved.map((p) async {
      bool online = false;
      String? ip;
      if (p.type == PrinterType.lan) {
        ip = p.address.split(':').first; // IP lokal printer
        try {
          // Ping DISERIALISASI dengan job cetak (tak ganggu perintah order).
          online = await _printer.pingLanSafe(p.address,
              timeout: const Duration(seconds: 1));
        } catch (_) {}
      } else {
        // BT: status "paired" (tak bisa pastikan menyala tanpa connect).
        online = pairedBt.contains(p.address);
      }
      return {
        'name': p.name,
        'address': p.address, // BT MAC atau IP:port
        if (ip != null) 'ip': ip, // IP lokal (LAN)
        'type': p.type.name,
        'roles': p.rolesLabel,
        'connected': online, // terhubung/terjangkau (LAN) atau paired (BT)
        'online': online, // alias kompatibilitas
      };
    }));
  }
}
