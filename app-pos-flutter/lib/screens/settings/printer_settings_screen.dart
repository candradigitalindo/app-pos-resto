import 'package:flutter/material.dart';

import '../../services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _service = PrinterService();
  late final TabController _tabController;

  // Saved printers
  List<PrinterDevice> _saved = [];

  // Bluetooth scan
  List<PrinterDevice> _btDevices = [];
  bool _btScanning = false;
  String? _btError;

  // LAN scan
  List<PrinterDevice> _lanDevices = [];
  bool _lanScanning = false;
  int _lanProgress = 0;
  String? _lanError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSaved();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final saved = await _service.getSavedPrinters();
    if (mounted) setState(() => _saved = saved);
  }

  // ── Bluetooth ──────────────────────────────────────────────────────────────

  Future<void> _scanBluetooth() async {
    setState(() {
      _btScanning = true;
      _btError = null;
      _btDevices = [];
    });
    try {
      final devices = await _service.scanBluetooth();
      if (mounted) setState(() => _btDevices = devices);
    } catch (e) {
      if (mounted) setState(() => _btError = e.toString());
    } finally {
      if (mounted) setState(() => _btScanning = false);
    }
  }

  // ── LAN ────────────────────────────────────────────────────────────────────

  Future<void> _scanLan() async {
    setState(() {
      _lanScanning = true;
      _lanError = null;
      _lanDevices = [];
      _lanProgress = 0;
    });
    try {
      final devices = await _service.scanLan(
        onProgress: (current, total) {
          if (mounted) setState(() => _lanProgress = current);
        },
      );
      if (mounted) setState(() => _lanDevices = devices);
    } catch (e) {
      if (mounted) setState(() => _lanError = e.toString());
    } finally {
      if (mounted) setState(() => _lanScanning = false);
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _save(PrinterDevice device) async {
    await _service.savePrinter(device);
    await _loadSaved();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${device.name} disimpan')),
      );
    }
  }

  /// Ubah peran printer tersimpan (Dapur / Bar / Kasir / -).
  Future<void> _setRole(PrinterDevice device, String role) async {
    await _service.savePrinter(device.copyWith(role: role));
    await _loadSaved();
  }

  Future<void> _remove(PrinterDevice device) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Printer?'),
        content: Text('Hapus "${device.name}" dari daftar?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await _service.removePrinter(device.address);
      await _loadSaved();
    }
  }

  Future<void> _testPrint(PrinterDevice device) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(content: Text('Mengirim test print ke ${device.name}...')),
    );
    try {
      await _service.testPrint(device);
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Test print berhasil: ${device.name}')),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Gagal: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan Printer'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.print), text: 'Tersimpan'),
            Tab(icon: Icon(Icons.bluetooth), text: 'Bluetooth'),
            Tab(icon: Icon(Icons.lan), text: 'LAN'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildSavedTab(),
          _buildBluetoothTab(),
          _buildLanTab(),
        ],
      ),
    );
  }

  // ── Tab: Saved ─────────────────────────────────────────────────────────────

  Widget _buildSavedTab() {
    if (_saved.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.print_disabled, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('Belum ada printer tersimpan',
                style: TextStyle(color: Colors.grey[400], fontSize: 16)),
            const SizedBox(height: 8),
            Text('Scan Bluetooth atau LAN untuk menambahkan',
                style: TextStyle(color: Colors.grey[400], fontSize: 13)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _saved.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _PrinterTile(
        device: _saved[i],
        isSaved: true,
        onSave: null,
        onRemove: () => _remove(_saved[i]),
        onTest: () => _testPrint(_saved[i]),
        onRoleChange: (role) => _setRole(_saved[i], role),
      ),
    );
  }

  // ── Tab: Bluetooth ─────────────────────────────────────────────────────────

  Widget _buildBluetoothTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _btScanning ? null : _scanBluetooth,
              icon: _btScanning
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.bluetooth_searching),
              label: Text(_btScanning ? 'Mencari...' : 'Scan Bluetooth'),
            ),
          ),
        ),
        if (_btError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ErrorBanner(message: _btError!),
          ),
        Expanded(
          child: _btDevices.isEmpty && !_btScanning
              ? Center(
                  child: Text(
                    'Tekan Scan untuk mencari printer Bluetooth\n(hanya perangkat yang sudah dipasangkan)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _btDevices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = _btDevices[i];
                    final alreadySaved =
                        _saved.any((s) => s.address == d.address);
                    return _PrinterTile(
                      device: d,
                      isSaved: alreadySaved,
                      onSave: alreadySaved ? null : () => _save(d),
                      onRemove: alreadySaved ? () => _remove(d) : null,
                      onTest: () => _testPrint(d),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // ── Tab: LAN ───────────────────────────────────────────────────────────────

  Widget _buildLanTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _lanScanning ? null : _scanLan,
                  icon: _lanScanning
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.search),
                  label: Text(_lanScanning
                      ? 'Scanning... ($_lanProgress/254)'
                      : 'Scan Printer LAN (port 9100)'),
                ),
              ),
              if (_lanScanning) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: _lanProgress / 254),
              ],
            ],
          ),
        ),
        if (_lanError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ErrorBanner(message: _lanError!),
          ),
        Expanded(
          child: _lanDevices.isEmpty && !_lanScanning
              ? Center(
                  child: Text(
                    'Tekan Scan untuk mendeteksi printer di jaringan LAN\n(port 9100 / ESC-POS)',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[400], fontSize: 13),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _lanDevices.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final d = _lanDevices[i];
                    final alreadySaved =
                        _saved.any((s) => s.address == d.address);
                    return _PrinterTile(
                      device: d,
                      isSaved: alreadySaved,
                      onSave: alreadySaved ? null : () => _save(d),
                      onRemove: alreadySaved ? () => _remove(d) : null,
                      onTest: () => _testPrint(d),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

// ─── Reusable Widgets ─────────────────────────────────────────────────────────

class _PrinterTile extends StatelessWidget {
  final PrinterDevice device;
  final bool isSaved;
  final VoidCallback? onSave;
  final VoidCallback? onRemove;
  final VoidCallback? onTest;
  final void Function(String role)? onRoleChange;

  const _PrinterTile({
    required this.device,
    required this.isSaved,
    required this.onSave,
    required this.onRemove,
    required this.onTest,
    this.onRoleChange,
  });

  @override
  Widget build(BuildContext context) {
    final isBt = device.type == PrinterType.bluetooth;
    final color = isBt ? Colors.blue : Colors.teal;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isBt ? Icons.bluetooth : Icons.lan,
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(device.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(device.address,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                  if (isSaved)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Tersimpan',
                          style: TextStyle(
                              fontSize: 10,
                              color: Colors.green,
                              fontWeight: FontWeight.w600)),
                    ),
                ],
              ),
            ),

            // Actions
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onTest != null)
                  IconButton(
                    icon: const Icon(Icons.print_outlined, size: 20),
                    tooltip: 'Test Print',
                    onPressed: onTest,
                  ),
                if (onSave != null)
                  IconButton(
                    icon: const Icon(Icons.save_outlined,
                        size: 20, color: Colors.green),
                    tooltip: 'Simpan',
                    onPressed: onSave,
                  ),
                if (onRemove != null)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: Colors.red),
                    tooltip: 'Hapus',
                    onPressed: onRemove,
                  ),
              ],
            ),
          ],
            ),
            if (isSaved && onRoleChange != null) _buildRoleSelector(),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleSelector() {
    const roles = [
      [PrinterRole.kitchen, 'Dapur'],
      [PrinterRole.bar, 'Bar'],
      [PrinterRole.cashier, 'Kasir'],
      [PrinterRole.none, '-'],
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          const Text('Peran:',
              style: TextStyle(fontSize: 11, color: Color(0xFF8E8E93))),
          const SizedBox(width: 8),
          ...roles.map((r) {
            final value = r[0];
            final label = r[1];
            final selected = device.role == value;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onRoleChange!(value),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF059669)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color:
                            selected ? Colors.white : const Color(0xFF8E8E93),
                      )),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
