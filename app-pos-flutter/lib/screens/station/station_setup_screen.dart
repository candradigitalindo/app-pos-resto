import 'package:flutter/material.dart';

import '../../services/station_api_client.dart';
import 'station_screen.dart';

/// Layar setup mode Station: temukan Main POS di jaringan lalu hubungkan.
class StationSetupScreen extends StatefulWidget {
  const StationSetupScreen({super.key});

  @override
  State<StationSetupScreen> createState() => _StationSetupScreenState();
}

class _StationSetupScreenState extends State<StationSetupScreen> {
  final _api = StationApiClient.instance;
  final _manualCtrl = TextEditingController();

  List<StationServer> _found = [];
  bool _scanning = false;
  int _progress = 0;
  String? _error;
  String? _connecting;

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  Future<void> _scan() async {
    setState(() {
      _scanning = true;
      _found = [];
      _progress = 0;
      _error = null;
    });
    try {
      final servers = await _api.discover(
        onProgress: (c, t) {
          if (mounted) setState(() => _progress = (c / t * 100).round());
        },
      );
      if (mounted) setState(() => _found = servers);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _connect(String baseUrl, String name) async {
    setState(() => _connecting = baseUrl);
    final server = await _api.ping(baseUrl);
    if (!mounted) return;
    setState(() => _connecting = null);
    if (server == null) {
      setState(() => _error = 'Tidak dapat terhubung ke $baseUrl');
      return;
    }
    await _api.save(server.baseUrl);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StationScreen()),
    );
  }

  Future<void> _connectManual() async {
    var input = _manualCtrl.text.trim();
    if (input.isEmpty) return;
    if (!input.startsWith('http')) {
      input = 'http://$input:${StationApiClient.serverPort}';
    }
    await _connect(input, input);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(title: const Text('Hubungkan ke Main POS')),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _scanning ? null : _scan,
                    icon: _scanning
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.wifi_find),
                    label: Text(_scanning
                        ? 'Mencari... $_progress%'
                        : 'Cari Main POS (port ${StationApiClient.serverPort})'),
                  ),
                ),
                if (_scanning) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(value: _progress / 100),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _manualCtrl,
                        decoration: const InputDecoration(
                          hintText: 'atau IP manual, mis. 192.168.1.10',
                          isDense: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _connecting != null ? null : _connectManual,
                      child: const Text('Hubung'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_error != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_error!,
                  style: const TextStyle(color: Color(0xFFB91C1C))),
            ),
          Expanded(
            child: _found.isEmpty
                ? Center(
                    child: Text(
                      _scanning
                          ? 'Memindai jaringan...'
                          : 'Tekan "Cari Main POS" untuk menemukan\nperangkat kasir utama di WiFi yang sama',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _found.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final s = _found[i];
                      final loading = _connecting == s.baseUrl;
                      return Card(
                        margin: EdgeInsets.zero,
                        child: ListTile(
                          leading: const Icon(Icons.point_of_sale,
                              color: Color(0xFF059669)),
                          title: Text(s.outletName,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(
                              '${s.baseUrl} · ${s.connectedStations} station'),
                          trailing: loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2))
                              : const Icon(Icons.chevron_right),
                          onTap: loading
                              ? null
                              : () => _connect(s.baseUrl, s.outletName),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
