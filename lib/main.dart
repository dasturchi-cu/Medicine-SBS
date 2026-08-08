import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/localization/language_provider.dart';
import 'core/services/auth_service.dart';
import 'core/services/catalog_service.dart';
import 'core/services/push_messaging.dart';
import 'core/theme/app_theme.dart';
import 'core/widgets/startup_guard.dart';
import 'firebase_background_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final firebaseOk = await ensureFirebaseCoreInitialized();
  if (firebaseOk && Firebase.apps.isNotEmpty) {
    try {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    } catch (e) {
      debugPrint(
        'FirebaseMessaging.onBackgroundMessage — ehtimoliy takror (Hot Restart): $e',
      );
    }
  }

  await AuthService.bootstrap();
  await CatalogService.bootstrap(maxAttempts: 5);
  runApp(
    const ProviderScope(
      child: FirebasePushBootstrap(child: NeuroscienceApp()),
    ),
  );
}

class NeuroscienceApp extends ConsumerWidget {
  const NeuroscienceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locAsync = ref.watch(localizationProvider);

    return locAsync.when(
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: StartupLoadingScreen(
          onRetry: () => ref.invalidate(localizationProvider),
        ),
      ),
      error: (e, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: Scaffold(body: Center(child: Text(e.toString()))),
      ),
      data: (st) {
        return MaterialApp.router(
          debugShowCheckedModeBanner: false,
          title: translate(st, 'app_name'),
          theme: AppTheme.light(),
          routerConfig: router,
          locale: Locale(st.langCode),
          supportedLocales: const [Locale('uz'), Locale('ru'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          builder: (context, child) {
            return StartupGuard(
              child: PushRouterScope(
                router: router,
                child: TrScope(
                  state: st,
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class StartupLoadingScreen extends StatefulWidget {
  const StartupLoadingScreen({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  State<StartupLoadingScreen> createState() => _StartupLoadingScreenState();
}

class _StartupLoadingScreenState extends State<StartupLoadingScreen> {
  bool _showFallback = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _showFallback = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 14),
              Text(
                _showFallback
                    ? "Ilova sekin yuklanmoqda. Internetni tekshirib qayta urinib ko'ring."
                    : "Ilova yuklanmoqda...",
                textAlign: TextAlign.center,
              ),
              if (_showFallback) ...[
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: widget.onRetry,
                  child: const Text("Qayta urinish"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
