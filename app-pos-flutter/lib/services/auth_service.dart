import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../database/database.dart';
import '../models/models.dart';

class AuthService {
  final AppDatabase _db = AppDatabase.instance;

  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;

  /// Login with username and PIN (4 digit)
  Future<User> login(String username, String pin) async {
    final results = await _db.query(
      'users',
      where: 'username = ? AND is_active = 1',
      whereArgs: [username],
    );

    if (results.isEmpty) {
      throw Exception('Username tidak ditemukan');
    }

    final user = User.fromMap(results.first);

    // Verify PIN hash using bcrypt-style comparison
    // For now using simple hash comparison
    // TODO: Implement proper bcrypt verification
    final pinHash = _hashPin(pin);
    if (user.passwordHash != pinHash &&
        !_verifyBcrypt(pin, user.passwordHash)) {
      throw Exception('PIN salah');
    }

    _currentUser = user;
    await _saveSession(user);
    return user;
  }

  /// Quick login with PIN only (for returning users)
  Future<User> quickLogin(String pin) async {
    final session = await _loadSession();
    if (session == null) {
      throw Exception('Sesi habis, silakan login ulang');
    }

    final results = await _db.query(
      'users',
      where: 'id = ? AND is_active = 1',
      whereArgs: [session],
    );

    if (results.isEmpty) {
      throw Exception('User tidak ditemukan');
    }

    final user = User.fromMap(results.first);

    final pinHash = _hashPin(pin);
    if (user.passwordHash != pinHash &&
        !_verifyBcrypt(pin, user.passwordHash)) {
      throw Exception('PIN salah');
    }

    _currentUser = user;
    await _saveSession(user);
    return user;
  }

  /// Logout
  Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user_id');
  }

  /// Check if there's an active session
  Future<bool> checkSession() async {
    final userId = await _loadSession();
    if (userId == null) return false;

    final results = await _db.query(
      'users',
      where: 'id = ? AND is_active = 1',
      whereArgs: [userId],
    );

    if (results.isEmpty) {
      await logout();
      return false;
    }

    _currentUser = User.fromMap(results.first);
    return true;
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _verifyBcrypt(String pin, String hash) {
    // TODO: Implement proper bcrypt verification
    // For development, accept known default PIN
    if (hash.contains('dummyhash')) {
      return pin == '1234';
    }
    return false;
  }

  Future<void> _saveSession(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user_id', user.id);
  }

  Future<String?> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('current_user_id');
  }
}
