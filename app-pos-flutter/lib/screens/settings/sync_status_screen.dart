import 'dart:async';

import 'package:flutter/material.dart';

import '../../repositories/sync_queue_repository.dart';
import '../../services/cloud_sync_service.dart';
import '../../theme/theme.dart';
import '../../widgets/ui/ui.dart';

/// Monitor outbox sinkronisasi cloud: lihat pending/sukses/gagal + sync ulang.
class SyncStatusScreen extends StatefulWidget {
  const SyncStatusScreen({super.key});

  @override
  State<SyncStatusScreen> createState() => _SyncStatusScreenState();
}

class _SyncStatusScreenState extends State<SyncStatusScreen> {
  final _queue = SyncQueueRepository();

  static const _accent = AppColors.moduleKasir;

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
    showAppSnack(context, msg);
    await _load();
  }

  Future<void> _retryFailed() async {
    await _queue.retryFailed();
    await _syncNow();
  }

  Future<void> _clearSuccess() async {
    final n = await _queue.clearSuccess();
    if (!mounted) return;
    showAppSnack(context, '$n riwayat sukses dibersihkan');
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final failed = _stats['failed'] ?? 0;
    return Scaffold(
      body: AppBackground(
        child: Column(
          children: [
            AppPageHeader(
              title: 'Status Sinkronisasi',
              subtitle: 'Outbox cloud (kirim ulang)',
              icon: Icons.cloud_sync_rounded,
              accent: _accent,
              actions: [
                if (_syncing)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.sm),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                  )
                else
                  AppIconButton(
                    icon: Icons.cloud_upload_rounded,
                    tooltip: 'Sync sekarang',
                    filled: true,
                    color: _accent,
                    size: 42,
                    onPressed: _syncNow,
                  ),
              ],
            ),
            _buildStatsBar(),
            if (failed > 0) _buildRetryBanner(failed),
            Expanded(
              child: _loading
                  ? const AppLoader()
                  : _jobs.isEmpty
                      ? const EmptyState(
                          icon: Icons.cloud_done_rounded,
                          title: 'Tidak ada antrian sinkronisasi',
                          message: 'Semua data sudah terkirim ke cloud.',
                          accent: _accent,
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            itemCount: _jobs.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (_, i) => _JobTile(job: _jobs[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            _statChip('Antri', _stats['pending'] ?? 0, AppColors.warning),
            const SizedBox(width: AppSpacing.xs),
            _statChip('Terkirim', _stats['success'] ?? 0, AppColors.success),
            const SizedBox(width: AppSpacing.xs),
            _statChip('Gagal', _stats['failed'] ?? 0, AppColors.danger),
            const Spacer(),
            // Aksi sekunder (bukan CTA utama) → aksen GOLD tonal.
            AppButton(
              label: 'Bersihkan',
              icon: Icons.cleaning_services_rounded,
              variant: AppButtonVariant.tonal,
              accent: AppColors.accent,
              size: AppButtonSize.small,
              expanded: false,
              onPressed: (_stats['success'] ?? 0) > 0 ? _clearSuccess : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, int value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.soft(color, 0.10),
        borderRadius: AppRadius.rSm,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value', style: AppType.h3.copyWith(color: color)),
          Text(label,
              style: AppType.caption.copyWith(
                  color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildRetryBanner(int failed) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
      child: AppCard(
        color: AppColors.dangerSoft,
        border: Border.all(color: AppColors.soft(AppColors.danger, 0.3)),
        shadow: const [],
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: AppColors.danger, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text('$failed item gagal terkirim ke cloud',
                  style: AppType.bodySm.copyWith(
                      color: AppColors.danger, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: AppSpacing.sm),
            AppButton(
              label: 'Coba Lagi',
              variant: AppButtonVariant.danger,
              size: AppButtonSize.small,
              expanded: false,
              onPressed: _retryFailed,
            ),
          ],
        ),
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
      'success' => (AppColors.success, Icons.check_circle_rounded, 'Terkirim'),
      'failed' => (AppColors.danger, Icons.error_rounded, 'Gagal'),
      _ => (AppColors.warning, Icons.schedule_rounded, 'Antri'),
    };

    return AppCard(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          IconBadge(icon: icon, color: color, size: 40),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_labels[type] ?? type,
                    style: AppType.title, maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('$op${retry > 0 ? ' · retry $retry' : ''}',
                    style: AppType.caption),
                if (status == 'failed' && error != null && error.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(error,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption.copyWith(color: AppColors.danger)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          StatusPill(label: text, color: color, icon: icon),
        ],
      ),
    );
  }
}
