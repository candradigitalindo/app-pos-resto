import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hasil dialog otorisasi: PIN + alasan (bila diminta).
class PinAuthResult {
  final String pin;
  final String reason;
  const PinAuthResult({required this.pin, this.reason = ''});
}

/// Dialog OTORISASI PIN (Manager/SVP) yang besar & informatif — dipakai untuk
/// aksi sensitif: void transaksi, hapus item, bayar dari layar transaksi, dll.
/// [details] = rincian aksi (label → nilai) yang ditampilkan di kartu info.
/// Mengembalikan [PinAuthResult] atau null bila dibatalkan.
Future<PinAuthResult?> showPinAuthDialog(
  BuildContext context, {
  required String title,
  required String actionLabel,
  Color actionColor = const Color(0xFFEF4444),
  IconData icon = Icons.verified_user_outlined,
  Map<String, String> details = const {},
  bool askReason = true,
  String reasonHint = 'Contoh: salah input, refund pelanggan',
}) {
  return showDialog<PinAuthResult>(
    context: context,
    builder: (_) => _PinAuthDialog(
      title: title,
      actionLabel: actionLabel,
      actionColor: actionColor,
      icon: icon,
      details: details,
      askReason: askReason,
      reasonHint: reasonHint,
    ),
  );
}

class _PinAuthDialog extends StatefulWidget {
  final String title;
  final String actionLabel;
  final Color actionColor;
  final IconData icon;
  final Map<String, String> details;
  final bool askReason;
  final String reasonHint;

  const _PinAuthDialog({
    required this.title,
    required this.actionLabel,
    required this.actionColor,
    required this.icon,
    required this.details,
    required this.askReason,
    required this.reasonHint,
  });

  @override
  State<_PinAuthDialog> createState() => _PinAuthDialogState();
}

class _PinAuthDialogState extends State<_PinAuthDialog> {
  final _pinCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  bool _pinEmpty = false;

  @override
  void dispose() {
    _pinCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final pin = _pinCtrl.text.trim();
    if (pin.isEmpty) {
      setState(() => _pinEmpty = true);
      return;
    }
    Navigator.pop(context,
        PinAuthResult(pin: pin, reason: _reasonCtrl.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: ikon + judul + subjudul
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: widget.actionColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child:
                          Icon(widget.icon, color: widget.actionColor, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.title,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                          const Text('Perlu otorisasi Manager / SVP',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF64748B))),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Kartu rincian aksi
                if (widget.details.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      children: widget.details.entries
                          .map((e) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      width: 110,
                                      child: Text(e.key,
                                          style: const TextStyle(
                                              fontSize: 13,
                                              color: Color(0xFF64748B))),
                                    ),
                                    Expanded(
                                      child: Text(e.value,
                                          style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Input PIN besar
                TextField(
                  controller: _pinCtrl,
                  autofocus: true,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 12),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) {
                    if (_pinEmpty) setState(() => _pinEmpty = false);
                  },
                  onSubmitted: (_) => _submit(),
                  decoration: InputDecoration(
                    labelText: 'PIN Otorisasi',
                    hintText: '••••',
                    counterText: '',
                    errorText: _pinEmpty ? 'PIN wajib diisi' : null,
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'PIN yang berlaku: akun Admin / Manager / SVP, '
                  'atau PIN void outlet.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                ),

                if (widget.askReason) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _reasonCtrl,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    decoration: InputDecoration(
                      labelText: 'Alasan (opsional)',
                      hintText: widget.reasonHint,
                      prefixIcon: const Icon(Icons.notes_outlined),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Batal',
                              style: TextStyle(fontSize: 15)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 50,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: widget.actionColor),
                          onPressed: _submit,
                          child: Text(widget.actionLabel,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
