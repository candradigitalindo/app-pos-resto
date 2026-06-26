import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/models.dart';
import 'services/auth_service.dart';
import 'services/data_retention_service.dart';
import 'services/device_role_service.dart';
import 'services/station_api_client.dart';
import 'screens/login/login_screen.dart';
import 'screens/dashboard/dashboard_screen.dart';
import 'screens/role/role_selector_screen.dart';
import 'screens/station/station_screen.dart';
import 'screens/station/station_setup_screen.dart';

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});

class AuthState {
  final User? user;
  final bool isLoading;
  final bool isChecked;

  const AuthState({this.user, this.isLoading = false, this.isChecked = false});

  bool get isLoggedIn => user != null;

  AuthState copyWith({User? user, bool? isLoading, bool? isChecked}) {
    return AuthState(
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      isChecked: isChecked ?? this.isChecked,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService = AuthService();

  AuthNotifier() : super(const AuthState()) {
    checkSession();
    _runRetention();
  }

  /// Run data retention cleanup in background on app start
  void _runRetention() {
    Future.microtask(() async {
      try {
        final service = DataRetentionService();
        await service.runIfNeeded();
      } catch (_) {
        // Silent fail - don't block app startup
      }
    });
  }

  Future<void> checkSession() async {
    state = state.copyWith(isLoading: true);
    final loggedIn = await _authService.checkSession();
    state = AuthState(
      user: loggedIn ? _authService.currentUser : null,
      isLoading: false,
      isChecked: true,
    );
  }

  Future<void> login(String username, String pin) async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _authService.login(username, pin);
      state = AuthState(user: user, isLoading: false, isChecked: true);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  /// Login hanya dengan PIN — masuk sebagai user yang PIN-nya cocok.
  Future<void> loginByPin(String pin) async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _authService.loginByPin(pin);
      state = AuthState(user: user, isLoading: false, isChecked: true);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AuthState(isChecked: true);
  }
}

class PosRestoApp extends StatelessWidget {
  const PosRestoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      child: MaterialApp(
        title: 'POS Resto',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF10B981),
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        home: const RootGate(),
      ),
    );
  }
}

/// Router awal berdasarkan peran perangkat:
/// belum dipilih → pemilih peran; station → gerbang station; main pos → login.
class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  DeviceRole? _role;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final role = await DeviceRoleService.instance.getRole();
    if (!mounted) return;
    setState(() {
      _role = role;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (_role == null) {
      return RoleSelectorScreen(onSelected: _load);
    }
    if (_role == DeviceRole.station) {
      return const StationGate();
    }
    return const AuthWrapper();
  }
}

/// Gerbang mode Station: kalau sudah ada Main POS tersimpan & hidup → langsung
/// ordering; kalau belum → layar setup koneksi.
class StationGate extends StatefulWidget {
  const StationGate({super.key});

  @override
  State<StationGate> createState() => _StationGateState();
}

class _StationGateState extends State<StationGate> {
  bool _loading = true;
  bool _connected = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final api = StationApiClient.instance;
    final saved = await api.loadSaved();
    var ok = false;
    if (saved != null) {
      final server = await api.ping(saved);
      if (server != null) {
        ok = true;
        // Pastikan outlet_code tersimpan (untuk auto-rediscovery saat IP ganti)
        await api.save(server.baseUrl, outletCode: server.outletCode);
      } else {
        // IP tersimpan tak merespons → coba temukan di IP baru (DHCP berubah)
        ok = await api.rediscover();
      }
    }
    if (!mounted) return;
    setState(() {
      _connected = ok;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return _connected ? const StationScreen() : const StationSetupScreen();
  }
}

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (!authState.isChecked || authState.isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.restaurant, size: 80, color: Color(0xFF10B981)),
              SizedBox(height: 16),
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'POS Resto',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
    }

    if (authState.isLoggedIn) {
      return const DashboardScreen();
    }

    return const LoginScreen();
  }
}
