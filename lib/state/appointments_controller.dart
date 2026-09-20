import 'package:flutter/foundation.dart';

import '../../data/models/models.dart';
import '../../data/repositories/appointment_repository.dart';
import '../../services/notification_service.dart';

class AppointmentsController extends ChangeNotifier {
  final AppointmentRepository _repository;
  final NotificationService _notificationService;

  AppointmentsController({
    AppointmentRepository? repository,
    NotificationService? notificationService,
  })  : _repository = repository ?? AppointmentRepository(),
        _notificationService = notificationService ?? NotificationService();

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

  Future<void> delete(int id) async {
    final appointment = await _repository.byId(id);
    if (appointment?.notificationId != null) {
      await _notificationService.cancelReminder(appointment!.notificationId!);
    }
    await _repository.delete(id);
    await refresh();
  }

  Future<void> cancel(int id) => _setStatus(id, AppointmentStatus.cancelled);

  Future<void> complete(int id) => _setStatus(id, AppointmentStatus.completed);

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
