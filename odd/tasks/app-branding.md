# Feature: App icon, splash screen, and display name

## Objective
Use the user-provided icon (`assets/icon/app_icon.png`, pastel scissors +
comb + leaf on a rounded lavender/peach badge) as the real app icon on
Android and iOS, show it on a branded loading/splash screen with a loading
indicator matching the app's design system, and fix the installed app's
display name so it reads "Gestion Salon" instead of a raw/default name.

## Problem / why
User request, 2026-09-19: provided a new icon file at the project root
(`screen.png`, 1024×1024) and asked to (1) place it correctly and wire it
as the app icon, (2) make it show on the loading screen with a nicer,
branded loading experience (icon + loading bar, matching the app's style),
and (3) fix the installed app name, which showed as a raw/generic name
instead of "Gestion Salon".

## Scope
- Move the provided icon into `assets/icon/app_icon.png`, declare it as a
  Flutter asset (also reused by the custom splash widget).
- `flutter_launcher_icons`: generate Android (incl. adaptive icon) + iOS
  app icons from that image.
- `flutter_native_splash`: generate the native (OS-level, pre-Flutter-engine)
  splash screen, background color matching `AppColors.background`, using
  the same icon.
- A custom Flutter `SplashScreen` widget (first route in `MaterialApp.home`,
  matching the app's design system: `AppColors`, `IosCard`-style, no
  Cupertino) shown right after the native splash hands off, with the icon
  and an indeterminate loading indicator, then navigates to `HomeShell`.
- Fix the Android display name (`android:label`) to "Gestion Salon"
  (iOS's `CFBundleDisplayName` was already correct — verified, not touched).

Out of scope: custom app icon design iteration (the user already supplied
the final image), animated/Lottie splash, real per-step progress tracking
tied to specific async operations (an indeterminate bar matching the
app's style is what was asked for — "como si le pones una barra de
carga").

## Constraints
- Match existing design system: `AppColors`/`AppTheme`, Spanish copy, no
  Cupertino widgets, no new visual language.
- Must not break the existing Android notification manifest config from
  the `agendar-citas` feature (this branch is cut from `master`, which
  predates that feature — the two branches are independent and will be
  merged separately).
- 100% offline, no new runtime dependencies beyond the two icon/splash
  dev-tool packages (both are build-time code generators, not runtime
  deps).

## TDD mode
Not applicable — this is asset/config/branding work (icons, native splash
resources, a static branded widget), not testable logic. Matches this
project's existing convention of no widget-test infrastructure. Verified
via `flutter analyze`, `flutter test` (regression check on the existing
suite), a structural read-back of the new widget, and (if the user
authorizes it) a real `flutter build apk --debug`.

## Git workflow note
Branched `feature/app-branding` from `master` (not from `feature/agendar-citas`,
which is a separate, already-complete, not-yet-merged feature) since this
work is unrelated to appointment scheduling.

## Tasks
- [x] **T1** — `flutter_launcher_icons`: add dev dependency, configure
  (`image_path`, `adaptive_icon_background`, `adaptive_icon_foreground`,
  `ios: true`), run `dart run flutter_launcher_icons`, verify generated
  Android mipmap/adaptive-icon and iOS AppIcon.appiconset files actually
  changed.
- [x] **T2** — `flutter_native_splash`: add dev dependency, configure
  (`color` = `AppColors.background`, `image` = the icon, an `android_12`
  block), run `dart run flutter_native_splash:create`, verify generated
  Android/iOS native splash resources.
- [x] **T3** — Custom `SplashScreen` widget
  (`lib/ui/screens/splash/splash_screen.dart`): icon + app name +
  indeterminate loading indicator styled with `AppColors`, minimum visible
  time so it doesn't just flash on fast devices, then
  `Navigator.pushReplacement` to `HomeShell`. Wire it as `MaterialApp.home`
  in `lib/app.dart` (replacing the direct `HomeShell()`).
- [x] **T4** — Fix `android:label` in
  `android/app/src/main/AndroidManifest.xml` to `"Gestion Salon"`.
- [x] **T5** — Clean up: `assets/icon/app_icon.png` kept (needed by the
  splash widget). No extra cleanup required.

## Verification (per task)
- `flutter analyze`
- `flutter test` (existing suite, regression only — no new tests expected)
- Structural read-back of generated/edited files
- Real `flutter build apk --debug`, only with explicit user authorization
  (the user previously interrupted an unscoped build attempt)

## Progress / evidence
- **T1–T2** done. Commit `4e35863` — `flutter_launcher_icons ^0.14.4` +
  `flutter_native_splash ^2.4.8` resolved, both generated real output:
  Android `mipmap-*/launcher_icon.png` + adaptive icon XML +
  `ic_launcher_foreground.png`, iOS `AppIcon.appiconset/*.png`; native
  splash `drawable*/launch_background.xml` + `splash.png`/`android12splash.png`
  (incl. dark-mode), `values-v31`/`values-night-v31` styles, iOS
  `LaunchScreen.storyboard` + `LaunchImage`/`LaunchBackground` imagesets.
  No warnings about the source image's baked-in background vs. the
  Android 12 safe zone. `CFBundleDisplayName` confirmed unchanged
  ("Gestion Salon").
- **T3–T4** done. Commit `0417089` — `SplashScreen`
  (`lib/ui/screens/splash/splash_screen.dart`): icon in a
  `ClipRRect(28)` at 140×140, "Gestión Salón" label (inline `TextStyle`,
  matching this codebase's existing inline-styling convention, not
  `Theme.textTheme`), indeterminate `LinearProgressIndicator` in
  `AppColors.accentDeep`/`accent.withValues(alpha: 0.25)`, 1400ms minimum
  display then mounted-guarded `pushReplacement` to `HomeShell`. Wired as
  `MaterialApp.home` in `app.dart` (removed the now-unused `HomeShell`
  import there). `android:label` fixed to `"Gestion Salon"` in the main
  manifest only (debug/profile don't declare one).
  Verification: `flutter analyze` clean, `flutter test` 9/9 (this branch's
  baseline, cut from `master` before `agendar-citas`), structural
  read-back done. No native build attempted — reserved for explicit user
  authorization.

## Outcome
All 5 tasks done. Icon, native splash, and branded loading screen are in
place; Android display name fixed. **Not yet verified**: no real
`flutter build apk`/`flutter build ios` has been run for this branch —
the user should authorize that explicitly before considering this
production-ready, since native icon/splash resource generation is exactly
the kind of change that can silently break a native build (manifest
merge, resource naming clashes) even when `flutter analyze`/`flutter test`
stay green.

Gentle AI review of the full branch (73 files vs. `master`): user granted
consent, `review-reliability` found one real CRITICAL —
`flutter_native_splash`'s `fullscreen: true` had set
`UIStatusBarHidden=true` on iOS with no restoration logic, hiding the
status bar app-wide instead of only during the splash (commit `68ba1c8`
first over-corrected this by also reverting Android's fullscreen splash
theme and dropping `fullscreen: true` from the config entirely — the
targeted validator correctly rejected that as out-of-scope; commit
`e3dd5d3` re-scoped the fix to the single iOS `Info.plist` line that
actually needed to change, keeping Android's fullscreen splash intact).
Re-validation then hit the same `recovery_authorization_required` gate
already seen on the `agendar-citas` branch (a maintainer-level grant the
agent declined to self-issue) — left unacknowledged, consistent with that
earlier precedent. `flutter analyze` clean and `flutter test` 9/9 after
the final fix, independent of this lineage's bureaucratic state.
