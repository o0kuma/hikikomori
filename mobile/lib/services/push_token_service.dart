import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_web_config.dart';

/// Resolves a device push token for core-backend registration.
///
/// Prefer a real FCM registration token when Firebase is configured
/// (`google-services.json` on Android, dart-define Web config + VAPID on web).
/// Otherwise fall back to a stable `install:` placeholder that the server
/// intentionally skips for delivery.
class PushTokenService {
  PushTokenService({
    this.storeInstallId,
    this.readInstallId,
    FirebaseWebConfig? webConfig,
  }) : webConfig = webConfig ?? FirebaseWebConfig.fromEnvironment();

  /// Persist a newly generated install id (KV / secure storage).
  final Future<void> Function(String installId)? storeInstallId;

  /// Load a previously stored install id.
  final Future<String?> Function()? readInstallId;

  /// Injected for tests; production uses [FirebaseWebConfig.fromEnvironment].
  final FirebaseWebConfig webConfig;

  Future<({String token, String platform, bool isFcm})> resolve() async {
    final platform = _platformLabel();
    final fcm = await _tryFirebaseToken();
    if (fcm != null && fcm.isNotEmpty) {
      return (token: fcm, platform: platform, isFcm: true);
    }
    final installId = await _ensureInstallId();
    return (token: 'install:$installId', platform: platform, isFcm: false);
  }

  Future<String?> _tryFirebaseToken() async {
    if (kIsWeb) {
      return _tryFirebaseWebToken();
    }
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return null;
    }
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (token == null || token.isEmpty) return null;
      return token;
    } catch (e) {
      debugPrint('FCM token unavailable (using install placeholder): $e');
      return null;
    }
  }

  /// N4-W4 — Web Push via FCM + VAPID (build-time dart-define secrets).
  Future<String?> _tryFirebaseWebToken() async {
    if (!webConfig.isReady) {
      debugPrint(
        'FCM web skipped: FIREBASE_* / VAPID dart-defines not set '
        '(see docs/fcm-setup.md Web)',
      );
      return null;
    }
    try {
      final options = webConfig.options!;
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: options);
      }
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken(vapidKey: webConfig.vapidKey);
      if (token == null || token.isEmpty) return null;
      return token;
    } catch (e) {
      debugPrint('FCM web token unavailable (using install placeholder): $e');
      return null;
    }
  }

  Future<String> _ensureInstallId() async {
    final existing = await readInstallId?.call();
    if (existing != null && existing.isNotEmpty) return existing;
    final rand = Random.secure();
    final installId =
        List.generate(16, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
    await storeInstallId?.call(installId);
    return installId;
  }

  String _platformLabel() {
    if (kIsWeb) return 'web';
    if (defaultTargetPlatform == TargetPlatform.android) return 'android';
    if (defaultTargetPlatform == TargetPlatform.iOS) return 'ios';
    return 'other';
  }
}
