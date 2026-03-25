import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/secure_storage.dart';
import '../config/api_client.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

class AuthState {
  final bool configured;
  final bool checking;
  final User? user;

  const AuthState({
    this.configured = false,
    this.checking = true,
    this.user,
  });

  AuthState copyWith({bool? configured, bool? checking, User? user}) {
    return AuthState(
      configured: configured ?? this.configured,
      checking: checking ?? this.checking,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    _checkConfig();
    return const AuthState();
  }

  Future<void> _checkConfig() async {
    final configured = await SecureStorage.isConfigured();
    User? user;
    if (configured) {
      try {
        user = await AuthService.getCurrentUser();
      } catch (_) {}
    }
    state = AuthState(configured: configured, checking: false, user: user);
  }

  Future<void> checkConfig() async {
    await _checkConfig();
  }

  Future<void> login() async {
    User? user;
    try {
      user = await AuthService.getCurrentUser();
    } catch (_) {}
    state = AuthState(configured: true, checking: false, user: user);
  }

  Future<void> logout() async {
    await SecureStorage.clear();
    ApiClient.reset();
    state = const AuthState(configured: false, checking: false);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(() {
  return AuthNotifier();
});
