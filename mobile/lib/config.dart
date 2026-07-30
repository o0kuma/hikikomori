/// Runtime config for talking to `core-backend/`.
///
/// Override at run time with:
/// `flutter run --dart-define=CORE_API_BASE=http://10.0.2.2:8080`
class AppConfig {
  static const coreApiBase = String.fromEnvironment(
    'CORE_API_BASE',
    defaultValue: 'http://10.0.2.2:8080', // Android emulator → host localhost
  );

  static String wsBase() {
    final uri = Uri.parse(coreApiBase);
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }
}
