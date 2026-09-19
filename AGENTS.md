# Code Review Rules — Gestión Salón

Flutter app for a hair salon owner: daily income/expense tracking, clients,
catalogs, reports, cash close. Must run 100% offline on Android and iOS.

## Architecture
- Layers: `ui/screens` + `ui/widgets` → `state` (controllers) → `data/repositories`
  → `data/db` (sqflite). Screens never touch the database directly.
- State management: Provider. One `XController extends ChangeNotifier` per
  feature, holding a repository, exposing plain fields, refreshed via
  `refresh()`. Registered as `ChangeNotifierProvider.value` in `lib/app.dart`,
  instantiated up-front (not lazily) in `lib/main.dart`.
- Persistence: sqflite only, no cloud services, no network calls. Schema
  lives in `lib/data/db/app_database.dart` (`_onCreate`). Repositories are
  plain classes with `insert/update/delete/byId/query` methods.
- Models live together in `lib/data/models/models.dart`: immutable classes
  with nullable `id`, a `toMap()`/`fromMap()` pair, dates stored via
  `DateHelpers.dateTimeKey`/parsed with `DateTime.parse`.
- Navigation: plain `Navigator.push(MaterialPageRoute(...))`, no named
  routes, no go_router. Add/edit forms use `fullscreenDialog: true`.

## UI / design system
- Material only (no Cupertino widgets), UI copy in Spanish.
- Reuse `AppColors`/`AppTheme` (`lib/core/theme/app_theme.dart`) — do not
  hardcode colors in screens.
- Reuse shared widgets (`IosCard`, `EmptyState`, `SectionTitle`, picker-tile
  pattern) instead of duplicating layout.
- Forms: `Form` + `GlobalKey<FormState>` + `ListView` of
  `TextFormField`/`DropdownButtonFormField`. Dialogs via `showDialog<T>` +
  `AlertDialog` with `TextButton` (Cancelar) / `FilledButton` (Guardar).
- Spacing rhythm: `EdgeInsets.all(16)` screen padding,
  `SizedBox(height: 8/12/16/24)`, `BorderRadius.circular(12–20)`.

## Testing
- Test the data/logic layer: repository tests run against a real in-memory
  SQLite database via `sqflite_common_ffi` (see `test/repository_test.dart`)
  — no mocks for the database.
- Pure logic (calculations, date/time helpers, scheduling math) gets unit
  tests independent of any plugin/platform channel.

## General
- Dart/Flutter lints (`flutter_lints`) must pass; run `flutter analyze`
  before committing.
- No `any`-equivalent shortcuts: keep model fields and DB columns typed and
  explicit.
- Don't introduce new dependencies for something the existing stack already
  covers (Provider, sqflite, fl_chart, intl are the established choices).
