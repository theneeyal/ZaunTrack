// File generated by FlutterFire CLI.
// ignore_for_file: type=lint
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
///
/// Example:
/// ```dart
/// import 'firebase_options.dart';
/// // ...
/// await Firebase.initializeApp(
///   options: DefaultFirebaseOptions.currentPlatform,
/// );
/// ```
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
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
    apiKey: 'AIzaSyCAyDKacevhBzUP_4zo9sZWClm5LFinBzo',
    appId: '1:409444266908:web:7ae1eedd9209985a6e0e59',
    messagingSenderId: '409444266908',
    projectId: 'zauntrack-c7a21',
    authDomain: 'zauntrack-c7a21.firebaseapp.com',
    storageBucket: 'zauntrack-c7a21.appspot.com',
    measurementId: 'G-4M2PN1Q6ZZ',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDzCSoFI12a4vaSL64NHJdUyOo1l6Xpf9Y',
    appId: '1:409444266908:android:1f01b88d3c3b98376e0e59',
    messagingSenderId: '409444266908',
    projectId: 'zauntrack-c7a21',
    storageBucket: 'zauntrack-c7a21.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDZZeJpE5mZUPy5oDSo5cWS9raAwwp2pRo',
    appId: '1:409444266908:ios:eb81e5ac90e674556e0e59',
    messagingSenderId: '409444266908',
    projectId: 'zauntrack-c7a21',
    storageBucket: 'zauntrack-c7a21.appspot.com',
    iosBundleId: 'com.example.myFlutterApp',
  );

  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyDZZeJpE5mZUPy5oDSo5cWS9raAwwp2pRo',
    appId: '1:409444266908:ios:eb81e5ac90e674556e0e59',
    messagingSenderId: '409444266908',
    projectId: 'zauntrack-c7a21',
    storageBucket: 'zauntrack-c7a21.appspot.com',
    iosBundleId: 'com.example.myFlutterApp',
  );

  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCAyDKacevhBzUP_4zo9sZWClm5LFinBzo',
    appId: '1:409444266908:web:54b75b2147a1b3cc6e0e59',
    messagingSenderId: '409444266908',
    projectId: 'zauntrack-c7a21',
    authDomain: 'zauntrack-c7a21.firebaseapp.com',
    storageBucket: 'zauntrack-c7a21.appspot.com',
    measurementId: 'G-W1WQNFHGV5',
  );

}