import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../di/providers.dart';
import '../services/auth_service.dart';
import 'purchase_controller.dart';

class AuthState {
  final bool isLoggedIn;
  final String name;
  final String? userId;
  final String? email;
  final bool isBlocked;
  final String? blockReason;

  const AuthState({
    required this.isLoggedIn,
    required this.name,
    required this.userId,
    required this.email,
    required this.isBlocked,
    required this.blockReason,
  });

  AuthState copyWith({
    bool? isLoggedIn,
    String? name,
    String? userId,
    String? email,
    bool? isBlocked,
    String? blockReason,
  }) {
    return AuthState(
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      name: name ?? this.name,
      userId: userId ?? this.userId,
      email: email ?? this.email,
      isBlocked: isBlocked ?? this.isBlocked,
      blockReason: blockReason ?? this.blockReason,
    );
  }
}

final authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);

class AuthController extends Notifier<AuthState> {
  Timer? _accessTimer;
  /// Bir xil foydalanuvchi uchun [build] qayta chaqirilsa, microtask/spam oldini olish.
  String? _hydratedUserId;
  /// Ketma-ket muvaffaqiyatli javoblarda `session_active: false` — tarmoq xatosida nolga qaytaramiz.
  int _inactiveSessionStreak = 0;

  @override
  AuthState build() {
    final user = ref.watch(authServiceProvider).currentUser;
    if (user == null) {
      _accessTimer?.cancel();
      _hydratedUserId = null;
      _inactiveSessionStreak = 0;
      return const AuthState(
        isLoggedIn: false,
        name: 'Mehmon',
        userId: null,
        email: null,
        isBlocked: false,
        blockReason: null,
      );
    }
    if (_hydratedUserId != user.id) {
      _hydratedUserId = user.id;
      _inactiveSessionStreak = 0;
      _accessTimer?.cancel();
      Future.microtask(() {
        ref.read(purchaseControllerProvider.notifier).bindRealtime(user.id);
        ref.read(purchaseControllerProvider.notifier).syncFromBackend(user.id);
        _verifyUserAccess(user.id);
      });
      _startAccessTimer(user.id);
    }
    return _fromUser(user);
  }

  void _startAccessTimer(String userId) {
    _accessTimer?.cancel();
    _accessTimer = Timer.periodic(const Duration(seconds: 12), (_) async {
      await ref.read(purchaseControllerProvider.notifier).syncFromBackend(userId);
      await _verifyUserAccess(userId);
    });
    ref.onDispose(() {
      _accessTimer?.cancel();
    });
  }

  Future<void> _verifyUserAccess(String userId) async {
    final status = await ref.read(authServiceProvider).checkUserAccess(userId);
    if (status == null) {
      _inactiveSessionStreak = 0;
      return;
    }
    if (status.isBlocked) {
      _inactiveSessionStreak = 0;
      await _applyForcedLogout(
        isBlocked: true,
        blockReason: "Siz admin tomonidan bloklangansiz. Admin: @${status.adminContact}",
      );
      return;
    }
    if (status.sessionActive) {
      _inactiveSessionStreak = 0;
      return;
    }
    _inactiveSessionStreak++;
    // Bir martalik server vaqtincha javobi uchun darhol chiqarib yubormaymiz.
    if (_inactiveSessionStreak < 4) return;

    _inactiveSessionStreak = 0;
    await _applyForcedLogout(
      isBlocked: false,
      blockReason: "Sessiya tugatildi. Qaytadan tizimga kiring.",
    );
  }

  Future<void> _applyForcedLogout({required bool isBlocked, required String blockReason}) async {
    await ref.read(authServiceProvider).signOut();
    ref.read(purchaseControllerProvider.notifier).clear();
    _hydratedUserId = null;
    state = AuthState(
      isLoggedIn: false,
      name: 'Mehmon',
      userId: null,
      email: null,
      isBlocked: isBlocked,
      blockReason: blockReason,
    );
  }

  AuthState _fromUser(LocalAuthUser user) {
    final guessedName = user.name.trim().isEmpty ? 'Ism yozmagansiz' : user.name;
    return AuthState(
      isLoggedIn: true,
      name: guessedName,
      userId: user.id,
      email: user.email,
      isBlocked: false,
      blockReason: null,
    );
  }

  Future<String?> login({
    required String phone,
    required String password,
    String? displayName,
  }) async {
    try {
      final user = await ref
          .read(authServiceProvider)
          .signIn(
            phone: phone.trim(),
            password: password.trim(),
            displayName: (displayName ?? '').trim(),
          );
      if (user == null) {
        return 'Telefon raqami noto‘g‘ri';
      }
      _inactiveSessionStreak = 0;
      state = _fromUser(user);
      ref.read(purchaseControllerProvider.notifier).bindRealtime(user.id);
      await ref.read(purchaseControllerProvider.notifier).syncFromBackend(user.id);
      return null;
    } on AuthServiceError catch (error) {
      if (error.message.toLowerCase().contains('blok')) {
        state = const AuthState(
          isLoggedIn: false,
          name: 'Mehmon',
          userId: null,
          email: null,
          isBlocked: true,
          blockReason: null,
        ).copyWith(blockReason: error.message);
      }
      return error.message;
    } catch (_) {
      return 'Xatolik yuz berdi. Qayta urinib ko‘ring';
    }
  }

  Future<void> updateName(String name) async {
    try {
      final updated = await ref.read(authServiceProvider).updateCurrentUserName(name);
      if (updated != null) {
        state = _fromUser(updated);
      }
    } on AuthServiceError {
      rethrow;
    }
  }

  Future<void> logout() async {
    _accessTimer?.cancel();
    _hydratedUserId = null;
    _inactiveSessionStreak = 0;
    await ref.read(authServiceProvider).signOut();
    ref.read(purchaseControllerProvider.notifier).clear();
    state = const AuthState(
      isLoggedIn: false,
      name: 'Mehmon',
      userId: null,
      email: null,
      isBlocked: false,
      blockReason: null,
    );
  }
}
