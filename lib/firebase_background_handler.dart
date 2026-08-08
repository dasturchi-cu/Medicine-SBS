import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isNotEmpty) return;
  if (!Platform.isAndroid) return;
  try {
    await Firebase.initializeApp();
  } catch (_) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.android);
  }
}
