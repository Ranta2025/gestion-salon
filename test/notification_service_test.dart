import 'package:flutter_test/flutter_test.dart';
import 'package:gestion_salon/services/notification_service.dart';

/// Pure DateTime-math tests for the "24h before" reminder rules. No plugin,
/// no platform channel, no mocking — plain `DateTime` assertions, matching
/// this project's convention of testing logic without a widget/plugin
/// harness (see odd/tasks/agendar-citas.md).
void main() {
  group('scheduleTimeFor', () {
    test('returns exactly 24 hours before the appointment', () {
      final appointmentAt = DateTime(2026, 9, 25, 15, 0);
      final result = scheduleTimeFor(appointmentAt);
      expect(result, DateTime(2026, 9, 24, 15, 0));
    });
  });

  group('shouldSchedule', () {
    test('true when the appointment is 48h away', () {
      final now = DateTime(2026, 9, 19, 12, 0);
      final appointmentAt = now.add(const Duration(hours: 48));
      expect(shouldSchedule(appointmentAt, now: now), isTrue);
    });

    test('false when the appointment is only 2h away', () {
      final now = DateTime(2026, 9, 19, 12, 0);
      final appointmentAt = now.add(const Duration(hours: 2));
      expect(shouldSchedule(appointmentAt, now: now), isFalse);
    });

    test('false when the appointment is already in the past', () {
      final now = DateTime(2026, 9, 19, 12, 0);
      final appointmentAt = now.subtract(const Duration(hours: 1));
      expect(shouldSchedule(appointmentAt, now: now), isFalse);
    });

    test(
        'boundary: false when the 24h-before mark is exactly now '
        '(appointment exactly 24h away)', () {
      final now = DateTime(2026, 9, 19, 12, 0);
      final appointmentAt = now.add(const Duration(hours: 24));
      // scheduleTimeFor(appointmentAt) == now, which is not strictly in the
      // future relative to now, so scheduling makes no sense.
      expect(shouldSchedule(appointmentAt, now: now), isFalse);
    });

    test('true when the 24h-before mark is one second in the future', () {
      final now = DateTime(2026, 9, 19, 12, 0);
      final appointmentAt =
          now.add(const Duration(hours: 24, seconds: 1));
      expect(shouldSchedule(appointmentAt, now: now), isTrue);
    });

    test('defaults `now` to DateTime.now() when not provided', () {
      final appointmentAt = DateTime.now().add(const Duration(hours: 48));
      expect(shouldSchedule(appointmentAt), isTrue);
    });
  });
}
