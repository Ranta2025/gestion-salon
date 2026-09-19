# Feature: Agendar Cita (appointment scheduling)

## Objective
Add a new screen to schedule salon appointments (client + date + time + optional
service/task note) that fires a local notification 24 hours before the
appointment, matching the app's existing design system and offline-first
architecture.

## Problem / why
The app currently tracks income/expenses/clients/reports but has no way to
schedule future appointments or remind the owner ahead of time. User request,
2026-09-19.

## Scope
- New `Appointment` model + `appointments` table + `AppointmentRepository`.
- Local notification scheduling 24h before the appointment (offline, no
  cloud/push — `flutter_local_notifications` + `timezone`).
- New `AppointmentsController` (Provider/ChangeNotifier, same shape as
  existing controllers).
- New `AppointmentFormScreen` ("Agendar Cita"): client picker sourced from the
  existing `Client`/`ClientRepository` (with inline "add new client" when not
  registered — decided with user, see Product decisions), date + time pickers
  reusing the existing `_PickerTile` visual pattern, optional description
  field, save action.
- Entry point wired into `HomeShell` (AppBar action icon, same pattern as the
  existing "Catálogos" button).

Out of scope (not requested): a dedicated appointments list/history screen,
editing/cancelling existing appointments, recurring appointments.

## Product decisions
- **Client field**: selectable from existing registered clients (with
  inline add-new-client fallback), not free text — user chose this explicitly
  to keep data normalized and linked to client history/reports (2026-09-19).

## Constraints
- App must remain 100% offline (no cloud notification service).
- Must work on both Android and iOS.
- Must match existing design system exactly: `AppColors`/`AppTheme`,
  `IosCard`, `_PickerTile`-style pickers, Material widgets, Spanish UI copy,
  `Form` + `GlobalKey<FormState>` + `ListView` pattern, `Navigator.push(...,
  fullscreenDialog: true)` navigation (no named routes/go_router).
- Repository/model pattern must mirror `MovementRepository`/`Movement`
  (`toMap`/`fromMap`, plain `insert/update/delete/byId/query`).

## TDD mode
- **Resolved mode**: Strict TDD enabled (session/project configuration).
- **Runner**: `flutter test`.
- **Actual project convention** (verified in `test/repository_test.dart`):
  TDD is applied to the data/logic layer only — repository tests run against
  a real in-memory SQLite DB via `sqflite_common_ffi`, no mocks. There is
  **no widget-test infrastructure anywhere in this project** (zero
  `testWidgets`, no test for the existing `MovementFormScreen` either).
- **Applied here**: RED → GREEN → REFACTOR for `AppointmentRepository` (real
  sqlite, extends `test/repository_test.dart` conventions) and for the pure
  "24h-before" schedule-time calculation (new `test/notification_service_test.dart`,
  testing pure logic only — the plugin itself cannot run in the unit-test
  environment). `AppointmentFormScreen` and `AppointmentsController` follow
  the existing untested-UI convention (same as `MovementFormScreen` /
  `MovementsController`) since no widget-test harness exists to extend.

## Research notes (2026-09-19)
- No notification package existed in the project (confirmed: not in
  `pubspec.yaml`, `AndroidManifest.xml`, or `Info.plist`).
- Current `flutter_local_notifications` (latest on pub.dev, resolve via
  `flutter pub add` rather than hardcoding a version) requires `zonedSchedule`
  with `tz.TZDateTime` from the `timezone` package; needs
  `SCHEDULE_EXACT_ALARM` (or `USE_EXACT_ALARM`) + `RECEIVE_BOOT_COMPLETED` in
  `AndroidManifest.xml`, plus the two `com.dexterous.flutterlocalnotifications`
  receivers, and Android 13+ needs runtime `POST_NOTIFICATIONS` permission.
  `flutter_timezone` gets the device's IANA timezone name for
  `tz.setLocalLocation`. Source: pub.dev package page (fetched live).

## Git workflow note
Repository had **zero commits** before this feature (everything untracked on
`master`, no history). Baseline-committed the existing app first so a
`feature/agendar-citas` branch has something real to branch from, per the
project's work-unit-commit workflow.

## Tasks

- [x] **T0** — Baseline commit existing untracked app on `master`; branch
  `feature/agendar-citas`. Route: direct inline (git plumbing only).
- [ ] **T1** — Add `flutter_local_notifications` + `timezone` (+
  `flutter_timezone`) deps; Android manifest permissions/receivers; iOS
  notification entitlement setup. Route: delegated writer (3+ platform
  config files). No TDD (platform config, not logic).
- [ ] **T2** — `Appointment` model (`lib/data/models/models.dart`),
  `appointments` table (`lib/data/db/app_database.dart`),
  `AppointmentRepository` (new file). TDD: extend
  `test/repository_test.dart` with insert/query/delete cases first (RED),
  then implement (GREEN). Route: delegated writer (4 files incl. test).
- [ ] **T3** — `NotificationService`: pure `scheduleTimeFor(appointmentAt)`
  (returns `appointmentAt - 24h`, plus a `shouldSchedule` guard for
  already-past times) unit-tested first (RED → GREEN), then the
  plugin-wiring (`init`, permission request, `schedule`, `cancel`). Route:
  delegated writer (2 files: service + test).
- [ ] **T4** — `AppointmentsController` (ChangeNotifier, mirrors
  `MovementsController`); wire into `lib/app.dart` `MultiProvider` and
  `lib/main.dart` instantiation (calls `NotificationService.init()`). Route:
  delegated writer (3 files).
- [ ] **T5** — `AppointmentFormScreen` (client picker w/ inline add-client
  dialog reusing `ClientsScreen`'s dialog pattern, date/time `_PickerTile`
  pickers, optional description field, Guardar button →
  `AppointmentsController.add()` → schedules notification); wire entry point
  into `HomeShell` AppBar (icon button, same pattern as "Catálogos"). Route:
  delegated writer (2 files).

## Verification (per task)
- `flutter analyze`
- `flutter test`
- For T5, no automated screen test exists to run (see TDD mode note) — the
  writer reports structural readback of the screen against the design system
  instead.

## Progress / evidence
(filled in as each task lands, with commit identity)
