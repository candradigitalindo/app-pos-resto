import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/models.dart';
import '../../services/auth_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _auth = AuthService();
  List<User>? _users;

  static const _roleLabels = {
    'admin': 'Admin',
    'manager': 'Manager',
    'cashier': 'Kasir',
    'waiter': 'Waiter',
    'kitchen': 'Dapur',
    'bar': 'Bar',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final u = await _auth.getUsers();
    if (mounted) setState(() => _users = u);
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : const Color(0xFF059669),
    ));
  }

  void _showForm({User? existing}) {
    final isEdit = existing != null;
    final nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    final userCtrl = TextEditingController(text: existing?.username ?? '');
    final pinCtrl = TextEditingController();
    var role = existing?.role ?? 'cashier';
    String? error;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(isEdit ? 'Ubah User' : 'Tambah User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: userCtrl,
                  enabled: !isEdit, // username tak diubah saat edit
                  decoration: InputDecoration(
                    labelText: 'Username',
                    helperText: isEdit ? 'Username tidak dapat diubah' : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Peran',
                    border: OutlineInputBorder(),
                  ),
                  items: AuthService.roles
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(_roleLabels[r] ?? r),
                          ))
                      .toList(),
                  onChanged: (v) => setS(() => role = v ?? role),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: pinCtrl,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 4,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: isEdit ? 'PIN Baru (opsional)' : 'PIN (4 digit)',
                    counterText: '',
                    border: const OutlineInputBorder(),
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: 8),
                  Text(error!,
                      style:
                          const TextStyle(color: Color(0xFFEF4444), fontSize: 12)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            FilledButton(
              style:
                  FilledButton.styleFrom(backgroundColor: const Color(0xFF059669)),
              onPressed: () async {
                try {
                  if (isEdit) {
                    await _auth.updateUser(
                      id: existing.id,
                      fullName: nameCtrl.text,
                      role: role,
                      newPin: pinCtrl.text,
                    );
                  } else {
                    await _auth.registerUser(
                      username: userCtrl.text,
                      fullName: nameCtrl.text,
                      role: role,
                      pin: pinCtrl.text,
                    );
                  }
                  if (!ctx.mounted) return;
                  Navigator.pop(ctx);
                  _snack(isEdit ? 'User diperbarui' : 'User ditambahkan');
                  await _load();
                } catch (e) {
                  setS(() =>
                      error = e.toString().replaceFirst('Exception: ', ''));
                }
              },
              child: Text(isEdit ? 'Simpan' : 'Tambah'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleActive(User u) async {
    await _auth.setUserActive(u.id, u.isActive != 1);
    await _load();
  }

  Future<void> _confirmDelete(User u) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus User?'),
        content: Text(
            'Hapus akun "${u.fullName}" (@${u.username})? Tindakan ini permanen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _auth.deleteUser(u.id);
      _snack('User "${u.fullName}" dihapus');
      await _load();
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), error: true);
    }
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'admin':
        return const Color(0xFFEF4444);
      case 'manager':
        return const Color(0xFF7C3AED);
      case 'cashier':
        return const Color(0xFF059669);
      case 'waiter':
        return const Color(0xFF2563EB);
      case 'kitchen':
        return const Color(0xFFEA580C);
      case 'bar':
        return const Color(0xFF0891B2);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Manajemen User'),
        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF059669),
        onPressed: () => _showForm(),
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text('Tambah User', style: TextStyle(color: Colors.white)),
      ),
      body: users == null
          ? const Center(child: CircularProgressIndicator())
          : users.isEmpty
              ? const Center(child: Text('Belum ada user'))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                  itemCount: users.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final u = users[i];
                    final active = u.isActive == 1;
                    return Card(
                      margin: EdgeInsets.zero,
                      child: ListTile(
                        onTap: () => _showForm(existing: u),
                        leading: CircleAvatar(
                          backgroundColor:
                              _roleColor(u.role).withValues(alpha: 0.15),
                          child: Text(
                            u.fullName.isNotEmpty
                                ? u.fullName.characters.first.toUpperCase()
                                : '?',
                            style: TextStyle(
                                color: _roleColor(u.role),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          u.fullName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: active ? null : Colors.grey,
                            decoration:
                                active ? null : TextDecoration.lineThrough,
                          ),
                        ),
                        subtitle: Text('@${u.username}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: _roleColor(u.role).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _roleLabels[u.role] ?? u.role,
                                style: TextStyle(
                                    color: _roleColor(u.role),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            Switch(
                              value: active,
                              activeThumbColor: const Color(0xFF059669),
                              onChanged: (_) => _toggleActive(u),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Color(0xFFEF4444)),
                              tooltip: 'Hapus User',
                              onPressed: () => _confirmDelete(u),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
