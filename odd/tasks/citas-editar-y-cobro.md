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
- [ ] **T1** — `AppointmentsController`: add `update(Appointment)` (persists
  edited fields; if `dateTime` changed, cancel the old reminder if any
  and reschedule via the existing `NotificationService`/`shouldSchedule`
  path, same as `add()`'s scheduling logic); change `complete(id)` to
  `complete(id, {required double amountCharged})` (inserts the income
  `Movement` via an injected `MovementRepository`, then persists
  `status: completed`, same reminder-cancel behavior as today). TDD:
  extend `test/appointments_controller_test.dart`. Route: delegated
  writer.
- [ ] **T2** — `AppointmentFormScreen`: optional `Appointment? editing`
  param; when set, pre-fill client/date/time/description, AppBar
  title/button copy adjusts ("Editar cita"/"Guardar cambios" vs. today's
  "Agendar Cita"/"Guardar"), save path calls `controller.update(...)`
  instead of `add(...)`. Route: delegated writer.
- [ ] **T3** — `AppointmentsScreen`: amount-entry `AlertDialog` (Spanish
  copy, numeric validation matching `Movement.amount`'s `CHECK(amount >
  0)` convention) wired into "Marcar como realizada"; new "Editar"
  action in the bottom sheet (status-gated to `scheduled`) pushing
  `AppointmentFormScreen(editing: appointment)`. Route: delegated writer.

## Verification (per task)
- `flutter analyze`
- `flutter test`
- T2/T3: structural read-back (no widget-test infra in this project).

## Progress / evidence
(filled in as each task lands, with commit identity)
