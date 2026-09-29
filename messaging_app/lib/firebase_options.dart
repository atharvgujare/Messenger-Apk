// File generated for Messenger Firebase configuration.
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
        return ios;
      default:
        return android;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCDPmtspCcj-2u6kqhjpaLL6llqX7kARpQ',
    appId: '1:537348766734:web:b9cc129988bef98d9e905f',
    messagingSenderId: '537348766734',
    projectId: 'messenger-bce30',
    authDomain: 'messenger-bce30.firebaseapp.com',
    storageBucket: 'messenger-bce30.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCDPmtspCcj-2u6kqhjpaLL6llqX7kARpQ',
    appId: '1:537348766734:android:b9cc129988bef98d9e905f',
    messagingSenderId: '537348766734',
    projectId: 'messenger-bce30',
    storageBucket: 'messenger-bce30.firebasestorage.app',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyCDPmtspCcj-2u6kqhjpaLL6llqX7kARpQ',
    appId: '1:537348766734:ios:b9cc129988bef98d9e905f',
    messagingSenderId: '537348766734',
    projectId: 'messenger-bce30',
    storageBucket: 'messenger-bce30.firebasestorage.app',
  );
}
