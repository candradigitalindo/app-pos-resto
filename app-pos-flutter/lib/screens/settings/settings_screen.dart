import 'package:flutter/material.dart';

import '../../app.dart';
import '../../controllers/settings_controller.dart';
import '../../models/models.dart';
import '../../repositories/order_repository.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/device_role_service.dart';
import 'print_queue_screen.dart';
import 'printer_settings_screen.dart';
import 'sync_status_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final SettingsController _controller;
  late final TabController _tabController;
  final _orderRepo = OrderRepository();

  // Outlet
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _socialCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  final _targetSpendCtrl = TextEditingController();

  // Cloud
  final _apiUrlCtrl = TextEditingController();
  final _apiKeyCtrl = TextEditingController();
  final _outletIdCtrl = TextEditingController();
  bool _syncEnabled = false;
  int _syncInterval = 5;

  // Additional charges
  List<AdditionalCharge> _charges = [];
  bool _loadingCharges = false;

  static const _tabs = [
    Tab(icon: Icon(Icons.store_outlined), text: 'Outlet'),
    Tab(icon: Icon(Icons.receipt_outlined), text: 'Biaya'),
    Tab(icon: Icon(Icons.cloud_outlined), text: 'Cloud'),
    Tab(icon: Icon(Icons.storage_outlined), text: 'Data'),
    Tab(icon: Icon(Icons.settings_outlined), text: 'Aplikasi'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _controller = SettingsController();
    _controller.addListener(_onStateChanged);
    _controller.loadSettings().then((_) => _populate());
    _loadCharges();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _controller.removeListener(_onStateChanged);
    _controller.dispose();
    for (final c in [
      _nameCtrl, _codeCtrl, _addressCtrl, _phoneCtrl,
      _socialCtrl, _footerCtrl, _targetSpendCtrl,
      _apiUrlCtrl, _apiKeyCtrl, _outletIdCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onStateChanged() {
    if (!mounted) return;
    setState(() {});
    final msg =
        _controller.state.successMessage ?? _controller.state.errorMessage;
    if (msg != null) {
      _controller.clearMessages();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(msg),
          backgroundColor: _controller.state.successMessage != null
              ? const Color(0xFF059669)
              : Colors.red,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      });
    }
  }

  void _populate() {
    final info = _controller.state.outletInfo;
    _nameCtrl.text = info.name;
    _codeCtrl.text = info.code;
    _addressCtrl.text = info.address;
    _phoneCtrl.text = info.phone;
    _socialCtrl.text = info.socialMedia;
    _footerCtrl.text = info.receiptFooter;
    _targetSpendCtrl.text =
        info.targetSpendPerPax > 0 ? info.targetSpendPerPax.toString() : '';
    _apiUrlCtrl.text = info.cloudApiUrl;
    _apiKeyCtrl.text = info.cloudApiKey;
    _outletIdCtrl.text = info.cloudOutletId;
    setState(() {
      _syncEnabled = info.syncEnabled;
      _syncInterval = info.syncInterval;
    });
  }

  Future<void> _loadCharges() async {
    setState(() => _loadingCharges = true);
    try {
      final charges = await _orderRepo.getActiveCharges();
      if (mounted) setState(() { _charges = charges; _loadingCharges = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCharges = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Pengaturan',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
          labelStyle:
              const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: const TextStyle(fontSize: 11),
        ),
      ),
      body: _controller.state.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF059669)))
          : TabBarView(
              controller: _tabController,
              children: [
                _tabOutlet(),
                _tabBiaya(),
                _tabCloud(),
                _tabData(),
                _tabAplikasi(),
              ],
            ),
    );
  }

  // ── Tab: Outlet ───────────────────────────────────────────────────────────

  Widget _tabOutlet() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _card([
            _field(_nameCtrl, 'Nama Outlet', Icons.store_outlined),
            _div(),
            _field(_codeCtrl, 'Kode Outlet', Icons.tag_outlined),
            _div(),
            _field(_addressCtrl, 'Alamat', Icons.location_on_outlined,
                maxLines: 2),
            _div(),
            _field(_phoneCtrl, 'Telepon', Icons.phone_outlined,
                keyboardType: TextInputType.phone),
            _div(),
            _field(_socialCtrl, 'Media Sosial', Icons.alternate_email),
            _div(),
            _field(_footerCtrl, 'Catatan Struk', Icons.receipt_outlined,
                maxLines: 2),
            _div(),
            _field(_targetSpendCtrl, 'Target Spend / Pax',
                Icons.people_outline,
                keyboardType: TextInputType.number, prefix: 'Rp '),
          ]),
          const SizedBox(height: 16),
          _saveBtn('Simpan Profil', _controller.state.isSaving, () {
            _controller.saveOutlet(_controller.state.outletInfo.copyWith(
              name: _nameCtrl.text.trim(),
              code: _codeCtrl.text.trim(),
              address: _addressCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              socialMedia: _socialCtrl.text.trim(),
              receiptFooter: _footerCtrl.text.trim(),
              targetSpendPerPax:
                  int.tryParse(_targetSpendCtrl.text) ?? 0,
            ));
          }),
        ],
      ),
    );
  }

  // ── Tab: Biaya Tambahan ───────────────────────────────────────────────────

  Widget _tabBiaya() {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              const Text('Biaya Tambahan (Pajak, Service, dll)',
                  style: TextStyle(
                      fontSize: 13, color: Color(0xFF64748B))),
              const Spacer(),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => _showChargeDialog(),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('Tambah', style: TextStyle(fontSize: 13)),
              ),
            ],
          ),
        ),
        const Divider(height: 0),
        Expanded(
          child: _loadingCharges
              ? const Center(
                  child: CircularProgressIndicator(
                      color: Color(0xFF059669)))
              : _charges.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 48, color: Color(0xFFCBD5E1)),
                          SizedBox(height: 8),
                          Text('Belum ada biaya tambahan',
                              style: TextStyle(
                                  color: Color(0xFF94A3B8))),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _charges.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: 8),
                      itemBuilder: (_, i) => _chargeCard(_charges[i]),
                    ),
        ),
      ],
    );
  }

  // ── Tab: Cloud ────────────────────────────────────────────────────────────

  Widget _tabCloud() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _card([
            _field(_apiUrlCtrl, 'URL Server Cloud', Icons.cloud_outlined),
            _div(),
            _field(_apiKeyCtrl, 'API Key', Icons.vpn_key_outlined,
                obscure: true),
            _div(),
            _field(_outletIdCtrl, 'Outlet ID (dari cloud)',
                Icons.store_outlined),
            _div(),
            _switchRow(
              'Aktifkan Sync',
              'Sinkronisasi otomatis ke cloud',
              Icons.sync,
              _syncEnabled,
              (v) => setState(() => _syncEnabled = v),
            ),
            _div(),
            _dropdownRow<int>(
              'Interval Sync',
              'Menit antar sinkronisasi',
              Icons.timer_outlined,
              _syncInterval,
              [1, 3, 5, 10, 15, 30],
              (v) => setState(() => _syncInterval = v ?? 5),
              labelMap: const {
                1: '1 menit', 3: '3 menit', 5: '5 menit',
                10: '10 menit', 15: '15 menit', 30: '30 menit',
              },
            ),
          ]),
          const SizedBox(height: 16),
          _saveBtn('Simpan Cloud', _controller.state.isSaving, () {
            _controller.saveCloud(
              cloudApiUrl: _apiUrlCtrl.text.trim(),
              cloudApiKey: _apiKeyCtrl.text.trim(),
              cloudOutletId: _outletIdCtrl.text.trim(),
              syncEnabled: _syncEnabled,
              syncInterval: _syncInterval,
            );
          }),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.cloud_upload_outlined),
              label: const Text('Sync Sekarang'),
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                messenger.showSnackBar(
                  const SnackBar(content: Text('Mengirim data ke cloud...')),
                );
                final r = await CloudSyncService.instance.pushNow();
                if (!mounted) return;
                final msg = (r['unconfigured'] ?? 0) == 1
                    ? 'Cloud belum dikonfigurasi (URL/API Key/Outlet ID)'
                    : 'Terkirim: ${r['success']} sukses, ${r['failed']} gagal '
                        '(dari ${r['sent']} item)';
                messenger.showSnackBar(SnackBar(content: Text(msg)));
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.sync_outlined),
              label: const Text('Status Sinkronisasi'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SyncStatusScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab: Data ─────────────────────────────────────────────────────────────

  Widget _tabData() {
    final retentionDays = _controller.state.outletInfo.retentionDays;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _card([
            _dropdownRow<int>(
              'Retensi Data',
              '0 = simpan selamanya',
              Icons.history,
              retentionDays,
              [0, 30, 60, 90, 180, 365],
              (v) => _controller.saveRetention(v ?? 0),
              labelMap: const {
                0: 'Selamanya', 30: '30 hari', 60: '60 hari',
                90: '90 hari', 180: '6 bulan', 365: '1 tahun',
              },
            ),
          ]),
          const SizedBox(height: 12),
          _card([
            _settingRow(
              Icons.download_outlined,
              'Seed Data Contoh',
              'Isi produk & meja sample untuk uji coba',
              onTap: () => _controller.seedData(),
            ),
            _div(),
            _settingRow(
              Icons.delete_forever_outlined,
              'Reset Database',
              'Hapus semua data transaksi permanen',
              iconColor: Colors.red,
              textColor: Colors.red,
              onTap: _showResetDialog,
            ),
          ]),
        ],
      ),
    );
  }

  // ── Tab: Aplikasi ─────────────────────────────────────────────────────────

  Widget _tabAplikasi() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: _card([
        _settingRow(
          Icons.print_outlined,
          'Pengaturan Printer',
          'Konfigurasi printer Bluetooth & LAN',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const PrinterSettingsScreen()),
          ),
        ),
        _div(),
        _settingRow(
          Icons.receipt_long_outlined,
          'Antrian Cetak Dapur/Bar',
          'Pantau status cetak & cetak ulang yang gagal',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PrintQueueScreen()),
          ),
        ),
        _div(),
        _settingRow(
          Icons.devices_other_outlined,
          'Peran Perangkat',
          'Saat ini: Kasir Utama (Main POS)',
          onTap: _changeDeviceRole,
        ),
        _div(),
        _settingRow(
          Icons.info_outline,
          'Versi Aplikasi',
          'POS Resto v1.0.0',
        ),
      ]),
    );
  }

  Future<void> _changeDeviceRole() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ganti Peran Perangkat?'),
        content: const Text(
            'Perangkat akan kembali ke layar pemilihan peran. Gunakan ini bila '
            'ingin menjadikan perangkat ini sebagai Station pelayan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Lanjut')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await DeviceRoleService.instance.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RootGate()),
      (route) => false,
    );
  }

  // ── Charge helpers ────────────────────────────────────────────────────────

  Widget _chargeCard(AdditionalCharge charge) {
    final isActive = charge.isActive == 1;
    final valueStr = charge.chargeType == 'percentage'
        ? '${charge.value.toStringAsFixed(charge.value % 1 == 0 ? 0 : 1)}%'
        : 'Rp ${charge.value.toStringAsFixed(0)}';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isActive
                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                : const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: isActive
                ? const Color(0xFFD1FAE5)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(valueStr,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isActive
                      ? const Color(0xFF059669)
                      : const Color(0xFF94A3B8))),
        ),
        title: Text(charge.name,
            style: const TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Text(
            '${charge.chargeType == 'percentage' ? 'Persentase' : 'Tetap'} • ${isActive ? 'Aktif' : 'Nonaktif'}',
            style: TextStyle(
                fontSize: 12,
                color: isActive
                    ? const Color(0xFF059669)
                    : const Color(0xFF94A3B8))),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined,
              size: 20, color: Color(0xFF94A3B8)),
          onPressed: () => _showChargeDialog(existing: charge),
        ),
      ),
    );
  }

  void _showChargeDialog({AdditionalCharge? existing}) {
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final valueCtrl = TextEditingController(
        text: existing?.value.toString() ?? '');
    String type = existing?.chargeType ?? 'percentage';
    bool isActive = existing == null || existing.isActive == 1;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16)),
          title: Text(existing == null
              ? 'Tambah Biaya Tambahan'
              : 'Edit Biaya Tambahan'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama (cth: PPN, Service Charge)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: valueCtrl,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Nilai',
                        suffixText:
                            type == 'percentage' ? '%' : 'Rp',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DropdownButton<String>(
                    value: type,
                    items: const [
                      DropdownMenuItem(
                          value: 'percentage', child: Text('  %  ')),
                      DropdownMenuItem(
                          value: 'fixed', child: Text('  Rp  ')),
                    ],
                    onChanged: (v) =>
                        setS(() => type = v ?? 'percentage'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                value: isActive,
                title: const Text('Aktif'),
                onChanged: (v) => setS(() => isActive = v),
                activeThumbColor: const Color(0xFF059669),
                activeTrackColor:
                    const Color(0xFF059669).withValues(alpha: 0.4),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal')),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669)),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final value = double.tryParse(valueCtrl.text) ?? 0;
                if (name.isEmpty) return;
                Navigator.pop(ctx);
                try {
                  if (existing == null) {
                    await _orderRepo.createAdditionalCharge(
                        name: name,
                        chargeType: type,
                        value: value,
                        isActive: isActive);
                  } else {
                    await _orderRepo.updateAdditionalCharge(
                        id: existing.id!,
                        name: name,
                        chargeType: type,
                        value: value,
                        isActive: isActive);
                  }
                  _loadCharges();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')));
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Database?'),
        content: const Text(
            'Semua data transaksi akan dihapus permanen dan tidak dapat dikembalikan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx);
              _controller.resetDatabase();
            },
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }

  // ── Widget helpers ────────────────────────────────────────────────────────

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(children: children),
      );

  Widget _div() => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 0, color: Color(0xFFF1F5F9)),
      );

  Widget _field(TextEditingController ctrl, String label, IconData icon,
      {int maxLines = 1,
      TextInputType keyboardType = TextInputType.text,
      bool obscure = false,
      String? prefix}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: maxLines > 1
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 2 : 0),
            child:
                Icon(icon, color: const Color(0xFF94A3B8), size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: ctrl,
              maxLines: maxLines,
              keyboardType: keyboardType,
              obscureText: obscure,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                labelText: label,
                prefixText: prefix,
                labelStyle: const TextStyle(
                    fontSize: 13, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchRow(String title, String subtitle, IconData icon, bool value,
      ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF94A3B8), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFF059669),
            activeTrackColor:
                const Color(0xFF059669).withValues(alpha: 0.4),
          ),
        ],
      ),
    );
  }

  Widget _dropdownRow<T>(String title, String subtitle, IconData icon,
      T value, List<T> options, ValueChanged<T?> onChanged,
      {Map<T, String>? labelMap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF94A3B8), size: 20),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w500, fontSize: 14)),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF94A3B8))),
              ],
            ),
          ),
          DropdownButton<T>(
            value: value,
            underline: const SizedBox(),
            items: options
                .map((v) => DropdownMenuItem(
                    value: v,
                    child: Text(labelMap?[v] ?? v.toString())))
                .toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _settingRow(IconData icon, String title, String subtitle,
      {Color? iconColor, Color? textColor, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon,
                color: iconColor ?? const Color(0xFF64748B), size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                          color: textColor)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF94A3B8))),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right,
                  size: 18, color: Color(0xFFCBD5E1)),
          ],
        ),
      ),
    );
  }

  Widget _saveBtn(String label, bool isLoading, VoidCallback onTap) =>
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: isLoading ? null : onTap,
          child: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : Text(label,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      );
}
