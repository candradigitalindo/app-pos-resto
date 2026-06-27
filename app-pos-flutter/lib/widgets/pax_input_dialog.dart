import 'package:flutter/material.dart';

/// Dialog input jumlah tamu (pax) untuk pesanan BARU.
/// Mengembalikan jumlah pax (1..99) bila dikonfirmasi, atau null bila batal.
Future<int?> showPaxDialog(BuildContext context, {int initial = 1}) {
  return showDialog<int>(
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

  void _set(int v) => setState(() => _pax = v.clamp(1, 99));

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.people_outline, color: Color(0xFF059669)),
          SizedBox(width: 10),
          Text('Jumlah Tamu'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Masukkan jumlah tamu (pax) untuk pesanan baru ini.',
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _stepBtn(Icons.remove, () => _set(_pax - 1)),
              Container(
                width: 90,
                alignment: Alignment.center,
                child: Text(
                  '$_pax',
                  style: const TextStyle(
                      fontSize: 34, fontWeight: FontWeight.w800),
                ),
              ),
              _stepBtn(Icons.add, () => _set(_pax + 1)),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          style:
              FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
          onPressed: () => Navigator.pop(context, _pax),
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
