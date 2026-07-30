/// Web/Chrome stub for [AppDatabase].
///
/// SQLCipher / dart:ffi cannot compile for Flutter Web. Chrome runs use an
/// in-tab memory map so UI + API flows still work. Persistence is not encrypted
/// and is lost on refresh (web is a preview surface, not the release target).
class AppDatabase {
  AppDatabase({this.encrypted = false});

  /// Always false on web — there is no SQLCipher path.
  final bool encrypted;

  final Map<String, String> _kv = {};
  List<String> _toneSamples = [];

  factory AppDatabase.memory() => AppDatabase(encrypted: false);

  static Future<AppDatabase> open() async => AppDatabase(encrypted: false);

  Future<List<String>> loadToneSamples() async => List<String>.from(_toneSamples);

  Future<void> replaceToneSamples(List<String> samples) async {
    _toneSamples = List<String>.from(samples);
  }

  Future<String?> getKv(String key) async => _kv[key];

  Future<void> setKv(String key, String value) async {
    _kv[key] = value;
  }

  Future<bool> getBoolKv(String key, {bool defaultValue = false}) async {
    final v = await getKv(key);
    if (v == null) return defaultValue;
    return v == '1' || v.toLowerCase() == 'true';
  }

  Future<void> setBoolKv(String key, bool value) async {
    await setKv(key, value ? '1' : '0');
  }

  Future<void> close() async {}
}
