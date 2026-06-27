import 'package:flutter/material.dart';

import '../../services/station_api_client.dart';

/// Login PIN di perangkat Station. Memverifikasi ke Main POS lalu menyerahkan
/// data user {id, full_name, username, role} ke [onLoggedIn]. Role menentukan
/// tampilan berikutnya (kasir vs waiter).
class StationLoginScreen extends StatefulWidget {
  final void Function(Map<String, dynamic> user) onLoggedIn;
  const StationLoginScreen({super.key, required this.onLoggedIn});

  @override
  State<StationLoginScreen> createState() => _StationLoginScreenState();
}

class _StationLoginScreenState extends State<StationLoginScreen> {
  String _pin = '';
  bool _busy = false;
  String? _error;

  void _tap(String d) {
    if (_busy || _pin.length >= 8) return;
    setState(() {
      _pin += d;
      _error = null;
    });
  }

  void _del() {
    if (_busy || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submit() async {
    if (_pin.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await StationApiClient.instance.authPin(_pin);
      if (!mounted) return;
      if (user == null) {
        setState(() {
          _error = 'PIN salah';
          _pin = '';
          _busy = false;
        });
        return;
      }
      widget.onLoggedIn(user);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Gagal menghubungi Main POS';
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.point_of_sale,
                  size: 56, color: Color(0xFF10B981)),
              const SizedBox(height: 12),
              const Text('Login Station',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Masukkan PIN — peran menentukan tampilan',
                  style: TextStyle(color: Colors.white54, fontSize: 13)),
              const SizedBox(height: 24),
              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pin.isEmpty ? 4 : _pin.length,
                  (i) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i < _pin.length
                          ? const Color(0xFF10B981)
                          : Colors.white24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 22,
                child: _error != null
                    ? Text(_error!,
                        style: const TextStyle(
                            color: Color(0xFFF87171), fontSize: 13))
                    : (_busy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Color(0xFF10B981)))
                        : null),
              ),
              const SizedBox(height: 12),
              _PinPad(onTap: _tap, onDelete: _del, onSubmit: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinPad extends StatelessWidget {
  final void Function(String) onTap;
  final VoidCallback onDelete;
  final VoidCallback onSubmit;
  const _PinPad(
      {required this.onTap, required this.onDelete, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    Widget key(String label, {VoidCallback? onPressed, IconData? icon}) {
      return Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 76,
          height: 64,
          child: Material(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onPressed ?? () => onTap(label),
              child: Center(
                child: icon != null
                    ? Icon(icon, color: Colors.white, size: 24)
                    : Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) key(d)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            key('', icon: Icons.backspace_outlined, onPressed: onDelete),
            key('0'),
            key('', icon: Icons.check, onPressed: onSubmit),
          ],
        ),
      ],
    );
  }
}
