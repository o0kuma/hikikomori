import 'package:firebase_core/firebase_core.dart';

/// Firebase Web + VAPID settings injected at build time via `--dart-define`.
///
/// Never commit real values. Pass them through Docker build-args / `.env`
/// (see `.env.example` and `docs/fcm-setup.md` Web section).
class FirebaseWebConfig {
  const FirebaseWebConfig({
    required this.apiKey,
    required this.appId,
    required this.messagingSenderId,
    required this.projectId,
    required this.vapidKey,
    this.authDomain = '',
    this.storageBucket = '',
  });

  /// Reads compile-time defines (`FIREBASE_*`).
  factory FirebaseWebConfig.fromEnvironment() {
    return const FirebaseWebConfig(
      apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
      appId: String.fromEnvironment('FIREBASE_APP_ID'),
      messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
      projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
      vapidKey: String.fromEnvironment('FIREBASE_VAPID_KEY'),
      authDomain: String.fromEnvironment('FIREBASE_AUTH_DOMAIN'),
      storageBucket: String.fromEnvironment('FIREBASE_STORAGE_BUCKET'),
    );
  }

  final String apiKey;
  final String appId;
  final String messagingSenderId;
  final String projectId;
  final String vapidKey;
  final String authDomain;
  final String storageBucket;

  /// True when the minimum set for FCM Web token registration is present.
  bool get isReady =>
      apiKey.isNotEmpty &&
      appId.isNotEmpty &&
      messagingSenderId.isNotEmpty &&
      projectId.isNotEmpty &&
      vapidKey.isNotEmpty;

  /// [FirebaseOptions] for [Firebase.initializeApp], or null when not ready.
  FirebaseOptions? get options {
    if (!isReady) return null;
    final domain =
        authDomain.isNotEmpty ? authDomain : '$projectId.firebaseapp.com';
    final bucket = storageBucket.isNotEmpty
        ? storageBucket
        : '$projectId.appspot.com';
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      messagingSenderId: messagingSenderId,
      projectId: projectId,
      authDomain: domain,
      storageBucket: bucket,
    );
  }
}
