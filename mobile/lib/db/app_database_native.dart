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

part 'app_database_native.g.dart';

@DriftDatabase(tables: [ToneSamples, LocalKv, ConversationSnoozes])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e, {this.encrypted = false});

  /// True when backed by on-device SQLCipher (not memory / web stub).
  final bool encrypted;

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // v1 -> v2: roadmap.md §2.7-F 답장 마감 알림 스누즈 테이블 추가.
          if (from < 2) {
            await m.createTable(conversationSnoozes);
          }
        },
      );

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

  /// 답장 마감 알림(roadmap.md §2.7-F) — "이따 답장"으로 대화방 [conversationId]에
  /// 스누즈를 건다. 서버에는 전혀 전달되지 않는 순수 온디바이스 상태.
  Future<void> setSnoozedUntil(int conversationId, DateTime until) async {
    await into(conversationSnoozes).insertOnConflictUpdate(
      ConversationSnoozesCompanion.insert(
        conversationId: conversationId.toString(),
        snoozedUntilMs: until.millisecondsSinceEpoch,
      ),
    );
  }

  Future<DateTime?> getSnoozedUntil(int conversationId) async {
    final row = await (select(conversationSnoozes)
          ..where((t) => t.conversationId.equals(conversationId.toString())))
        .getSingleOrNull();
    if (row == null) return null;
    // isUtc: true — millisecondsSinceEpoch는 어차피 절대 시각이라 타임존 표현과
    // 무관하지만, UTC로 고정해야 DateTime.== 비교(테스트 포함)가 저장 전과 일관된다.
    return DateTime.fromMillisecondsSinceEpoch(row.snoozedUntilMs, isUtc: true);
  }

  Future<void> clearSnooze(int conversationId) async {
    await (delete(conversationSnoozes)
          ..where((t) => t.conversationId.equals(conversationId.toString())))
        .go();
  }

  /// 대화 목록 화면(`conversation_list_screen.dart`)에서 배지를 그리기 위한 일괄 로드.
  Future<Map<int, DateTime>> loadAllSnoozes() async {
    final rows = await select(conversationSnoozes).get();
    return {
      for (final r in rows)
        int.parse(r.conversationId): DateTime.fromMillisecondsSinceEpoch(r.snoozedUntilMs, isUtc: true),
    };
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
