import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/print_queue_service.dart';

/// Monitor antrian cetak dapur/bar: lihat pending/done/failed + cetak ulang.
class PrintQueueScreen extends StatefulWidget {
  const PrintQueueScreen({super.key});

  @override
  State<PrintQueueScreen> createState() => _PrintQueueScreenState();
}

class _PrintQueueScreenState extends State<PrintQueueScreen> {
  final _service = PrintQueueService.instance;

  Map<String, int> _stats = const {'pending': 0, 'done': 0, 'failed': 0};
  List<Map<String, dynamic>> _jobs = [];
  bool _loading = true;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _load();
    // Auto-refresh tiap 2 detik agar status job terlihat hidup
    _autoRefresh = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    final stats = await _service.stats();
    final jobs = await _service.recentJobs();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _jobs = jobs;
      _loading = false;
    });
  }

  Future<void> _reprintJob(String id) async {
    await _service.reprint(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mencetak ulang ke printer...')),
      );
    }
    _load();
  }

  Future<void> _retryFailed() async {
    await _service.retryFailed();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Job gagal dimasukkan ulang ke antrian')),
    );
    await _load();
  }

  Future<void> _clearDone() async {
    final n = await _service.clearDone();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$n riwayat cetak dibersihkan')),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final failed = _stats['failed'] ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      appBar: AppBar(
        title: const Text('Antrian Cetak Dapur/Bar'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang',
            onPressed: () => _load(),
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, i) => _JobTile(
                            job: _jobs[i],
                            onReprint: () =>
                                _reprintJob(_jobs[i]['id'] as String),
                          ),
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
          _statChip('Selesai', _stats['done'] ?? 0, const Color(0xFF10B981)),
          const SizedBox(width: 10),
          _statChip('Gagal', _stats['failed'] ?? 0, const Color(0xFFEF4444)),
          const Spacer(),
          TextButton.icon(
            onPressed: (_stats['done'] ?? 0) > 0 ? _clearDone : null,
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
        border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFEF4444), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('$failed cetakan gagal terkirim ke printer',
                style: const TextStyle(
                    color: Color(0xFFB91C1C),
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444)),
            onPressed: _retryFailed,
            child: const Text('Cetak Ulang'),
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
          Icon(Icons.print_disabled_outlined, size: 56, color: Colors.grey[300]),
          const SizedBox(height: 12),
          Text('Belum ada riwayat cetak',
              style: TextStyle(color: Colors.grey[400], fontSize: 15)),
        ],
      ),
    );
  }
}

class _JobTile extends StatelessWidget {
  final Map<String, dynamic> job;
  final VoidCallback? onReprint;
  const _JobTile({required this.job, this.onReprint});

  @override
  Widget build(BuildContext context) {
    final status = job['status'] as String;
    final role = job['role'] as String? ?? '';
    final type = job['printer_type'] as String? ?? '';
    final label = (job['label'] as String?) ?? '';
    final retry = job['retry_count'] as int? ?? 0;
    final error = job['error_message'] as String?;

    final (color, icon, text) = switch (status) {
      'done' => (const Color(0xFF10B981), Icons.check_circle, 'Terkirim'),
      'failed' => (const Color(0xFFEF4444), Icons.error, 'Gagal'),
      _ => (const Color(0xFFF59E0B), Icons.schedule, 'Menunggu'),
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
                Text(label.isNotEmpty ? label : '${role.toUpperCase()} ($type)',
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(
                  '${role.toUpperCase()} · $type${retry > 0 ? ' · retry $retry' : ''}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
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
          // Cetak ulang per-tiket (selain yang masih menunggu).
          if (status != 'pending' && onReprint != null) ...[
            const SizedBox(width: 4),
            IconButton(
              onPressed: onReprint,
              icon: const Icon(Icons.refresh, size: 20, color: Color(0xFF2563EB)),
              tooltip: 'Cetak ulang',
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}
