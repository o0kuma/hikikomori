import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../models/models.dart';
import '../services/api_client.dart';
import '../services/push_token_service.dart';
import '../services/snooze_controller.dart';
import '../services/snooze_notification_service.dart';

class SessionState extends ChangeNotifier {
  SessionState({ApiClient? api, AppDatabase? db, SnoozeNotificationScheduler? snoozeScheduler})
      : _api = api ?? ApiClient(),
        _db = db,
        _snoozeScheduler = snoozeScheduler ?? LocalSnoozeNotificationScheduler();

  final ApiClient _api;
  AppDatabase? _db;
  final SnoozeNotificationScheduler _snoozeScheduler;

  /// 답장 마감 알림(roadmap.md §2.7-F) 오케스트레이션 — DB(스누즈 시각)와 로컬 알림
  /// 스케줄러를 함께 다룬다. DB가 아직 열리지 않았으면(부팅 초기) null.
  SnoozeController? get snoozeController =>
      _db == null ? null : SnoozeController(db: _db!, scheduler: _snoozeScheduler);

  User? user;
  AutonomyLevel autonomyLevel = AutonomyLevel.L0;
  RelationshipTier relationshipTier = RelationshipTier.formal;
  String? error;
  bool loading = false;
  bool toneOnboardingDone = false;
  List<String> styleExamples = const [];
  bool localDbEncrypted = false;

  static const _kUserId = 'user_id';
  static const _kDisplayName = 'display_name';
  static const _kInvite = 'invite_code';
  static const _kToken = 'session_token';
  // Legacy SharedPreferences keys — migrated into encrypted drift on first open.
  static const _kToneDoneLegacy = 'tone_onboarding_done';
  static const _kStyleExamplesLegacy = 'style_examples_json';

  static const _kToneDone = 'tone_onboarding_done';
  static const _kDeviceInstallId = 'device_install_id';

  AppDatabase? get db => _db;

  Future<void> restore() async {
    _db ??= await _openDb();
    await _migrateLegacyTonePrefs();

    toneOnboardingDone = await _db!.getBoolKv(_kToneDone);
    styleExamples = await _db!.loadToneSamples();

    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_kUserId);
    final name = prefs.getString(_kDisplayName);
    final invite = prefs.getString(_kInvite);
    final token = prefs.getString(_kToken);
    if (id != null && name != null && invite != null) {
      user = User(id: id, displayName: name, inviteCode: invite);
      _api.authToken = token;
      await _registerDeviceTokenBestEffort();
      notifyListeners();
    }
  }

  Future<AppDatabase> _openDb() async {
    try {
      final db = await AppDatabase.open();
      localDbEncrypted = db.encrypted;
      return db;
    } catch (e) {
      // Linux CI / hosts without libsqlcipher.so — fall back to memory so the
      // app still boots; Android release path uses SQLCipher.
      // Web uses SharedPreferences-backed AppDatabase via conditional import
      // (docs/web-upgrade.md N4-W1); this catch is for native open failures.
      debugPrint('Encrypted DB unavailable ($e); using in-memory fallback');
      localDbEncrypted = false;
      return AppDatabase.memory();
    }
  }

  Future<void> _migrateLegacyTonePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final rawExamples = prefs.getString(_kStyleExamplesLegacy);
    final legacyDone = prefs.getBool(_kToneDoneLegacy);
    final existing = await _db!.loadToneSamples();
    if (existing.isEmpty && rawExamples != null && rawExamples.isNotEmpty) {
      final decoded = (jsonDecode(rawExamples) as List<dynamic>)
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
      if (decoded.isNotEmpty) {
        await _db!.replaceToneSamples(decoded);
      }
      await prefs.remove(_kStyleExamplesLegacy);
    }
    if (legacyDone != null) {
      await _db!.setBoolKv(_kToneDone, legacyDone);
      await prefs.remove(_kToneDoneLegacy);
    }
  }

  Future<void> signup(String inviteCode, String displayName) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _api.signup(inviteCode: inviteCode, displayName: displayName);
      await _persistAuth(result.user, result.token, resetToneOnboarding: true);
      await _registerDeviceTokenBestEffort();
    } on ApiException catch (e) {
      error = '가입 실패 (${e.statusCode}): ${e.body}';
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Q8b — already registered: invite code + display name → new session.
  Future<void> login(String inviteCode, String displayName) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final result = await _api.login(inviteCode: inviteCode, displayName: displayName);
      await _persistAuth(result.user, result.token, resetToneOnboarding: false);
      await _registerDeviceTokenBestEffort();
    } on ApiException catch (e) {
      error = '로그인 실패 (${e.statusCode}): ${e.body}';
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _persistAuth(User u, String token, {required bool resetToneOnboarding}) async {
    user = u;
    _api.authToken = token;
    _db ??= await _openDb();
    if (resetToneOnboarding) {
      toneOnboardingDone = false;
      await _db!.setBoolKv(_kToneDone, false);
    } else {
      toneOnboardingDone = await _db!.getBoolKv(_kToneDone);
      styleExamples = await _db!.loadToneSamples();
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kUserId, u.id);
    await prefs.setString(_kDisplayName, u.displayName);
    await prefs.setString(_kInvite, u.inviteCode);
    await prefs.setString(_kToken, token);
  }

  /// Q8c — revoke current server session when possible, then clear local auth.
  Future<void> logout() async {
    final u = user;
    final token = _api.authToken;
    if (u != null && token != null && token.isNotEmpty) {
      try {
        final sessions = await _api.listSessions(u.id);
        for (final s in sessions) {
          if (s['is_current'] == true && s['id'] is num) {
            await _api.revokeSession(u.id, (s['id'] as num).toInt());
            break;
          }
        }
      } catch (e) {
        debugPrint('logout revoke skipped: $e');
      }
    }
    user = null;
    error = null;
    _api.authToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kDisplayName);
    await prefs.remove(_kInvite);
    await prefs.remove(_kToken);
    notifyListeners();
  }

  Future<void> saveToneSamples(List<String> samples, {bool markDone = true}) async {
    final cleaned = samples.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    styleExamples = cleaned;
    if (markDone) toneOnboardingDone = true;
    _db ??= await _openDb();
    await _db!.replaceToneSamples(cleaned);
    if (markDone) await _db!.setBoolKv(_kToneDone, true);
    notifyListeners();
  }

  Future<void> skipToneOnboarding() async {
    toneOnboardingDone = true;
    _db ??= await _openDb();
    await _db!.setBoolKv(_kToneDone, true);
    notifyListeners();
  }

  Future<void> setAutonomy(AutonomyLevel level) async {
    if (user == null) return;
    try {
      final settings = await _api.patchTwinSettings(userId: user!.id, autonomyLevel: level);
      autonomyLevel = settings.autonomyLevel;
      relationshipTier = settings.relationshipTier;
      notifyListeners();
    } on ApiException catch (e) {
      error = '자율성 변경 실패 (${e.statusCode})';
      notifyListeners();
    }
  }

  /// 관계별 페르소나 전역 기본값 변경 (roadmap.md §2.7-B).
  Future<void> setRelationshipTier(RelationshipTier tier) async {
    if (user == null) return;
    try {
      final settings = await _api.patchTwinSettings(
        userId: user!.id,
        autonomyLevel: autonomyLevel,
        relationshipTier: tier,
      );
      autonomyLevel = settings.autonomyLevel;
      relationshipTier = settings.relationshipTier;
      notifyListeners();
    } on ApiException catch (e) {
      error = '관계 설정 변경 실패 (${e.statusCode})';
      notifyListeners();
    }
  }

  /// Registers a real FCM token when Firebase is configured; otherwise a stable
  /// `install:` placeholder (server skips placeholders for delivery).
  Future<void> _registerDeviceTokenBestEffort() async {
    if (user == null) return;
    try {
      _db ??= await _openDb();
      final resolved = await PushTokenService(
        readInstallId: () => _db!.getKv(_kDeviceInstallId),
        storeInstallId: (id) => _db!.setKv(_kDeviceInstallId, id),
      ).resolve();
      await _api.registerDeviceToken(
        userId: user!.id,
        token: resolved.token,
        platform: resolved.platform,
      );
      debugPrint(
        resolved.isFcm
            ? 'device token registered (FCM)'
            : 'device token registered (install placeholder)',
      );
    } catch (e) {
      debugPrint('device token register skipped: $e');
    }
  }

  ApiClient get api => _api;
}
