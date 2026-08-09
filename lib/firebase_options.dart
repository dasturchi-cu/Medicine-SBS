import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Android qiymatlari [android/app/google-services.json] bilan mos kelishi kerak.
/// iOS uchun Firebase Console dan iOS ilova qo‘shib `flutterfire configure` yoki [GoogleService-Info.plist] dan appId kiriting.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'FCM hozircha faqat Androidda yoqilgan. iOS uchun keyinroq '
          '`flutterfire configure` va GoogleService-Info.plist qo‘shing.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBmCYZY5_UTHjhI7XloUe2Cx-VaLK1tGCY',
    appId: '1:591722198488:android:66f0cba15a3539e4f4eead',
    messagingSenderId: '591722198488',
    projectId: 'medicine-de76e',
    storageBucket: 'medicine-de76e.firebasestorage.app',
  );
}
