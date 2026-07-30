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

  static const _kUserId = 'user_id';
  static const _kDisplayName = 'display_name';
  static const _kInvite = 'invite_code';

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt(_kUserId);
    final name = prefs.getString(_kDisplayName);
    final invite = prefs.getString(_kInvite);
    if (id != null && name != null && invite != null) {
      user = User(id: id, displayName: name, inviteCode: invite);
      notifyListeners();
    }
  }

  Future<void> signup(String inviteCode, String displayName) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final created = await _api.signup(inviteCode: inviteCode, displayName: displayName);
      user = created;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_kUserId, created.id);
      await prefs.setString(_kDisplayName, created.displayName);
      await prefs.setString(_kInvite, created.inviteCode);
    } on ApiException catch (e) {
      error = '가입 실패 (${e.statusCode}): ${e.body}';
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
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
