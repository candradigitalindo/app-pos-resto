import 'dart:async';
import 'dart:io';

import 'package:flutter_bluetooth_serial/flutter_bluetooth_serial.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

enum PrinterType { bluetooth, lan }

class PrinterDevice {
  final String name;
  final String address; // BT MAC or IP:port
  final PrinterType type;

  const PrinterDevice({
    required this.name,
    required this.address,
    required this.type,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'address': address,
        'type': type.name,
      };

  factory PrinterDevice.fromMap(Map<String, dynamic> m) => PrinterDevice(
        name: m['name'] as String,
        address: m['address'] as String,
        type: PrinterType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => PrinterType.lan,
        ),
      );

  @override
  String toString() => '$name ($address) [${type.name}]';
}

// ─── PrinterService ───────────────────────────────────────────────────────────

class PrinterService {
  static const _prefKey = 'saved_printers';
  static const _defaultLanPort = 9100;

  // ── Bluetooth ──────────────────────────────────────────────────────────────

  /// Request all required Bluetooth permissions (Android 12+).
  Future<bool> requestBluetoothPermissions() async {
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

  /// Scan for paired Bluetooth devices.
  Future<List<PrinterDevice>> scanBluetooth() async {
    final granted = await requestBluetoothPermissions();
    if (!granted) throw Exception('Izin Bluetooth ditolak');

    final bonded = await FlutterBluetoothSerial.instance.getBondedDevices();
    return bonded
        .map((d) => PrinterDevice(
              name: d.name ?? d.address,
              address: d.address,
              type: PrinterType.bluetooth,
            ))
        .toList();
  }

  // ── LAN Discovery ──────────────────────────────────────────────────────────

  /// Scan the local /24 subnet for open port 9100 (ESC/POS default).
  /// [onProgress] is called with (current, total) for progress feedback.
  Future<List<PrinterDevice>> scanLan({
    int port = _defaultLanPort,
    Duration timeout = const Duration(milliseconds: 400),
    void Function(int current, int total)? onProgress,
  }) async {
    // Detect local IP
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );

    String? localIp;
    for (final iface in interfaces) {
      for (final addr in iface.addresses) {
        if (!addr.isLoopback) {
          localIp = addr.address;
          break;
        }
      }
      if (localIp != null) break;
    }

    if (localIp == null) throw Exception('Tidak dapat mendeteksi IP lokal');

    final parts = localIp.split('.');
    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}';

    final found = <PrinterDevice>[];
    const total = 254;
    var done = 0;

    // Scan 1–254 in parallel batches of 32
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
          );
        })
        .whereType<PrinterDevice>()
        .toList();
  }

  Future<void> savePrinter(PrinterDevice device) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getSavedPrinters();

    // Avoid duplicates by address
    final updated = existing.where((d) => d.address != device.address).toList()
      ..add(device);

    await prefs.setStringList(
      _prefKey,
      updated.map((d) => '${d.name}|${d.address}|${d.type.name}').toList(),
    );
  }

  Future<void> removePrinter(String address) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await getSavedPrinters();
    final updated = existing.where((d) => d.address != address).toList();
    await prefs.setStringList(
      _prefKey,
      updated.map((d) => '${d.name}|${d.address}|${d.type.name}').toList(),
    );
  }

  // ── Test Print ─────────────────────────────────────────────────────────────

  /// Send a simple ESC/POS test page to the printer.
  Future<void> testPrint(PrinterDevice device) async {
    final data = _buildTestPage();

    if (device.type == PrinterType.bluetooth) {
      await _sendBluetooth(device.address, data);
    } else {
      await _sendLan(device.address, data);
    }
  }

  List<int> _buildTestPage() {
    // ESC/POS minimal: init + text + cut
    const esc = 0x1B;
    const gs = 0x1D;
    final bytes = <int>[
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
    return bytes;
  }

  Future<void> _sendBluetooth(String address, List<int> data) async {
    BluetoothConnection? conn;
    try {
      conn = await BluetoothConnection.toAddress(address);
      conn.output.add(data as dynamic);
      await conn.output.allSent;
    } finally {
      conn?.dispose();
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

  // ── Public send methods (for external callers) ─────────────────────────────

  Future<void> sendBluetooth(String address, List<int> data) =>
      _sendBluetooth(address, data);

  Future<void> sendLan(String addressWithPort, List<int> data) =>
      _sendLan(addressWithPort, data);
}
