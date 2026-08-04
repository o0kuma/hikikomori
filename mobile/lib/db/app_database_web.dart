import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Web/Chrome [AppDatabase] backed by [SharedPreferences] (IndexedDB under the hood).
///
/// SQLCipher / dart:ffi cannot compile for Flutter Web. Persistence is
/// **not encrypted** — acceptable for the demo/preview surface
/// (`docs/web-upgrade.md` N4-W1). Drift WASM is intentionally not used.
///
/// [AppDatabase.memory] stays ephemeral (unit tests / fallbacks).
class AppDatabase {
  AppDatabase({
    this.encrypted = false,
    SharedPreferences? prefs,
    bool persist = false,
  })  : _prefs = prefs,
        _persist = persist && prefs != null;

  /// Always false on web — there is no SQLCipher path.
  final bool encrypted;

  final SharedPreferences? _prefs;
  final bool _persist;

  final Map<String, String> _kv = {};
  List<String> _toneSamples = [];
  final Map<int, DateTime> _snoozes = {};

  static const _kTone = 'ykavu_web_db_tone_samples';
  static const _kSnoozes = 'ykavu_web_db_snoozes';
  static const _kvPrefix = 'ykavu_web_db_kv_';

  factory AppDatabase.memory() => AppDatabase(encrypted: false, persist: false);

  /// Opens a durable preview DB (survives hard refresh in the same browser profile).
  static Future<AppDatabase> open() async {
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(encrypted: false, prefs: prefs, persist: true);
    await db._hydrate();
    return db;
  }

  Future<void> _hydrate() async {
    final prefs = _prefs;
    if (!_persist || prefs == null) return;

    try {
      final toneRaw = prefs.getString(_kTone);
      if (toneRaw != null && toneRaw.isNotEmpty) {
        final decoded = jsonDecode(toneRaw);
        if (decoded is List) {
          _toneSamples = decoded.map((e) => e.toString()).toList();
        }
      }
    } catch (_) {
      _toneSamples = [];
      await prefs.remove(_kTone);
    }

    try {
      final snoozeRaw = prefs.getString(_kSnoozes);
      if (snoozeRaw != null && snoozeRaw.isNotEmpty) {
        final decoded = jsonDecode(snoozeRaw);
        if (decoded is Map) {
          _snoozes
            ..clear()
            ..addEntries(
              decoded.entries.map((e) {
                final id = int.tryParse(e.key.toString());
                final ms = e.value is int
                    ? e.value as int
                    : int.tryParse(e.value.toString());
                if (id == null || ms == null) return null;
                return MapEntry(id, DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true));
              }).whereType<MapEntry<int, DateTime>>(),
            );
        }
      }
    } catch (_) {
      _snoozes.clear();
      await prefs.remove(_kSnoozes);
    }

    for (final key in prefs.getKeys()) {
      if (!key.startsWith(_kvPrefix)) continue;
      final logical = key.substring(_kvPrefix.length);
      final value = prefs.getString(key);
      if (value != null) _kv[logical] = value;
    }
  }

  Future<void> _persistTone() async {
    if (!_persist || _prefs == null) return;
    await _prefs.setString(_kTone, jsonEncode(_toneSamples));
  }

  Future<void> _persistSnoozes() async {
    if (!_persist || _prefs == null) return;
    final map = <String, int>{
      for (final e in _snoozes.entries) e.key.toString(): e.value.toUtc().millisecondsSinceEpoch,
    };
    await _prefs.setString(_kSnoozes, jsonEncode(map));
  }

  Future<void> _persistKv(String key, String value) async {
    if (!_persist || _prefs == null) return;
    await _prefs.setString('$_kvPrefix$key', value);
  }

  Future<List<String>> loadToneSamples() async => List<String>.from(_toneSamples);

  Future<void> replaceToneSamples(List<String> samples) async {
    _toneSamples = List<String>.from(samples);
    await _persistTone();
  }

  Future<String?> getKv(String key) async => _kv[key];

  Future<void> setKv(String key, String value) async {
    _kv[key] = value;
    await _persistKv(key, value);
  }

  Future<bool> getBoolKv(String key, {bool defaultValue = false}) async {
    final v = await getKv(key);
    if (v == null) return defaultValue;
    return v == '1' || v.toLowerCase() == 'true';
  }

  Future<void> setBoolKv(String key, bool value) async {
    await setKv(key, value ? '1' : '0');
  }

  /// roadmap.md §2.7-F — on-device snooze; web preview persists via SharedPreferences.
  Future<void> setSnoozedUntil(int conversationId, DateTime until) async {
    _snoozes[conversationId] = until.toUtc();
    await _persistSnoozes();
  }

  Future<DateTime?> getSnoozedUntil(int conversationId) async => _snoozes[conversationId];

  Future<void> clearSnooze(int conversationId) async {
    _snoozes.remove(conversationId);
    await _persistSnoozes();
  }

  Future<Map<int, DateTime>> loadAllSnoozes() async => Map<int, DateTime>.from(_snoozes);

  Future<void> close() async {}
}
