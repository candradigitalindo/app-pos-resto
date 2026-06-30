import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Hasil dialog pesanan baru: jumlah pax (wajib) + identitas customer (opsional).
class PaxResult {
  final int pax;
  final String? customerName;
  final String? customerPhone;
  const PaxResult({required this.pax, this.customerName, this.customerPhone});
}

/// Dialog input jumlah tamu (pax) + identitas customer untuk pesanan BARU.
/// Hanya pax yang wajib; Nama & No. HP opsional. Mengembalikan [PaxResult],
/// atau null bila dibatalkan.
Future<PaxResult?> showPaxDialog(BuildContext context, {int initial = 1}) {
  return showDialog<PaxResult>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _PaxInputDialog(initial: initial),
  );
}

class _PaxInputDialog extends StatefulWidget {
  final int initial;
  const _PaxInputDialog({required this.initial});

  @override
  State<_PaxInputDialog> createState() => _PaxInputDialogState();
}

class _PaxInputDialogState extends State<_PaxInputDialog> {
  late int _pax = widget.initial.clamp(1, 99);
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  void _set(int v) => setState(() => _pax = v.clamp(1, 99));

  void _submit() {
    final name = _nameCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();
    Navigator.pop(
      context,
      PaxResult(
        pax: _pax,
        customerName: name.isEmpty ? null : name,
        customerPhone: phone.isEmpty ? null : phone,
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding:
          const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      titlePadding: const EdgeInsets.fromLTRB(28, 24, 28, 8),
      contentPadding: const EdgeInsets.fromLTRB(28, 8, 28, 8),
      actionsPadding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      title: const Row(
        children: [
          Icon(Icons.people_outline, color: Color(0xFF059669), size: 28),
          SizedBox(width: 12),
          Text('Pesanan Baru',
              style:
                  TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Jumlah tamu (pax) wajib diisi.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
              const SizedBox(height: 20),
              // Pax stepper — besar di tengah
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _stepBtn(Icons.remove, () => _set(_pax - 1)),
                      Container(
                        width: 110,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('$_pax',
                                style: const TextStyle(
                                    fontSize: 44,
                                    fontWeight: FontWeight.w800,
                                    height: 1.0)),
                            const Text('pax',
                                style: TextStyle(
                                    fontSize: 12, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                      _stepBtn(Icons.add, () => _set(_pax + 1)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text('Identitas Customer (opsional)',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF94A3B8))),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama (opsional)',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
                ],
                decoration: const InputDecoration(
                  labelText: 'No. HP (opsional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
          child: const Text('Batal', style: TextStyle(fontSize: 15)),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF059669),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          ),
          onPressed: _submit,
          child: const Text('Lanjut',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => Material(
        color: const Color(0xFF059669),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      );
}
