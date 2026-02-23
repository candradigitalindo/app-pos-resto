import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/qr_setup_screen.dart';

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  final AppState appState = AppState();

  @override
  void initState() {
    super.initState();
    appState.init();
  }

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      notifier: appState,
      child: AnimatedBuilder(
        animation: appState,
        builder: (context, _) {
          const primary = Color(0xFF10B981);
          const primaryDark = Color(0xFF059669);
          const background = Color(0xFFF8FAFC);
          const border = Color(0xFFE2E8F0);
          return MaterialApp(
            title: 'Kasir Mobile',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: primary,
                primary: primary,
                secondary: primaryDark,
                surface: Colors.white,
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: background,
              appBarTheme: const AppBarTheme(
                backgroundColor: primaryDark,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              navigationBarTheme: const NavigationBarThemeData(
                backgroundColor: Colors.white,
                indicatorColor: Color(0xFFD1FAE5),
                labelTextStyle: WidgetStatePropertyAll(
                  TextStyle(fontWeight: FontWeight.w600),
                ),
                iconTheme: WidgetStatePropertyAll(
                  IconThemeData(color: primaryDark),
                ),
              ),
              cardTheme: const CardThemeData(
                color: Colors.white,
                elevation: 2,
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
              elevatedButtonTheme: const ElevatedButtonThemeData(
                style: ButtonStyle(
                  backgroundColor: WidgetStatePropertyAll(primary),
                  foregroundColor: WidgetStatePropertyAll(Colors.white),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              outlinedButtonTheme: const OutlinedButtonThemeData(
                style: ButtonStyle(
                  foregroundColor: WidgetStatePropertyAll(Color(0xFF475569)),
                  side: WidgetStatePropertyAll(BorderSide(color: border)),
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                    ),
                  ),
                  padding: WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  ),
                ),
              ),
              inputDecorationTheme: const InputDecorationTheme(
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  borderSide: BorderSide(color: primary),
                ),
              ),
            ),
            home: _resolveHome(appState),
          );
        },
      ),
    );
  }

  Widget _resolveHome(AppState state) {
    if (!state.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (state.baseUrl == null || state.baseUrl!.isEmpty) {
      return const QrSetupScreen();
    }
    if (state.isCheckingConnection) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!state.isServerReachable) {
      return const ServerDisconnectedScreen();
    }
    if (!state.isLoggedIn) {
      return const LoginScreen();
    }
    return const HomeScreen();
  }
}
