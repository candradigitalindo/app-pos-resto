import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'api_client.dart';

class AppState extends ChangeNotifier {
  String? token;
  String? baseUrl;
  Map<String, dynamic>? user;
  bool isInitialized = false;
  bool isCheckingConnection = false;
  bool isServerReachable = false;

  bool get isLoggedIn => token != null && token!.isNotEmpty;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    token = prefs.getString('token');
    baseUrl = prefs.getString('baseUrl');
    final userJson = prefs.getString('user');
    if (userJson != null && userJson.isNotEmpty) {
      user = jsonDecode(userJson) as Map<String, dynamic>;
    }
    isInitialized = true;
    notifyListeners();
    if (baseUrl != null && baseUrl!.isNotEmpty) {
      await checkServerConnection();
    }
  }

  Future<void> setSession({
    required String baseUrl,
    required String token,
    required Map<String, dynamic> user,
  }) async {
    this.baseUrl = baseUrl;
    this.token = token;
    this.user = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', baseUrl);
    await prefs.setString('token', token);
    await prefs.setString('user', jsonEncode(user));
    notifyListeners();
  }

  Future<void> setBaseUrl(String baseUrl) async {
    this.baseUrl = baseUrl;
    token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('baseUrl', baseUrl);
    await prefs.remove('token');
    await prefs.remove('user');
    notifyListeners();
    await checkServerConnection();
  }

  Future<void> clearBaseUrl() async {
    baseUrl = null;
    token = null;
    user = null;
    isServerReachable = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('baseUrl');
    await prefs.remove('token');
    await prefs.remove('user');
    notifyListeners();
  }

  Future<void> checkServerConnection() async {
    if (baseUrl == null || baseUrl!.isEmpty) {
      isServerReachable = false;
      notifyListeners();
      return;
    }
    if (isCheckingConnection) return;
    isCheckingConnection = true;
    notifyListeners();
    try {
      final client = ApiClient(baseUrl: baseUrl!);
      final result = await client.get('/server/qr');
      isServerReachable = result.success;
    } catch (_) {
      isServerReachable = false;
    }
    isCheckingConnection = false;
    notifyListeners();
  }

  Future<void> clearSession() async {
    token = null;
    user = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user');
    notifyListeners();
  }
}

class AppStateScope extends InheritedNotifier<AppState> {
  const AppStateScope({
    super.key,
    required super.notifier,
    required super.child,
  });

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppStateScope>();
    if (scope == null || scope.notifier == null) {
      throw StateError('AppStateScope not found');
    }
    return scope.notifier!;
  }
}
