import 'package:flutter/material.dart';

import '../api_client.dart';
import '../app_state.dart';
import '../utils.dart';
import 'qr_setup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameController = TextEditingController();
  final pinController = TextEditingController();
  bool isLoading = false;
  String? errorMessage;

  @override
  void dispose() {
    usernameController.dispose();
    pinController.dispose();
    super.dispose();
  }

  Future<void> handleLogin() async {
    final username = usernameController.text.trim();
    final pin = pinController.text.trim();
    final appState = AppStateScope.of(context);
    final serverInput = appState.baseUrl ?? '';
    if (serverInput.isEmpty) {
      setState(() {
        errorMessage = 'Server belum terhubung';
      });
      return;
    }
    if (username.isEmpty || pin.isEmpty) {
      setState(() {
        errorMessage = 'Username dan PIN wajib diisi';
      });
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final baseUrl = normalizeBaseUrl(serverInput);
    final api = ApiClient(baseUrl: baseUrl);
    final result = await api.post(
      '/auth/login',
      body: {'username': username, 'password': pin},
    );

    if (!mounted) return;

    if (!result.success) {
      setState(() {
        isLoading = false;
        errorMessage = result.message.isEmpty ? 'Login gagal' : result.message;
      });
      return;
    }

    final data = result.data as Map<String, dynamic>? ?? {};
    final token = data['token']?.toString() ?? '';
    final user = (data['user'] as Map?)?.cast<String, dynamic>() ?? {};
    if (token.isEmpty) {
      setState(() {
        isLoading = false;
        errorMessage = 'Token tidak ditemukan';
      });
      return;
    }

    await appState.setSession(baseUrl: baseUrl, token: token, user: user);
    if (!mounted) return;
    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppStateScope.of(context);
    final serverUrl = appState.baseUrl ?? '-';
    return Scaffold(
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF059669), Color(0xFF10B981)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 40 : 20,
                  vertical: 32,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: isWide
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildPromoPanel(context)),
                              const SizedBox(width: 32),
                              Expanded(
                                child: _buildLoginPanel(
                                  appState: appState,
                                  serverUrl: serverUrl,
                                ),
                              ),
                            ],
                          )
                        : _buildLoginPanel(
                            appState: appState,
                            serverUrl: serverUrl,
                          ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPromoPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 72,
            width: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.point_of_sale_outlined,
              color: Colors.white,
              size: 36,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'POS',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'SYSTEM',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Point of Sale Modern',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          const SizedBox(height: 28),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const QrSetupScreen()));
            },
            child: const Text('Tampilkan QR Code Server'),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginPanel({
    required AppState appState,
    required String serverUrl,
  }) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FFFB),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 30,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Selamat Datang Kembali',
                style: TextStyle(
                  color: Color(0xFF047857),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Masuk ke Dashboard',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              _buildStatusBadge(appState),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Kelola bisnis Anda dengan mudah dan efisien',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 16),
          Text(
            serverUrl,
            style: const TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
              hintText: 'Masukkan username Anda',
              prefixIcon: Icon(Icons.person_outline, color: Color(0xFF10B981)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: pinController,
            decoration: const InputDecoration(
              labelText: 'PIN (4 Digit)',
              hintText: '••••',
              prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF10B981)),
            ),
            obscureText: true,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          if (errorMessage != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                errorMessage!,
                style: const TextStyle(
                  color: Color(0xFFB91C1C),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: isLoading ? null : handleLogin,
            child: Text(isLoading ? 'Memproses...' : 'Masuk ke Dashboard'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Icon(
                Icons.verified_user,
                size: 16,
                color: Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Koneksi terenkripsi & aman',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              Text(
                'v1.0.0',
                style: TextStyle(
                  color: const Color(0xFF94A3B8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(AppState appState) {
    final color = appState.isCheckingConnection
        ? const Color(0xFFF59E0B)
        : appState.isServerReachable
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);
    final label = appState.isCheckingConnection
        ? 'Mengecek'
        : appState.isServerReachable
        ? 'Terhubung'
        : 'Offline';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
