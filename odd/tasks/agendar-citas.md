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
- [x] **T1** — Add `flutter_local_notifications` + `timezone` (+
  `flutter_timezone`) deps; Android manifest permissions/receivers; iOS
  notification entitlement setup. Route: delegated writer (3+ platform
  config files). No TDD (platform config, not logic).
- [x] **T2** — `Appointment` model (`lib/data/models/models.dart`),
  `appointments` table (`lib/data/db/app_database.dart`),
  `AppointmentRepository` (new file). TDD: extend
  `test/repository_test.dart` with insert/query/delete cases first (RED),
  then implement (GREEN). Route: delegated writer (4 files incl. test).
- [x] **T3** — `NotificationService`: pure `scheduleTimeFor(appointmentAt)`
  (returns `appointmentAt - 24h`, plus a `shouldSchedule` guard for
  already-past times) unit-tested first (RED → GREEN), then the
  plugin-wiring (`init`, permission request, `schedule`, `cancel`). Route:
  delegated writer (2 files: service + test).
- [x] **T4** — `AppointmentsController` (ChangeNotifier, mirrors
  `MovementsController`); wire into `lib/app.dart` `MultiProvider` and
  `lib/main.dart` instantiation (calls `NotificationService.init()`). Route:
  delegated writer (3 files).
- [x] **T5** — `AppointmentFormScreen` (client picker w/ inline add-client
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
- **T0** done. Baseline commit `b5a6f29` on `master` (110 files, existing app
  + newly-created `AGENTS.md`, required by the repo's `gga` pre-commit hook
  which had no rules file yet). Branched `feature/agendar-citas` from it.
- **T1** done. Commit `59a035f` — `flutter_local_notifications 22.3.1`,
  `timezone 0.11.1`, `flutter_timezone 5.1.0` resolved via `flutter pub add`;
  Android manifest permissions/receivers, `build.gradle.kts` core-library
  desugaring, iOS `AppDelegate.swift` notification-center delegate. Verified
  with `flutter pub get` and `flutter analyze` (clean, no issues). Gentle AI
  review: medium-risk consent granted by user, `review-reliability` lens
  approved (2 non-blocking SUGGESTION findings noting the new deps aren't
  consumed by code yet — expected, that's T2/T3), acknowledged.
  Post-commit `gentle-ai review assess --base-ref b5a6f29 --committed-only`:
  medium risk, `review_due=false` (`under_budget`, 90/~400 lines) — reviewed
  boundary stays at `b5a6f29`.
- **T2** done. Commit `ec26270` — `Appointment` model (`clientId` required,
  `notificationId` for T3, `copyWith`), `appointments` table + `date_time`
  index, `AppointmentRepository` (`insert/update/delete/byId/upcoming`,
  left-joined with `clients` for `clientName`, same pattern as
  `MovementRepository`). TDD: RED (compile failure, class didn't exist) →
  GREEN (12/12 tests pass, 3 new) → clean `flutter analyze`. FK decision:
  since this DB never enables `PRAGMA foreign_keys` and `Movement` already
  sets the precedent of "keep the record, clear/orphan the link" on client
  deletion, a deleted client's appointments are kept with their (now stale)
  `clientId` and a `clientName` that resolves to `null` — verified by test.
  Post-commit assess: medium risk (321/~400 lines cumulative),
  `review_due=false` (`under_budget`) — boundary stays at `b5a6f29`.
- **T3** done. Commit `4857c0f` — pure `scheduleTimeFor`/`shouldSchedule`
  (TDD: RED compile failure → GREEN 7/7 new + 12 pre-existing = 19/19) +
  `NotificationService` wrapping the plugin (`init`, exact-alarm graceful
  degradation, `scheduleAppointmentReminder`, `cancelReminder`), API verified
  against the actually-installed package sources, not memory. Clean
  `flutter analyze`.
  Post-commit assess (509/~400 lines cumulative): `review_due=true`
  (`slice_budget_reached`) — ran the review. User granted consent; single
  `review-reliability` lens found one CRITICAL: `appointments` table only
  created in `_onCreate`, no `onUpgrade`, so an existing install would miss
  the table after an update. Fixed for real: bumped `_dbVersion` to 2 and
  added `_onUpgrade` creating `appointments`+index for `oldVersion < 2`
  (commit `ae0ffd3`), tests still 19/19 green, analyze clean.
  The review tool's own correction-validation step then hit its documented
  terminal state (`captured_artifacts_unverifiable` — a known open upstream
  defect, gentle-ai#4772, reproduced here too and reported with an
  occurrence comment per the project's defect-handoff protocol, user
  consented). The code fix itself is committed and verified independently
  of that tool state; reviewed boundary stays at `b5a6f29` since this
  lineage never reached acknowledgement.
- **T4** done. Commit `c28aa5c` — `AppointmentsController` (`ChangeNotifier`,
  `upcoming`/`loading`, `refresh()`, `add()` persists then schedules the
  reminder then persists `notificationId`, `delete()` cancels the reminder
  then deletes), registered with `ChangeNotifierProvider.value` in
  `lib/app.dart` (same pattern as `MovementsController`), instantiated in
  `lib/main.dart` with `NotificationService().init()` wrapped in try/catch
  at startup (already-async `main()`, no signature change needed). Clean
  `flutter analyze`, 19/19 tests still passing.
  Post-commit assess (602/~400 lines cumulative): `review_due=true`
  (`slice_budget_reached`) — ran the review (fresh lineage this time, since
  the T3 one was stuck terminal). User granted consent; single
  `review-reliability` lens found two more CRITICALs: (1)
  `AppointmentsController.add()` had no error handling around the
  notification call, unlike `main.dart`'s established pattern for the same
  failure mode, and (2) the `_onUpgrade` migration had zero test coverage.
  Fixed for real (commit `376c50f`): wrapped the notification
  scheduling+persist step in `add()` in try/catch (appointment stays saved
  without a `notificationId` on failure, `refresh()` still runs); added
  `test/appointments_controller_test.dart` (first controller test in the
  project, TDD: RED confirmed the exception propagated → GREEN after the
  fix) and a real v1→v2 migration test in `test/repository_test.dart` (new
  `createV1SchemaForTest`/`upgradeSchemaForTest` testing-only helpers on
  `AppDatabase`, migration passed first try — it was genuinely just
  untested, not broken). 21/21 tests, analyze clean.
  Re-deriving review status after this second correction returned
  `recover`/`scope_changed` (the new test file widened the reviewed file
  set), asking for a `--maintainer-authorization` block that the tool's own
  `review recover --help` describes as a maintainer-level grant — not
  something to self-issue as the implementing agent. Discussed with the
  user: left this review lineage unresolved/unacknowledged rather than
  self-authorizing, and proceeded with T5. The code itself (T1–T4, plus
  both corrections) is independently verified via `flutter analyze` +
  `flutter test` regardless of this lineage's bureaucratic state; reviewed
  boundary stays at `b5a6f29`.
- **T5** done — feature complete. Commit `3225caa` —
  `AppointmentFormScreen` (`lib/ui/screens/appointments/appointment_form_screen.dart`,
  new): required client picker (`DropdownButtonFormField<int>` over
  `ClientsController.clients`, matching `movement_form_screen.dart`'s
  existing client-field style) with an inline "+ cliente" dialog replicating
  `clients_screen.dart`'s add-client flow verbatim; date/time via a
  duplicated `_PickerTile` (tomorrow 10:00 default, `firstDate: now`);
  optional description (`TextFormField`, blank → `null`); Guardar →
  `AppointmentsController.add(...)` → pop, no success snackbar (matches
  `MovementFormScreen`'s own convention). Entry point: AppBar icon button
  next to "Catálogos" in `home_shell.dart` (occasional action, not a daily
  quick-add, so it doesn't belong in the Ingreso/Gasto bottom sheet).
  Clean `flutter analyze`; 21/21 tests unaffected (no data/logic touched).
  Structural read-back done (no widget-test infra exists in this project,
  per the TDD mode note) — confirmed `AppColors` used, Spanish copy, no
  Cupertino widgets, no dead code/TODOs, existing form/navigation
  conventions matched exactly.

## Outcome
All 5 tasks done. Client scheduling with date, time, optional
description, and a 24h-before local notification is implemented end to
end, matching the existing design system, fully offline. Two real
reliability fixes were made mid-flight from code review findings (DB
migration path, controller error handling), both with new tests.
**Not verified**: no Android/iOS emulator or physical device is available
in this environment, so the screen was never visually run or manually
tapped through — verification is `flutter analyze` (clean) + the full
`flutter test` suite (21/21) plus structural read-back only. Recommend
running `flutter run` on a device/emulator before considering this
production-ready, particularly to confirm the notification actually fires
and that Android's exact-alarm/POST_NOTIFICATIONS runtime permission
prompts behave as expected on a real device.
One Gentle AI review lineage (`review-18c6560fded73cad`, T1–T4 cumulative)
was left unacknowledged after hitting a `recover`/`scope_changed` gate
that asks for a maintainer-level authorization the agent declined to
self-issue (user concurred) — does not block delivery under this
project's "unmanaged" delivery policy, but a maintainer could resolve it
manually with `gentle-ai review recover` if desired.
