import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class StartupGuard extends StatefulWidget {
  const StartupGuard({super.key, required this.child});

  final Widget child;

  @override
  State<StartupGuard> createState() => _StartupGuardState();
}

class _StartupGuardState extends State<StartupGuard> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<dynamic>? _subscription;
  bool _hasInternet = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkInternet();
    await _requestNotificationPermission();
    _subscription = _connectivity.onConnectivityChanged.listen((result) {
      final next = _hasNetwork(result);
      if (!mounted || next == _hasInternet) return;
      setState(() => _hasInternet = next);
    });
  }

  bool _hasNetwork(dynamic result) {
    if (result is List<ConnectivityResult>) {
      return !result.contains(ConnectivityResult.none);
    }
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    return true;
  }

  Future<void> _checkInternet() async {
    final result = await _connectivity.checkConnectivity();
    if (!mounted) return;
    setState(() => _hasInternet = _hasNetwork(result));
  }

  Future<void> _requestNotificationPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) return;
    final status = await Permission.notification.status;
    if (status.isGranted || status.isPermanentlyDenied) return;
    await Permission.notification.request();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasInternet) return widget.child;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.wifi_off_rounded, size: 52, color: Color(0xFF1E6BB8)),
              const SizedBox(height: 12),
              const Text(
                "Internet yo'q. Iltimos internetni yoqing.",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _checkInternet,
                child: const Text("Qayta tekshirish"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
