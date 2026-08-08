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
    apiKey: 'AIzaSyB5pGQchiOnyUwFwNKCox1D1IqdpJVjw6U',
    appId: '1:288949029713:android:0c6b1ee2a29a8663652170',
    messagingSenderId: '288949029713',
    projectId: 'neurosciense-9d6bc',
    storageBucket: 'neurosciense-9d6bc.firebasestorage.app',
  );
}
