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
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.people_outline, color: Color(0xFF059669)),
          SizedBox(width: 10),
          Text('Pesanan Baru'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Jumlah tamu (pax) wajib diisi.',
                style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            // Pax stepper
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _stepBtn(Icons.remove, () => _set(_pax - 1)),
                  Container(
                    width: 90,
                    alignment: Alignment.center,
                    child: Text('$_pax',
                        style: const TextStyle(
                            fontSize: 34, fontWeight: FontWeight.w800)),
                  ),
                  _stepBtn(Icons.add, () => _set(_pax + 1)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Identitas customer (opsional) — di bawah pax
            const Text('Identitas Customer (opsional)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF94A3B8))),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nama (opsional)',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),
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
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
          onPressed: _submit,
          child: const Text('Lanjut'),
        ),
      ],
    );
  }

  Widget _stepBtn(IconData icon, VoidCallback onTap) => Material(
        color: const Color(0xFFF1F5F9),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Icon(icon, color: const Color(0xFF059669), size: 26),
          ),
        ),
      );
}
