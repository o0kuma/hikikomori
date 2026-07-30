import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/app_database.dart';
import '../models/models.dart';
import '../services/api_client.dart';

class SessionState extends ChangeNotifier {
  SessionState({ApiClient? api, AppDatabase? db})
      : _api = api ?? ApiClient(),
        _db = db;

  final ApiClient _api;
  AppDatabase? _db;

  User? user;
  AutonomyLevel autonomyLevel = AutonomyLevel.L0;
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
      // Web uses an in-memory stub via conditional import (no FFI).
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
      user = result.user;
      toneOnboardingDone = false;
      _db ??= await _openDb();
      await _db!.setBoolKv(_kToneDone, false);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kUserId, result.user.id);
      await prefs.setString(_kDisplayName, result.user.displayName);
      await prefs.setString(_kInvite, result.user.inviteCode);
      await prefs.setString(_kToken, result.token);
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
      final settings = await _api.patchTwinSettings(user!.id, level);
      autonomyLevel = settings.autonomyLevel;
      notifyListeners();
    } on ApiException catch (e) {
      error = '자율성 변경 실패 (${e.statusCode})';
      notifyListeners();
    }
  }

  /// Registers a stable install id as the push token until Firebase Messaging
  /// is wired with a real FCM registration token (roadmap B).
  Future<void> _registerDeviceTokenBestEffort() async {
    if (user == null) return;
    try {
      _db ??= await _openDb();
      var installId = await _db!.getKv(_kDeviceInstallId);
      if (installId == null || installId.isEmpty) {
        final rand = Random.secure();
        installId = List.generate(16, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
        await _db!.setKv(_kDeviceInstallId, installId);
      }
      await _api.registerDeviceToken(
        userId: user!.id,
        token: 'install:$installId',
        platform: defaultTargetPlatform == TargetPlatform.android ? 'android' : 'other',
      );
    } catch (e) {
      debugPrint('device token register skipped: $e');
    }
  }

  ApiClient get api => _api;
}
