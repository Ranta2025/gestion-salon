# Feature: Citas as a full bottom-nav tab, with history (cancel/complete/delete)

## Objective
Move "Agendar Cita" from an AppBar icon button into a full 6th bottom-nav
tab ("Citas") with its own history screen: list every appointment, cancel
one, mark one as done ("realizada"), or delete it from history. Also fix
the branded splash screen so its loading bar and app-name text are
actually noticeable.

## Problem / why
User feedback, 2026-09-19, after compiling and running the merged app:
- The current entry point (AppBar icon next to "Catálogos", only on the
  Dashboard tab) isn't enough — appointments need to be a first-class
  section like Inicio/Movimientos/Ajustes, with a real management screen:
  add, view history, cancel, mark done, delete.
- The splash screen "only shows the icon" — the loading bar and app name
  aren't registering. Explored the code: no structural bug found (text +
  `LinearProgressIndicator` are both there, colors are opaque, 1400ms is
  well past one frame). Most likely explanation: a thin 4px indeterminate
  bar with pastel low-contrast colors, shown for only 1.4s, is easy to
  miss/not notice — not a rendering defect. Fixing by making it clearly
  visible and giving it a bit more time, not by hunting a nonexistent bug
  further.

## Scope
- `Appointment` gets a `status` field (`scheduled` / `cancelled` /
  `completed`), schema bump to `_dbVersion = 3` with a v2→v3
  `_onUpgrade` migration (existing local installs — the user's own
  already-compiled device — may be on v2).
- `AppointmentRepository`: `all()` (full history, newest first, no date
  filter) and `upcoming()` narrowed to `status = 'scheduled'` (a
  cancelled/completed appointment is no longer "upcoming").
- `AppointmentsController`: `history` list alongside `upcoming`,
  `cancel(id)` and `complete(id)` (both cancel the pending reminder
  notification if any, then update status; `delete(id)` already existed
  and stays a real permanent delete).
- New `AppointmentsScreen` (history/list view, the tab's content): list
  every appointment (client, date/time, description, status), tap opens
  a bottom-sheet of actions (matches this app's existing
  `showModalBottomSheet`-for-choices convention — there's no
  `PopupMenuButton` precedent anywhere in the app to match instead),
  actions gated by current status (only a `scheduled` appointment can be
  cancelled or completed; delete always available, with a confirm dialog
  matching `MovementsScreen`'s `Dismissible.confirmDismiss` convention).
- `HomeShell`: add "Citas" as a 6th tab (order: Inicio, Movimientos,
  Clientes, Reportes, Citas, Ajustes — Ajustes stays last, matching the
  near-universal settings-last convention); remove the now-redundant
  "Agendar cita" AppBar icon button; FAB now also opens
  `AppointmentFormScreen` directly when on the Citas tab (the existing
  quick-add sheet stays Movimientos-tab-specific, untouched).
- Splash screen: taller/higher-contrast progress bar, slightly longer
  minimum display time.

Out of scope (not requested): editing/rescheduling an existing
appointment's date/time/description (only status changes + delete),
push/cloud reminders, recurring appointments.

## Constraints
- Same as the original agendar-citas feature: 100% offline, match
  existing design system exactly (`AppColors`, `IosCard`, `EmptyState`,
  `Dismissible`-confirm pattern, `showModalBottomSheet`-for-choices
  pattern, Spanish copy, no Cupertino), Provider/ChangeNotifier state,
  sqflite only.
- The user has already compiled and run the merged `master` locally —
  their device may hold a real v2 database, so the v2→v3 migration must
  actually work (test it, don't just add the column and assume).

## TDD mode
Same resolved mode/runner as the original feature (strict TDD enabled;
this project's actual convention tests the data/logic layer with real
`sqflite_common_ffi`, no widget-test infra). Applied to: repository
(`all()`, `status`-filtered `upcoming()`, v2→v3 migration) and controller
(`cancel`/`complete`, extending the existing
`test/appointments_controller_test.dart`). `AppointmentsScreen` and
`HomeShell` changes follow the existing untested-UI convention; verified
by structural read-back + `flutter analyze`/`flutter test` regression.
The splash tweak is a trivial single-file style change, no TDD applicable.

## Git workflow note
Branched `feature/citas-tab-historial` from `master` (which already has
both `agendar-citas` and `app-branding` merged in).

## Tasks
- [ ] **T1** — `Appointment.status` (`AppointmentStatus` enum:
  `scheduled`/`cancelled`/`completed`), `_dbVersion` bump to 3 +
  `_onUpgrade` v2→v3 branch adding the `status` column (default
  `'scheduled'`), `_onCreate`'s `appointments` table gets the column +
  `CHECK` constraint directly (fresh installs only — no `ALTER TABLE`
  `CHECK` complications). `AppointmentRepository.all()` +
  `upcoming()` narrowed to `status = 'scheduled'`. TDD: extend
  `test/repository_test.dart` (RED → GREEN) with a v2→v3 migration test
  (mirroring the existing v1→v2 one) and repository tests for `all()`
  and the narrowed `upcoming()`. Route: delegated writer.
- [ ] **T2** — `AppointmentsController`: `history` list, `cancel(id)`,
  `complete(id)` (both cancel any pending notification, then persist the
  new status, then refresh both lists). TDD: extend
  `test/appointments_controller_test.dart`. Route: delegated writer.
- [ ] **T3** — `AppointmentsScreen`
  (`lib/ui/screens/appointments/appointments_screen.dart`): history list
  matching `MovementsScreen`'s visual conventions (`IosCard`,
  `EmptyState`), status-gated action bottom sheet on tap, delete confirm
  dialog. Route: delegated writer.
- [ ] **T4** — `HomeShell`: add the "Citas" tab (6th), remove the old
  AppBar icon button, extend FAB dispatch to open
  `AppointmentFormScreen` directly on the Citas tab. Route: delegated
  writer.
- [ ] **T5** — Splash screen: taller/higher-contrast progress bar
  (`minHeight`), slightly longer minimum display time. Route: direct
  inline (single well-understood file, no research needed).

## Verification (per task)
- `flutter analyze`
- `flutter test`
- T3/T4: structural read-back against the design system (no widget-test
  infra in this project).
- T5: structural read-back only (trivial style tweak).

## Progress / evidence
(filled in as each task lands, with commit identity)
