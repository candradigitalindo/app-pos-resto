import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../app_state.dart';
import '../utils.dart';

class QrSetupScreen extends StatefulWidget {
  const QrSetupScreen({super.key});

  @override
  State<QrSetupScreen> createState() => _QrSetupScreenState();
}

class _QrSetupScreenState extends State<QrSetupScreen> {
  final MobileScannerController controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  final TextEditingController manualController = TextEditingController();
  bool saving = false;
  String? manualError;

  @override
  void dispose() {
    controller.dispose();
    manualController.dispose();
    super.dispose();
  }

  Future<void> handleDetect(BarcodeCapture capture) async {
    if (saving) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value != null && value.isNotEmpty) {
        raw = value;
        break;
      }
    }
    if (raw == null) return;
    final baseUrl = _extractBaseUrl(raw);
    if (baseUrl == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR tidak berisi URL server')),
      );
      return;
    }
    setState(() => saving = true);
    final appState = AppStateScope.of(context);
    await appState.setBaseUrl(baseUrl);
    if (!mounted) return;
    setState(() => saving = false);
  }

  Future<void> handleManualSubmit() async {
    if (saving) return;
    final input = manualController.text.trim();
    if (input.isEmpty) {
      setState(() {
        manualError = 'URL server wajib diisi';
      });
      return;
    }
    final baseUrl = normalizeBaseUrl(input);
    setState(() {
      saving = true;
      manualError = null;
    });
    final appState = AppStateScope.of(context);
    await appState.setBaseUrl(baseUrl);
    if (!mounted) return;
    setState(() => saving = false);
  }

  String? _extractBaseUrl(String raw) {
    String value = raw.trim();
    if (value.startsWith('{') && value.endsWith('}')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          final candidate =
              decoded['baseUrl'] ??
              decoded['base_url'] ??
              decoded['url'] ??
              decoded['server_url'];
          if (candidate is String && candidate.trim().isNotEmpty) {
            value = candidate.trim();
          } else {
            final serverIp = decoded['server_ip']?.toString().trim();
            final serverPort = decoded['server_port']?.toString().trim();
            if (serverIp != null && serverIp.isNotEmpty) {
              value = serverPort == null || serverPort.isEmpty
                  ? 'http://$serverIp'
                  : 'http://$serverIp:$serverPort';
            }
          }
        }
      } catch (_) {
        return null;
      }
    }
    if (value.isEmpty) return null;
    return normalizeBaseUrl(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hubungkan Server',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Scan QR dari halaman login web untuk menyimpan URL server.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: MobileScanner(
                        controller: controller,
                        onDetect: handleDetect,
                        errorBuilder: (context, error, child) {
                          return Container(
                            color: const Color(0xFFF1F5F9),
                            alignment: Alignment.center,
                            child: Text(
                              'Kamera tidak tersedia',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (saving)
                    const LinearProgressIndicator()
                  else
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: const Text(
                        'Arahkan kamera ke QR code server',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Input Manual URL Server',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: manualController,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'URL Server',
                              hintText: 'http://192.168.1.10',
                            ),
                          ),
                          if (manualError != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              manualError!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: saving ? null : handleManualSubmit,
                            child: const Text('Simpan URL'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ServerDisconnectedScreen extends StatelessWidget {
  const ServerDisconnectedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final serverUrl = appState.baseUrl ?? '-';
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 32),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF059669), Color(0xFF10B981)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Server Tidak Terhubung',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Aplikasi tidak dapat menjangkau server.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Server Tersimpan',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            serverUrl,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: appState.isCheckingConnection
                        ? null
                        : appState.checkServerConnection,
                    child: Text(
                      appState.isCheckingConnection
                          ? 'Mengecek...'
                          : 'Coba Lagi',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: appState.clearBaseUrl,
                    child: const Text('Scan Ulang QR'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
