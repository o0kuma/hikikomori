import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';
import '../services/api_client.dart';

class SessionState extends ChangeNotifier {
  SessionState({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  User? user;
  AutonomyLevel autonomyLevel = AutonomyLevel.L0;
  String? error;
  bool loading = false;
  bool toneOnboardingDone = false;
  List<String> styleExamples = const [];

  static const _kUserId = 'user_id';
  static const _kDisplayName = 'display_name';
  static const _kInvite = 'invite_code';
  static const _kToken = 'session_token';
  static const _kToneDone = 'tone_onboarding_done';
  static const _kStyleExamples = 'style_examples_json';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_kUserId);
    final name = prefs.getString(_kDisplayName);
    final invite = prefs.getString(_kInvite);
    final token = prefs.getString(_kToken);
    toneOnboardingDone = prefs.getBool(_kToneDone) ?? false;
    final rawExamples = prefs.getString(_kStyleExamples);
    if (rawExamples != null && rawExamples.isNotEmpty) {
      final decoded = jsonDecode(rawExamples) as List<dynamic>;
      styleExamples = decoded.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    }
    if (id != null && name != null && invite != null) {
      user = User(id: id, displayName: name, inviteCode: invite);
      _api.authToken = token;
      notifyListeners();
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kUserId, result.user.id);
      await prefs.setString(_kDisplayName, result.user.displayName);
      await prefs.setString(_kInvite, result.user.inviteCode);
      await prefs.setString(_kToken, result.token);
      await prefs.setBool(_kToneDone, false);
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kStyleExamples, jsonEncode(cleaned));
    if (markDone) await prefs.setBool(_kToneDone, true);
    notifyListeners();
  }

  Future<void> skipToneOnboarding() async {
    toneOnboardingDone = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kToneDone, true);
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

  ApiClient get api => _api;
}
