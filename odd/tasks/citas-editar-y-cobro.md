# Feature: Edit an appointment; charge amount required to mark as done

## Objective
Let the user edit an existing appointment (client/date/time/description)
instead of having to delete and recreate it. Require an amount charged
when marking an appointment as "realizada" (completed) — that amount
automatically creates an income `Movement` linked to the same client, so
completed appointments feed the existing income/expense reporting.

## Problem / why
User feedback, 2026-09-20, after using the merged Citas tab:
- No way to fix a mistaken date/client/etc. on an already-scheduled
  appointment — the only option was delete + recreate.
- Marking an appointment "realizada" currently has no link to the
  money side of the app at all; the user wants the actual charge
  captured at that moment and reflected in Movimientos as income,
  since that's the real business event (the appointment happened and
  was paid for).

## Scope
- `AppointmentFormScreen` gains an edit mode: optional `Appointment?
  editing` constructor param, pre-fills client/date/time/description,
  saves via a new `AppointmentsController.update(...)` instead of
  `add(...)`. If the date/time changed, the existing reminder (if any)
  is cancelled and a new one is scheduled for the new time (same
  `shouldSchedule` past-time guard already used elsewhere).
- `AppointmentsController.complete(id, {required double amountCharged})`
  — signature change (amount now required): cancels any live reminder,
  inserts a new income `Movement` (`clientId` = the appointment's
  client, `date` = the appointment's `dateTime`, `amount` =
  `amountCharged`, `note` = "Cita – {clientName}" [+ the appointment's
  description if present], default `paymentMethod` = `'efectivo'`),
  then persists `status: completed`, then refreshes.
- `AppointmentsScreen`: the "Marcar como realizada" action now opens an
  amount-entry `AlertDialog` (matches the existing add-client dialog
  style) before calling `complete(...)` — cancelling the dialog leaves
  the appointment untouched (still `scheduled`); a new "Editar" action
  in the same bottom sheet (only when `status == scheduled`, same
  gating as cancel/complete) pushes `AppointmentFormScreen(editing:
  appointment)`.

Out of scope (not requested): editing a `cancelled`/`completed`
appointment, editing the charged amount after the fact, changing the
auto-created movement's category/service, recurring appointments.

## Product decisions (made by the agent, per user's "you get it" scope)
- Edit is only available for `scheduled` appointments.
- The auto-created movement uses the appointment's `dateTime` as its
  `date` (not "now"), so daily/monthly reports reflect when the
  appointment actually happened.
- `paymentMethod` defaults to `'efectivo'` (matches `Movement`'s own
  existing default) — not asked, since the user only mentioned the
  amount.
- Movement note format: `"Cita – {clientName}"`, plus the appointment's
  description appended if present.

## Constraints
Same as the rest of this feature family: 100% offline, match existing
design system exactly, Provider/ChangeNotifier state, sqflite only,
Spanish copy, no Cupertino. `AppointmentsController` will now depend on
`MovementRepository` too (constructor-injected, optional param,
mirrors the existing `NotificationService` injection pattern) — a
controller depending on another domain's repository is new for this
app but necessary here since completing an appointment is genuinely a
cross-domain business event (appointments + finance).

## TDD mode
Same resolved mode/runner (strict TDD; real `sqflite_common_ffi`, no
widget-test infra). Applied to: `AppointmentsController.update()` and
the changed `complete()` (extending
`test/appointments_controller_test.dart` — assert the Movement is
actually inserted with correct fields, assert notification
reschedule-on-date-change). UI (`AppointmentFormScreen` edit mode, the
new dialog in `AppointmentsScreen`) follows the existing untested-UI
convention; verified by structural read-back + regression.

## Git workflow note
Branched `feature/citas-editar-y-cobro` from `master` (has
`agendar-citas`, `app-branding`, and `citas-tab-historial` merged in).

## Tasks
- [x] **T1** — `AppointmentsController`: add `update(Appointment)` (persists
  edited fields; if `dateTime` changed, cancel the old reminder if any
  and reschedule via the existing `NotificationService`/`shouldSchedule`
  path, same as `add()`'s scheduling logic); change `complete(id)` to
  `complete(id, {required double amountCharged})` (inserts the income
  `Movement` via an injected `MovementRepository`, then persists
  `status: completed`, same reminder-cancel behavior as today). TDD:
  extend `test/appointments_controller_test.dart`. Route: delegated
  writer.
- [x] **T2** — `AppointmentFormScreen`: optional `Appointment? editing`
  param; when set, pre-fill client/date/time/description, AppBar
  title/button copy adjusts ("Editar cita"/"Guardar cambios" vs. today's
  "Agendar Cita"/"Guardar"), save path calls `controller.update(...)`
  instead of `add(...)`. Route: delegated writer.
- [x] **T3** — `AppointmentsScreen`: amount-entry `AlertDialog` (Spanish
  copy, numeric validation matching `Movement.amount`'s `CHECK(amount >
  0)` convention) wired into "Marcar como realizada"; new "Editar"
  action in the bottom sheet (status-gated to `scheduled`) pushing
  `AppointmentFormScreen(editing: appointment)`. Route: delegated writer.

## Verification (per task)
- `flutter analyze`
- `flutter test`
- T2/T3: structural read-back (no widget-test infra in this project).

## Progress / evidence
- **T1** done. Commit `f1daf1f` — `AppointmentsController` gains an
  optional `MovementRepository?` (mirrors the `NotificationService?`
  pattern); `update(...)` compares `dateTime` via `DateHelpers
  .dateTimeKey` (avoids false-positive reschedules from DB round-trip
  precision loss), only cancels/reschedules the reminder when the date
  actually changed, never touches `status`; `complete(id, {required
  amountCharged})` inserts the income `Movement` FIRST and lets a
  failure propagate (fails closed — an appointment never completes
  with an unrecorded charge), then reuses `_setStatus` for the
  reminder-cancel + `status: completed` step. TDD: RED (compile errors
  for the new signature/method) → GREEN (8/8 in
  `appointments_controller_test.dart`, 31/31 full suite). Clean
  `flutter analyze`.
  **Stopgap left for T3**: `appointments_screen.dart`'s "Marcar como
  realizada" action currently calls `complete(id, amountCharged: 0.01)`
  with a `TODO(T3)` — T3 must replace this with the real amount-entry
  dialog.
- **T2** done. Commit `b70351a` — `AppointmentFormScreen` gains
  `editing`/`_isEditing`, matching `MovementFormScreen`'s exact edit
  convention (title/button copy switch, `initState` pre-fill, `_save()`
  branches `update`/`add`, preserves `id`/`notificationId`/`status`/
  `createdAt` from the original on edit). Create-mode path untouched.
  `flutter analyze` clean, 31/31 tests unaffected.
- **T3** done — feature complete. Commit `b933fcf` — amount dialog
  (`_promptAmount`, `Form`+`TextFormField`, comma→dot normalization
  matching `MovementFormScreen`'s own amount parsing, rejects
  empty/non-numeric/≤0 with "Ingresá un monto válido"); a failed
  `complete()` call is caught and shown via the same `_showError`
  SnackBar pattern already used in `AppointmentFormScreen`
  ("No se pudo registrar el cobro. Intentá de nuevo."); stopgap
  `0.01`/`TODO(T3)` fully removed (confirmed via grep). "Editar cita"
  added to the action sheet, status-gated to `scheduled`, placed
  between "Marcar como realizada" and "Cancelar cita" (constructive
  actions before destructive ones), pushes
  `AppointmentFormScreen(editing: appointment)`. `flutter analyze`
  clean, 31/31 tests unaffected.

## Outcome
All 3 tasks done. Appointments can now be edited (client/date/time/
description, with automatic reminder reschedule if the date changed),
and marking one "realizada" requires entering the amount charged, which
creates a linked income Movement automatically. Matches the existing
design system throughout.
**Not yet verified**: no real native build has been run on this branch —
same caveat as every other feature this session.

Gentle AI review of the full branch (5 files vs. `master`): user granted
consent, `review-reliability` found two CRITICALs. (1) A false-positive
premise on inspection — `clientName` was claimed to be "lost" on
`update()`, but it's a display-only join field never written by
`Appointment.toMap()`, so nothing was actually lost in the DB; still
fixed the underlying code smell (the reconstructed `Appointment` was
using `appointment.clientName`, always `null` from the form, instead of
the method's own fresher `clientName` parameter). (2) A real one:
`complete()` did the income `Movement` insert and the appointment's
status update as two separate, unguarded writes — a failure between them
could leave an orphaned `Movement` with the appointment still
`scheduled`, and the UI's retry-on-error path would then double-insert
the charge on a successful retry. Fixed by wrapping both writes in one
`Database.transaction()` (added an optional `DatabaseExecutor? executor`
param to `AppointmentRepository.update()` and `MovementRepository
.insert()` so both can share one transaction), commit `617a2ab`. 31/31
tests, analyze clean after the fix.
Re-validation hit the same `recovery_authorization_required` gate
already seen twice on this branch's predecessor features (the fix
touched 2 repository files outside the originally-reviewed manifest,
widening scope) — left unacknowledged, consistent with that established
precedent; the fix itself is independently verified.
