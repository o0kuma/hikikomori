import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// 답장 마감 알림(roadmap.md §2.7-F, PRD.md §3.2 "내가 '이따 답장' 누르면 나에게만
/// 리마인드")의 스케줄러 인터페이스. 다른 사람에게는 절대 보이지 않는, 이 기기에만
/// 존재하는 로컬 알림 — AGENTS.md 온디바이스 우선 원칙과 정확히 일치.
///
/// 이 세션의 샌드박스에는 실제 Android/iOS 기기·에뮬레이터가 없어 알림이 실제로
/// 뜨는지/탭했을 때의 동작까지는 검증할 수 없었다. 검증한 것은 `zonedSchedule()` /
/// `cancel()` 호출이 올바른 id·시각·페이로드로 이뤄지는가뿐이며, 이는 이 인터페이스의
/// 목(mock) 구현을 주입하는 단위 테스트(`test/snooze_notification_scheduler_test.dart`)로
/// 확인했다.
abstract class SnoozeNotificationScheduler {
  Future<void> scheduleReminder({
    required int conversationId,
    required String title,
    required String body,
    required DateTime at,
  });

  Future<void> cancelReminder(int conversationId);

  /// Immediate notification (web past-due catch-up). Native uses OS schedule only.
  Future<void> showImmediate({required String title, required String body}) async {}

  Future<bool> ensurePermission() async => true;
}

class LocalSnoozeNotificationScheduler implements SnoozeNotificationScheduler {
  LocalSnoozeNotificationScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static const _channelId = 'reply_snooze_reminders';
  static const _channelName = '답장 마감 알림';
  static const _channelDescription = '"이따 답장" 스누즈 마감 시각 알림 (본인 기기에만 표시, 상대에게는 보이지 않음)';

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _initialized = true;
  }

  @override
  Future<void> scheduleReminder({
    required int conversationId,
    required String title,
    required String body,
    required DateTime at,
  }) async {
    await _ensureInitialized();
    await _plugin.zonedSchedule(
      id: conversationId,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(at, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // SCHEDULE_EXACT_ALARM 권한 없이도 동작하는 모드 — 개인 리마인드 용도라
      // 초단위 정확도가 필요하지 않음 (Doze 모드에서도 결국은 전달됨).
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<void> cancelReminder(int conversationId) async {
    await _plugin.cancel(id: conversationId);
  }

  @override
  Future<void> showImmediate({required String title, required String body}) async {
    // Native path relies on zonedSchedule; no separate immediate channel here.
  }

  @override
  Future<bool> ensurePermission() async => true;
}
