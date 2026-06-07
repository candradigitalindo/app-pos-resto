import 'dart:async';

import 'package:flutter/material.dart';

import '../../repositories/sync_queue_repository.dart';
import '../../services/cloud_sync_service.dart';

/// Monitor outbox sinkronisasi cloud: lihat pending/sukses/gagal + sync ulang.
class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  final _queue = SyncQueueRepository();

  Map<String, int> _stats = const {'pending': 0, 'success': 0, 'failed': 0};
  List<Map<String, dynamic>> _jobs = [];
  bool _loading = true;
  bool _syncing = false;
  Timer? _auto;

  @override
  void initState() {
    super.initState();
    _load();
    _auto = Timer.periodic(const Duration(seconds: 3), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _auto?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final stats = await _queue.stats();
    final jobs = await _queue.recentJobs();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _jobs = jobs;
      _loading = false;
    });
  }

  Future<void> _syncNow() async {
    setState(() => _syncing = true);
    final r = await CloudSyncService.instance.pushNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    final msg = (r['unconfigured'] ?? 0) == 1
        ? 'Cloud belum dikonfigurasi (URL/API Key/Outlet ID)'
        : 'Terkirim: ${r['success']} sukses, ${r['failed']} gagal (dari ${r['sent']})';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    await _load();
  }

  Future<void> _retryFailed() async {
    await _queue.retryFailed();
    await _syncNow();
  }

  Future<void> _clearSuccess() async {
    final n = await _queue.clearSuccess();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$n riwayat sukses dibersihkan')));
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final failed = _stats['failed'] ?? 0;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Status Sinkronisasi Cloud'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: _syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_outlined),
            tooltip: 'Sync sekarang',
            onPressed: _syncing ? null : _syncNow,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatsBar(),
          if (failed > 0) _buildRetryBanner(failed),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _jobs.isEmpty
                    ? _buildEmpty()
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: _jobs.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (_, i) => _JobTile(job: _jobs[i]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          _statChip('Antri', _stats['pending'] ?? 0, const Color(0xFFF59E0B)),
          const SizedBox(width: 10),
          _statChip('Terkirim', _stats['success'] ?? 0, const Color(0xFF10B981)),
          const SizedBox(width: 10),
          _statChip('Gagal', _stats['failed'] ?? 0, const Color(0xFFEF4444)),
          const Spacer(),
          TextButton.icon(
            onPressed: (_stats['success'] ?? 0) > 0 ? _clearSuccess : null,
            icon: const Icon(Icons.cleaning_services_outlined, size: 16),
            label: const Text('Bersihkan'),
          ),
        ],
      ),
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value',
              style: TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 18, color: color)),
          Text(label,
              style: TextStyle(
                  fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRetryBanner(int failed) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border:
            Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_outlined,
              color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$failed item gagal terkirim ke cloud',
                style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: _retryFailed,
            child: const Text('Coba Lagi'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_done_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Tidak ada antrian sinkronisasi',
              style: TextStyle(color: Colors.grey[400], fontSize: 15)),
        ],
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  final Map<String, dynamic> job;
  const _JobTile({required this.job});

  static const _labels = {
    'transaction': 'Transaksi',
    'cashier_shift': 'Shift Kasir',
    'cashier_cash_movement': 'Kas Masuk/Keluar',
    'product': 'Produk',
    'category': 'Kategori',
  };

  @override
  Widget build(BuildContext context) {
    final status = job['status'] as String;
    final type = job['entity_type'] as String? ?? '';
    final op = job['operation'] as String? ?? '';
    final retry = job['retry_count'] as int? ?? 0;
    final error = job['error_message'] as String?;

    final (color, icon, text) = switch (status) {
      'success' => (const Color(0xFF10B981), Icons.check_circle, 'Terkirim'),
      'failed' => (const Color(0xFFEF4444), Icons.error, 'Gagal'),
      _ => (const Color(0xFFF59E0B), Icons.schedule, 'Antri'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_labels[type] ?? type,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('$op${retry > 0 ? ' · retry $retry' : ''}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                if (status == 'failed' && error != null && error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(error,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11, color: Color(0xFFB91C1C))),
                  ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(text,
                style: TextStyle(
                    fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
