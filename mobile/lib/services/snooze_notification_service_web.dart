import 'dart:async';
// Web-only conditional import target (see snooze_notification_service.dart).
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Web reminder scheduler (docs/web-upgrade.md N4-W3).
///
/// Uses the browser Notification API when permission is granted. Scheduling is
/// in-tab [Timer]-based (no SW alarm) — if the tab is closed before [at], the
/// in-app past-due badge/banner remains the source of truth after reopen.
abstract class SnoozeNotificationScheduler {
  Future<void> scheduleReminder({
    required int conversationId,
    required String title,
    required String body,
    required DateTime at,
  });

  Future<void> cancelReminder(int conversationId);

  Future<void> showImmediate({required String title, required String body});

  Future<bool> ensurePermission();
}

class LocalSnoozeNotificationScheduler implements SnoozeNotificationScheduler {
  final Map<int, Timer> _timers = {};

  bool get permissionGranted {
    try {
      return html.Notification.permission == 'granted';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<bool> ensurePermission() async {
    try {
      final current = html.Notification.permission;
      if (current == 'granted') return true;
      if (current == 'denied') return false;
      final result = await html.Notification.requestPermission();
      return result == 'granted';
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> showImmediate({required String title, required String body}) async {
    try {
      if (!permissionGranted) return;
      html.Notification(title, body: body);
    } catch (_) {
      // Unsupported browser — ignore.
    }
  }

  @override
  Future<void> scheduleReminder({
    required int conversationId,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    await ensurePermission();
    await cancelReminder(conversationId);
    final delay = at.toUtc().difference(DateTime.now().toUtc());
    if (delay.isNegative || delay == Duration.zero) {
      await showImmediate(title: title, body: body);
      return;
    }
    _timers[conversationId] = Timer(delay, () {
      _timers.remove(conversationId);
      showImmediate(title: title, body: body);
    });
  }

  @override
  Future<void> cancelReminder(int conversationId) async {
    _timers.remove(conversationId)?.cancel();
  }
}
