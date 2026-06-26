import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../repositories/product_repository.dart';
import '../../services/printer_service.dart';

class PrinterSettingsScreen extends StatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  State<PrinterSettingsScreen> createState() => _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends State<PrinterSettingsScreen>
    with SingleTickerProviderStateMixin {
  final _service = PrinterService();
  final _productRepo = ProductRepository();
  late final TabController _tabController;

  // Saved printers
  List<PrinterDevice> _saved = [];

  // Kategori menu (untuk assign per printer)
  List<Category> _categories = [];

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
    final results = await Future.wait([
      _service.getSavedPrinters(),
      _productRepo.getCategories(),
    ]);
    if (mounted) {
      setState(() {
        _saved = results[0] as List<PrinterDevice>;
        _categories = results[1] as List<Category>;
      });
    }
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

  /// Tambah printer LAN manual via IP:port — jalan keluar bila auto-scan gagal
  /// (WiFi client-isolation, beda subnet, atau printer lambat balas).
  void _showManualLanDialog() {
    final ipCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '9100');
    final nameCtrl = TextEditingController();
    String? error;
    var testing = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Tambah Printer LAN'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ipCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Alamat IP printer *',
                  hintText: 'mis. 192.168.1.50',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: portCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        hintText: '9100',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama (opsional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 10),
                Text(error!,
                    style: const TextStyle(
                        color: Color(0xFFEF4444), fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton.icon(
              onPressed: testing
                  ? null
                  : () async {
                      final ip = ipCtrl.text.trim();
                      final port = int.tryParse(portCtrl.text.trim()) ?? 9100;
                      if (!_isValidIp(ip)) {
                        setS(() => error = 'Format IP tidak valid');
                        return;
                      }
                      setS(() {
                        testing = true;
                        error = null;
                      });
                      final reachable =
                          await _service.pingLan(ip, port);
                      if (!ctx.mounted) return;
                      if (!reachable) {
                        setS(() {
                          testing = false;
                          error =
                              'Tidak bisa terhubung ke $ip:$port. Pastikan printer menyala & satu jaringan.';
                        });
                        return;
                      }
                      final device = PrinterDevice(
                        name: nameCtrl.text.trim().isEmpty
                            ? 'Printer LAN ($ip)'
                            : nameCtrl.text.trim(),
                        address: '$ip:$port',
                        type: PrinterType.lan,
                      );
                      Navigator.pop(ctx);
                      await _save(device);
                    },
              icon: testing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check, size: 18),
              label: Text(testing ? 'Menguji...' : 'Tes & Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  bool _isValidIp(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    for (final p in parts) {
      final n = int.tryParse(p);
      if (n == null || n < 0 || n > 255) return false;
    }
    return true;
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

  /// Aktif/nonaktifkan peran khusus (Checker/Kasir).
  Future<void> _toggleRole(PrinterDevice device, String role) async {
    await _service.savePrinter(device.toggleRole(role));
    await _loadSaved();
  }

  /// Aktif/nonaktifkan kategori menu yang dicetak printer ini.
  Future<void> _toggleCategory(PrinterDevice device, String categoryId) async {
    await _service.savePrinter(device.toggleCategory(categoryId));
    await _loadSaved();
  }

  /// Ubah lebar kertas printer (32 = 58mm, 48 = 80mm).
  Future<void> _setPaper(PrinterDevice device, int cols) async {
    await _service.savePrinter(device.copyWith(paperCols: cols));
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
        onRoleToggle: (role) => _toggleRole(_saved[i], role),
        categories: _categories,
        onCategoryToggle: (catId) => _toggleCategory(_saved[i], catId),
        onPaperChange: (cols) => _setPaper(_saved[i], cols),
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
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _lanScanning ? null : _showManualLanDialog,
                  icon: const Icon(Icons.add_link, size: 18),
                  label: const Text('Tambah manual via IP'),
                ),
              ),
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
  final void Function(String role)? onRoleToggle;
  final List<Category> categories;
  final void Function(String categoryId)? onCategoryToggle;
  final void Function(int cols)? onPaperChange;

  const _PrinterTile({
    required this.device,
    required this.isSaved,
    required this.onSave,
    required this.onRemove,
    required this.onTest,
    this.onRoleToggle,
    this.categories = const [],
    this.onCategoryToggle,
    this.onPaperChange,
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
            if (isSaved && onRoleToggle != null) ...[
              const Divider(height: 18),
              _buildCategorySelector(),
              const SizedBox(height: 12),
              _buildRoleSelector(),
              const SizedBox(height: 12),
              _buildPaperSelector(),
            ],
          ],
        ),
      ),
    );
  }

  /// Pilih lebar kertas: 58mm (32 kolom) / 80mm (48 kolom).
  Widget _buildPaperSelector() {
    Widget chip(String label, int cols) {
      final selected = device.paperCols == cols;
      return GestureDetector(
        onTap: () => onPaperChange?.call(cols),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0F766E) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : const Color(0xFF8E8E93),
              )),
        ),
      );
    }

    return Row(
      children: [
        const Icon(Icons.straighten, size: 14, color: Color(0xFF0F766E)),
        const SizedBox(width: 5),
        const Text('Lebar kertas:',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3C3C43))),
        const SizedBox(width: 8),
        chip('58mm', 32),
        const SizedBox(width: 6),
        chip('80mm', 48),
      ],
    );
  }

  /// Pilih KATEGORI menu yang dicetak printer ini (bisa lebih dari satu).
  Widget _buildCategorySelector() {
    final isChecker = device.hasRole(PrinterRole.checker);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.restaurant_menu, size: 14, color: Color(0xFF059669)),
            SizedBox(width: 5),
            Text('Cetak kategori menu:',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3C3C43))),
          ],
        ),
        const SizedBox(height: 6),
        if (isChecker)
          const Text(
            'Printer ini Checker — otomatis mencetak SEMUA pesanan.',
            style: TextStyle(fontSize: 10, color: Color(0xFF2563EB)),
          )
        else if (categories.isEmpty)
          const Text('Belum ada kategori menu.',
              style: TextStyle(fontSize: 10, color: Color(0xFF8E8E93)))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: categories.map((cat) {
              final selected = device.printsCategory(cat.id);
              return GestureDetector(
                onTap: () => onCategoryToggle?.call(cat.id),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? const Color(0xFF059669)
                        : const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: selected
                            ? const Color(0xFF059669)
                            : const Color(0xFFE5E5EA)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(selected ? Icons.check : Icons.add,
                          size: 13,
                          color: selected
                              ? Colors.white
                              : const Color(0xFFB0B0B5)),
                      const SizedBox(width: 4),
                      Text(cat.name,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: selected
                                ? Colors.white
                                : const Color(0xFF8E8E93),
                          )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        if (!isChecker &&
            device.categoryIds.isEmpty &&
            !device.hasRole(PrinterRole.cashier))
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text(
              '⚠ Belum ada kategori/peran — printer ini hanya dipakai bila tak ada printer lain.',
              style: TextStyle(fontSize: 10, color: Color(0xFFD97706)),
            ),
          ),
      ],
    );
  }

  /// Peran khusus: Checker (salinan seluruh pesanan) & Kasir (struk).
  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Peran khusus:',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3C3C43))),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: PrinterRole.selectable.map((value) {
            final label = PrinterRole.labels[value] ?? value;
            final selected = device.hasRole(value);
            return GestureDetector(
              onTap: () => onRoleToggle!(value),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFF2563EB)
                      : const Color(0xFFF2F2F7),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      size: 13,
                      color: selected ? Colors.white : const Color(0xFFB0B0B5),
                    ),
                    const SizedBox(width: 5),
                    Text(label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color:
                              selected ? Colors.white : const Color(0xFF8E8E93),
                        )),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
