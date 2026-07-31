import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

/// Resolves a device push token for core-backend registration.
///
/// Prefer a real FCM registration token when Firebase is configured
/// (`google-services.json` on Android). Otherwise fall back to a stable
/// `install:` placeholder that the server intentionally skips for delivery.
class PushTokenService {
  PushTokenService({this.storeInstallId, this.readInstallId});

  /// Persist a newly generated install id (KV / secure storage).
  final Future<void> Function(String installId)? storeInstallId;

  /// Load a previously stored install id.
  final Future<String?> Function()? readInstallId;

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
    // Web push needs a separate Firebase web config + VAPID; skip until provided.
    if (kIsWeb) return null;
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
