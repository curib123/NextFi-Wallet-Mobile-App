import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for ios - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.macOS:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for macos - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.windows:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for windows - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyADU2zo6kSPmnVeEwTAuKAz2vJz4L2CwTk',
    appId: '1:353191669623:web:54db86051d3eb73331fb72',
    messagingSenderId: '353191669623',
    projectId: 'nextfi-d6789',
    authDomain: 'nextfi-d6789.firebaseapp.com',
    storageBucket: 'nextfi-d6789.firebasestorage.app',
    measurementId: 'G-3V312MCPLL',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyC6dZV0yfHosuIO4AaPNiqYffisxTtvKz4',
    appId: '1:353191669623:android:9c21c5bc6e1db0bf31fb72',
    messagingSenderId: '353191669623',
    projectId: 'nextfi-d6789',
    storageBucket: 'nextfi-d6789.firebasestorage.app',
  );
}
