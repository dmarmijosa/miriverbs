import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps in this project.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError(
        'DefaultFirebaseOptions have not been configured for web - '
        'you can reconfigure this by running the FlutterFire CLI.',
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCWSUcCeQvs_83JQwsrnw-2CLUMvavcvP8',
    appId: '1:481557558534:android:4adff657fb95c9af32da87',
    messagingSenderId: '481557558534',
    projectId: 'miri-verbs',
    storageBucket: 'miri-verbs.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyC3da1gKA8ZGXbHXC1VVk0BhMdM5FjCmVo',
    appId: '1:481557558534:ios:05936c8cf97c0d0e32da87',
    messagingSenderId: '481557558534',
    projectId: 'miri-verbs',
    storageBucket: 'miri-verbs.firebasestorage.app',
    iosClientId: '481557558534-2fpuem13he1i1em1hcvkvm82qrglclj5.apps.googleusercontent.com',
    iosBundleId: 'com.nexacode.miriverbs',
  );
}
