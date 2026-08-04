import 'package:flutter_test/flutter_test.dart';
import 'package:ykavu_mobile/config/firebase_web_config.dart';

void main() {
  test('isReady false when any required field is empty', () {
    expect(
      const FirebaseWebConfig(
        apiKey: 'k',
        appId: 'a',
        messagingSenderId: '1',
        projectId: 'p',
        vapidKey: '',
      ).isReady,
      isFalse,
    );
    expect(
      const FirebaseWebConfig(
        apiKey: '',
        appId: 'a',
        messagingSenderId: '1',
        projectId: 'p',
        vapidKey: 'v',
      ).isReady,
      isFalse,
    );
  });

  test('isReady true and options fill default domains', () {
    const cfg = FirebaseWebConfig(
      apiKey: 'api',
      appId: '1:123:web:abc',
      messagingSenderId: '123',
      projectId: 'iykyka',
      vapidKey: 'vapid-public',
    );
    expect(cfg.isReady, isTrue);
    final opts = cfg.options!;
    expect(opts.apiKey, 'api');
    expect(opts.projectId, 'iykyka');
    expect(opts.authDomain, 'iykyka.firebaseapp.com');
    expect(opts.storageBucket, 'iykyka.appspot.com');
  });

  test('explicit authDomain and storageBucket win over defaults', () {
    const cfg = FirebaseWebConfig(
      apiKey: 'api',
      appId: '1:123:web:abc',
      messagingSenderId: '123',
      projectId: 'iykyka',
      vapidKey: 'vapid-public',
      authDomain: 'custom.example.com',
      storageBucket: 'iykyka.firebasestorage.app',
    );
    final opts = cfg.options!;
    expect(opts.authDomain, 'custom.example.com');
    expect(opts.storageBucket, 'iykyka.firebasestorage.app');
  });

  test('fromEnvironment without defines is not ready', () {
    expect(FirebaseWebConfig.fromEnvironment().isReady, isFalse);
    expect(FirebaseWebConfig.fromEnvironment().options, isNull);
  });
}
