import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/appointment_repository.dart';
import '../../data/repositories/movement_repository.dart';
import '../../core/utils/date_helpers.dart';
import '../../services/notification_service.dart';

class AppointmentsController extends ChangeNotifier {
  final AppointmentRepository _repository;
  final NotificationService _notificationService;
  final MovementRepository _movementRepository;

  AppointmentsController({
    AppointmentRepository? repository,
    NotificationService? notificationService,
    MovementRepository? movementRepository,
  })  : _repository = repository ?? AppointmentRepository(),
        _notificationService = notificationService ?? NotificationService(),
        _movementRepository = movementRepository ?? MovementRepository();

  List<Appointment> upcoming = const [];
  List<Appointment> history = const [];
  bool loading = true;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    upcoming = await _repository.upcoming();
    history = await _repository.all();
    loading = false;
    notifyListeners();
  }

  Future<int> add(Appointment appointment, {required String clientName}) async {
    final id = await _repository.insert(appointment);

    // Notification scheduling may fail (permissions denied, platform channel
    // issues, etc. — see NotificationService/main.dart for the same failure
    // mode). The appointment is already persisted at this point, so a
    // scheduling failure must not propagate: losing the reminder is an
    // acceptable degradation, losing the appointment or leaving in-memory
    // state stale relative to the database is not.
    try {
      final notificationId =
          await _notificationService.scheduleAppointmentReminder(
        appointmentId: id,
        appointmentAt: appointment.dateTime,
        clientName: clientName,
        description: appointment.description,
      );
      if (notificationId != null) {
        await _repository.update(
          appointment.copyWith(id: id, notificationId: notificationId),
        );
      }
    } catch (_) {
      // No reminder will fire for this appointment, but it stays saved.
    }

    await refresh();
    return id;
  }

  /// Persists an edited [appointment] (client/date-time/description changed
  /// by the user; `id` is non-null since this always edits an existing
  /// appointment). Status is never touched here — that's `cancel`/`complete`'s
  /// job.
  ///
  /// If `dateTime` changed relative to the previously stored appointment,
  /// any live reminder is cancelled (best-effort, same as elsewhere in this
  /// file) and a new one is scheduled for the new `dateTime` (also
  /// best-effort, same as [add]) — the resulting `notificationId` (possibly
  /// `null`, if `shouldSchedule` rejects the new time) is what gets
  /// persisted. If `dateTime` did not change, the existing `notificationId`
  /// is left untouched.
  Future<void> update(
    Appointment appointment, {
    required String clientName,
  }) async {
    final id = appointment.id!;
    final previous = await _repository.byId(id);
    if (previous == null) return;

    var notificationId = previous.notificationId;
    final dateTimeChanged = DateHelpers.dateTimeKey(appointment.dateTime) !=
        DateHelpers.dateTimeKey(previous.dateTime);

    if (dateTimeChanged) {
      if (previous.notificationId != null) {
        try {
          await _notificationService.cancelReminder(previous.notificationId!);
        } catch (_) {
          // No live reminder will be cancelled, but the edit proceeds.
        }
      }
      try {
        notificationId = await _notificationService.scheduleAppointmentReminder(
          appointmentId: id,
          appointmentAt: appointment.dateTime,
          clientName: clientName,
          description: appointment.description,
        );
      } catch (_) {
        // No reminder will fire for the new time, but the edit proceeds.
        notificationId = null;
      }
    }

    await _repository.update(
      Appointment(
        id: id,
        clientId: appointment.clientId,
        dateTime: appointment.dateTime,
        description: appointment.description,
        notificationId: notificationId,
        createdAt: previous.createdAt,
        status: previous.status,
        clientName: appointment.clientName,
      ),
    );
    await refresh();
  }

  Future<void> delete(int id) async {
    final appointment = await _repository.byId(id);
    if (appointment?.notificationId != null) {
      await _notificationService.cancelReminder(appointment!.notificationId!);
    }
    await _repository.delete(id);
    await refresh();
  }

  Future<void> cancel(int id) => _setStatus(id, AppointmentStatus.cancelled);

  /// Marks appointment [id] as completed and records the real business
  /// event behind it: the client was charged [amountCharged] for it. Unlike
  /// the notification-scheduling failures elsewhere in this file, the
  /// `Movement` insert below is NOT best-effort — if it throws, the
  /// exception propagates and the appointment is left `scheduled`. Silently
  /// swallowing a failed charge insert here would complete the appointment
  /// with no record of the money it was supposed to bring in, which is
  /// exactly the bug this feature exists to prevent.
  Future<void> complete(int id, {required double amountCharged}) async {
    final appointment = await _repository.byId(id);
    if (appointment == null) return;

    final noteBuffer = StringBuffer(
      'Cita – ${appointment.clientName ?? 'cliente'}',
    );
    final description = appointment.description;
    if (description != null && description.isNotEmpty) {
      noteBuffer.write(' ($description)');
    }

    await _movementRepository.insert(
      Movement(
        type: MovementType.income,
        amount: amountCharged,
        date: appointment.dateTime,
        clientId: appointment.clientId,
        note: noteBuffer.toString(),
        createdAt: DateTime.now(),
      ),
    );

    await _setStatus(id, AppointmentStatus.completed);
  }

  /// Persists [status] for the appointment [id]. A `scheduled` appointment
  /// leaving that status no longer needs its reminder (it was either
  /// cancelled, or it already happened), so any live reminder is cancelled
  /// first — best-effort, same as [add]'s scheduling: a notification-cancel
  /// failure (already fired, plugin issue, etc.) must not block the status
  /// change. `notificationId` is then cleared: `Appointment.copyWith` uses a
  /// naive `value ?? this.value` pattern for its nullable fields, which
  /// cannot distinguish "not passed" from "explicitly cleared to null", so
  /// clearing it requires building the updated appointment via the
  /// constructor directly instead of through copyWith.
  Future<void> _setStatus(int id, AppointmentStatus status) async {
    final appointment = await _repository.byId(id);
    if (appointment == null) return;

    if (appointment.notificationId != null) {
      try {
        await _notificationService.cancelReminder(appointment.notificationId!);
      } catch (_) {
        // No live reminder will be cancelled, but the status change proceeds.
      }
    }

    await _repository.update(
      Appointment(
        id: appointment.id,
        clientId: appointment.clientId,
        dateTime: appointment.dateTime,
        description: appointment.description,
        notificationId: null,
        createdAt: appointment.createdAt,
        status: status,
        clientName: appointment.clientName,
      ),
    );
    await refresh();
  }
}
