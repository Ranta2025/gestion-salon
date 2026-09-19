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
  bool loading = true;

  Future<void> refresh() async {
    loading = true;
    notifyListeners();
    upcoming = await _repository.upcoming();
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
}
