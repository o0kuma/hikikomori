import 'dart:ffi';
import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';
import 'package:sqlite3/open.dart';

import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [ToneSamples, LocalKv])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e, {this.encrypted = false});

  /// True when backed by on-device SQLCipher (not memory / web stub).
  final bool encrypted;

  @override
  int get schemaVersion => 1;

  /// In-memory DB for unit tests (no SQLCipher / filesystem).
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory(), encrypted: false);

  /// Production opener: encrypted on-device file (tech-design.md §8).
  static Future<AppDatabase> open() async {
    final db = AppDatabase(_openEncryptedExecutor(), encrypted: true);
    // Force open so missing SQLCipher SO fails here (caller can fall back).
    await db.customSelect('SELECT 1').get();
    return db;
  }

  Future<List<String>> loadToneSamples() async {
    final rows = await (select(toneSamples)..orderBy([(t) => OrderingTerm.asc(t.sortOrder)])).get();
    return rows.map((r) => r.sampleText).toList();
  }

  Future<void> replaceToneSamples(List<String> samples) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await transaction(() async {
      await delete(toneSamples).go();
      for (var i = 0; i < samples.length; i++) {
        await into(toneSamples).insert(
          ToneSamplesCompanion.insert(
            id: 'tone_${i}_$now',
            sampleText: samples[i],
            createdAtMs: now,
            sortOrder: i,
          ),
        );
      }
    });
  }

  Future<String?> getKv(String key) async {
    final row = await (select(localKv)..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> setKv(String key, String value) async {
    await into(localKv).insertOnConflictUpdate(LocalKvCompanion.insert(key: key, value: value));
  }

  Future<bool> getBoolKv(String key, {bool defaultValue = false}) async {
    final v = await getKv(key);
    if (v == null) return defaultValue;
    return v == '1' || v.toLowerCase() == 'true';
  }

  Future<void> setBoolKv(String key, bool value) async {
    await setKv(key, value ? '1' : '0');
  }
}

const _kDbPassphrase = 'db_passphrase_v1';

QueryExecutor _openEncryptedExecutor() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'ykavu_encrypted.db'));
    final passphrase = await _loadOrCreatePassphrase();

    // Background isolate does not inherit open.overrideFor — re-apply there.
    final token = RootIsolateToken.instance;
    return NativeDatabase.createInBackground(
      file,
      isolateSetup: () async {
        if (token != null) {
          BackgroundIsolateBinaryMessenger.ensureInitialized(token);
        }
        await _configureSqlCipherOpen();
      },
      setup: (rawDb) {
        // SQLCipher key must be set before any other statement.
        final escaped = passphrase.replaceAll("'", "''");
        rawDb.execute("PRAGMA key = '$escaped'");
        rawDb.config.doubleQuotedStringLiterals = false;
      },
    );
  });
}

Future<void> _configureSqlCipherOpen() async {
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();
    open.overrideFor(OperatingSystem.android, openCipherOnAndroid);
  } else if (Platform.isLinux) {
    // Desktop/dev: try SQLCipher SO; fall back is handled by open() failure upstream.
    open.overrideFor(OperatingSystem.linux, () => DynamicLibrary.open('libsqlcipher.so'));
  } else if (Platform.isWindows) {
    open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open('sqlcipher.dll'));
  }
  // iOS/macOS: sqlcipher_flutter_libs links into the process.
}

Future<String> _loadOrCreatePassphrase() async {
  const storage = FlutterSecureStorage();
  final existing = await storage.read(key: _kDbPassphrase);
  if (existing != null && existing.isNotEmpty) return existing;
  final rand = Random.secure();
  final bytes = List<int>.generate(32, (_) => rand.nextInt(256));
  final passphrase = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  await storage.write(key: _kDbPassphrase, value: passphrase);
  return passphrase;
}
