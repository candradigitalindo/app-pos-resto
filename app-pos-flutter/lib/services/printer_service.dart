import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:network_info_plus/network_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

enum PrinterType { bluetooth, lan }

/// Peran printer untuk routing cetakan order.
/// kitchen/bar dipakai print queue; cashier untuk struk (cetak langsung).
class PrinterRole {
  static const String kitchen = 'kitchen';
  static const String bar = 'bar';
  static const String cashier = 'cashier';
  static const String none = 'none';
}

class PrinterDevice {
  final String name;
  final String address; // BT MAC or IP:port
  final PrinterType type;
  final String role; // kitchen | bar | cashier | none

  const PrinterDevice({
    required this.name,
    required this.address,
    required this.type,
    this.role = PrinterRole.none,
  });

  PrinterDevice copyWith({String? role}) => PrinterDevice(
        name: name,
        address: address,
        type: type,
        role: role ?? this.role,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'type': type.name,
        'role': role,
      };

  factory PrinterDevice.fromMap(Map<String, dynamic> m) => PrinterDevice(
        name: m['name'] as String,
        address: m['address'] as String,
        type: PrinterType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => PrinterType.lan,
        ),
        role: m['role'] as String? ?? PrinterRole.none,
      );

  @override
  String toString() => '$name ($address) [${type.name}/$role]';
}

// ─── PrinterService ───────────────────────────────────────────────────────────

class PrinterService {
  static const _prefKey = 'saved_printers';
  static const _defaultLanPort = 9100;

  // ── Bluetooth ──────────────────────────────────────────────────────────────

  /// Request Bluetooth permissions (Android only; iOS handled via Info.plist).
  Future<bool> requestBluetoothPermissions() async {
    if (Platform.isIOS) return true;

    final statuses = await [
      Permission.bluetooth,
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();

    return statuses.values.every(
      (s) => s == PermissionStatus.granted || s == PermissionStatus.limited,
    );
  }

  /// Return paired BT devices (Android) or BLE-discovered devices (iOS).
  Future<List<PrinterDevice>> scanBluetooth() async {
    final granted = await requestBluetoothPermissions();
    if (!granted) throw Exception('Izin Bluetooth ditolak');

    final devices = await PrintBluetoothThermal.pairedBluetooths;
    return devices
        .map((d) => PrinterDevice(
              name: d.name.isNotEmpty ? d.name : d.macAdress,
              address: d.macAdress,
              type: PrinterType.bluetooth,
            ))
        .toList();
  }

  // ── LAN Discovery ──────────────────────────────────────────────────────────

  /// Scan local /24 subnet for open port 9100 (ESC/POS default).
  Future<List<PrinterDevice>> scanLan({
    int port = _defaultLanPort,
    Duration timeout = const Duration(milliseconds: 400),
    void Function(int current, int total)? onProgress,
  }) async {
    // network_info_plus lebih andal di iOS (menghindari VPN/interface ganda)
    String? localIp = await NetworkInfo().getWifiIP();

    // Fallback ke dart:io jika network_info_plus tidak berhasil
    if (localIp == null || localIp.isEmpty) {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (!addr.isLoopback) {
            localIp = addr.address;
            break;
          }
        }
        if (localIp != null) break;
      }
    }

    if (localIp == null) throw Exception('Tidak dapat mendeteksi IP lokal. Pastikan WiFi aktif.');

    final parts = localIp.split('.');
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

    final found = <PrinterDevice>[];
    const total = 254;
    var done = 0;

    const batchSize = 32;
    for (var start = 1; start <= total; start += batchSize) {
      final end = (start + batchSize - 1).clamp(1, total);
      final futures = <Future<void>>[];

      for (var i = start; i <= end; i++) {
        final ip = '$subnet.$i';
        futures.add(_checkPort(ip, port, timeout).then((open) {
          if (open) {
            found.add(PrinterDevice(
              name: 'Printer LAN ($ip)',
              address: '$ip:$port',
              type: PrinterType.lan,
            ));
          }
          done++;
          onProgress?.call(done, total);
        }));
      }
      await Future.wait(futures);
    }

    return found;
  }

  Future<bool> _checkPort(String ip, int port, Duration timeout) async {
    try {
      final socket = await Socket.connect(ip, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (_) {
      return false;
    }
  }

  // ── Persistence ────────────────────────────────────────────────────────────

  Future<List<PrinterDevice>> getSavedPrinters() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefKey) ?? [];
    return raw
        .map((s) {
          final parts = s.split('|');
          if (parts.length < 3) return null;
          return PrinterDevice(
            name: parts[0],
            address: parts[1],
            type: PrinterType.values.firstWhere(
              (t) => t.name == parts[2],
              orElse: () => PrinterType.lan,
            ),
            // Backward-compat: printer lama (3 field) → role 'none'
            role: parts.length >= 4 ? parts[3] : PrinterRole.none,
          );
        })
        .whereType<PrinterDevice>()
        .toList();
  }

  /// Printer aktif untuk satu peran (kitchen/bar/cashier). Bisa lebih dari satu.
  Future<List<PrinterDevice>> getPrintersByRole(String role) async {
    final all = await getSavedPrinters();
    return all.where((p) => p.role == role).toList();
  }

  Future<void> savePrinter(PrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getSavedPrinters();
    final updated = existing.where((d) => d.address != device.address).toList()
      ..add(device);
    await prefs.setStringList(_prefKey, updated.map(_serialize).toList());
  }

  Future<void> removePrinter(String address) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getSavedPrinters();
    final updated = existing.where((d) => d.address != address).toList();
    await prefs.setStringList(_prefKey, updated.map(_serialize).toList());
  }

  String _serialize(PrinterDevice d) =>
      '${d.name}|${d.address}|${d.type.name}|${d.role}';

  // ── Test Print ─────────────────────────────────────────────────────────────

  Future<void> testPrint(PrinterDevice device) async {
    final data = _buildTestPage();
    if (device.type == PrinterType.bluetooth) {
      await _sendBluetooth(device.address, data);
    } else {
      await _sendLan(device.address, data);
    }
  }

  List<int> _buildTestPage() {
    const esc = 0x1B;
    const gs = 0x1D;
    return [
      esc, 0x40, // Initialize
      esc, 0x61, 0x01, // Center align
      esc, 0x21, 0x10, // Double height
      ...'\nPOS RESTO\n'.codeUnits,
      esc, 0x21, 0x00, // Normal
      ...('-' * 32).codeUnits,
      ...'\nTest Print OK\n'.codeUnits,
      ...DateTime.now().toString().codeUnits,
      ...'\n\n\n'.codeUnits,
      gs, 0x56, 0x41, 0x03, // Cut
    ];
  }

  // ── Internal send ──────────────────────────────────────────────────────────

  Future<void> _sendBluetooth(String address, List<int> data) async {
    final connected = await PrintBluetoothThermal.connect(
      macPrinterAddress: address,
    );
    if (!connected) throw Exception('Gagal terhubung ke printer Bluetooth');
    try {
      final sent = await PrintBluetoothThermal.writeBytes(
        Uint8List.fromList(data),
      );
      if (!sent) throw Exception('Gagal mengirim data ke printer');
    } finally {
      await PrintBluetoothThermal.disconnect;
    }
  }

  Future<void> _sendLan(String addressWithPort, List<int> data) async {
    final parts = addressWithPort.split(':');
    final ip = parts[0];
    final port = parts.length > 1 ? int.tryParse(parts[1]) ?? 9100 : 9100;

    final socket =
        await Socket.connect(ip, port, timeout: const Duration(seconds: 5));
    try {
      socket.add(data);
      await socket.flush();
    } finally {
      await socket.close();
    }
  }

  // ── Public send methods ────────────────────────────────────────────────────

  Future<void> sendBluetooth(String address, List<int> data) =>
      _sendBluetooth(address, data);

  Future<void> sendLan(String addressWithPort, List<int> data) =>
      _sendLan(addressWithPort, data);
}
