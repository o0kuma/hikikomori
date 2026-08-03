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
  final Map<int, DateTime> _snoozes = {};

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

  // roadmap.md §2.7-F 답장 마감 알림 — native stub과 동일한 시그니처
  // (in-memory, encrypted persistence 없음 — web은 프리뷰 서피스일 뿐 릴리스 타깃이 아님).
  Future<void> setSnoozedUntil(int conversationId, DateTime until) async {
    _snoozes[conversationId] = until;
  }

  Future<DateTime?> getSnoozedUntil(int conversationId) async => _snoozes[conversationId];

  Future<void> clearSnooze(int conversationId) async {
    _snoozes.remove(conversationId);
  }

  Future<Map<int, DateTime>> loadAllSnoozes() async => Map<int, DateTime>.from(_snoozes);

  Future<void> close() async {}
}
