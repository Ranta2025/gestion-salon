import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Returns the moment the "24h before" reminder for [appointmentAt] should
/// fire.
DateTime scheduleTimeFor(DateTime appointmentAt) =>
    appointmentAt.subtract(const Duration(hours: 24));

/// Whether it still makes sense to schedule a "24h before" reminder for
/// [appointmentAt].
///
/// The reminder time ([scheduleTimeFor]) must be strictly in the future
/// relative to [now] (defaults to [DateTime.now]). If the appointment is
/// less than 24h away — or already in the past — scheduling a "24h before"
/// notification would mean scheduling it in the past, which the plugin
/// would either fire immediately or reject. Callers should skip scheduling
/// in that case instead.
bool shouldSchedule(DateTime appointmentAt, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  return scheduleTimeFor(appointmentAt).isAfter(reference);
}

/// Wraps [FlutterLocalNotificationsPlugin] to schedule/cancel the "24h
/// before" appointment reminder. Offline-only: uses the device's local
/// timezone via `flutter_timezone` + `timezone`, no push/cloud service.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  static const String _channelId = 'appointment_reminders';
  static const String _channelName = 'Recordatorios de turnos';
  static const String _channelDescription =
      'Recordatorios 24 horas antes de un turno agendado';

  /// Initializes the plugin, wires the device's local timezone into the
  /// `timezone` package, and requests notification permissions.
  Future<void> init() async {
    tz_data.initializeTimeZones();
    final timezoneName = (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(timezoneName));

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _plugin.initialize(settings: initSettings);

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    // iOS/macOS permissions are requested during `initialize` above via
    // `DarwinInitializationSettings`' default `request*Permission` flags.
  }

  /// Requests the Android 12+ exact-alarm permission. The user may deny it —
  /// [scheduleAppointmentReminder] degrades gracefully to an inexact alarm
  /// mode in that case, so this must never block or throw on denial.
  Future<void> requestExactAlarmPermissionIfNeeded() async {
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();
  }

  /// Deterministically derives the OS notification id for an appointment so
  /// reminders can be found again for cancel/reschedule. `notification id`
  /// is a 32-bit int on Android; appointment primary keys are SQLite
  /// `INTEGER` rowids that fit comfortably within that range for this
  /// offline single-user app, so the appointment id is reused as-is.
  int _notificationIdFor(int appointmentId) => appointmentId;

  /// Schedules the "24h before" reminder for an appointment. Returns the
  /// notification id used (to persist on the `Appointment` record for later
  /// cancel/reschedule), or `null` if [shouldSchedule] says it's too late to
  /// schedule a meaningful reminder.
  Future<int?> scheduleAppointmentReminder({
    required int appointmentId,
    required DateTime appointmentAt,
    required String clientName,
    String? description,
  }) async {
    if (!shouldSchedule(appointmentAt)) return null;

    final notificationId = _notificationIdFor(appointmentId);
    final buffer = StringBuffer('Mañana tenés turno con $clientName');
    if (description != null && description.isNotEmpty) {
      buffer.write(' - $description');
    }

    var scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
    final canScheduleExact = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.canScheduleExactNotifications();
    if (canScheduleExact == false) {
      scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
    }

    await _plugin.zonedSchedule(
      id: notificationId,
      title: 'Recordatorio de turno',
      body: buffer.toString(),
      scheduledDate: tz.TZDateTime.from(scheduleTimeFor(appointmentAt), tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: scheduleMode,
    );

    return notificationId;
  }

  /// Cancels a previously scheduled reminder.
  Future<void> cancelReminder(int notificationId) =>
      _plugin.cancel(id: notificationId);
}
