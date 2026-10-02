# CLAUDE.md

Behavioral guidelines to reduce common LLM coding mistakes. Merge with project-specific instructions as needed.

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

## 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them - don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

## 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

## 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it - don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

## 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

---

# Project: concapt

An Android app that floats a capture bubble over Gakuen Idolmaster. A tap on a contest rehearsal result screen reads the 9 member scores with on-device OCR, checks each stage's sum, and adds the run to a session. Sessions show per-slot statistics, histograms, and CSV export.

- Spec: `docs/superpowers/specs/2026-10-02-concapt-design.md`
- Plan: `docs/superpowers/plans/2026-10-02-concapt-android.md`

## Stack

- Flutter 3.41.4 / Dart 3.11.1, Android only for now (app id `dev.concapt.app`, `minSdk` 26)
- Kotlin for screen capture (local plugin `packages/screen_capture`, MediaProjection foreground service)
- `flutter_overlay_window` for the bubble, `google_mlkit_text_recognition` (Latin) for OCR
- `drift` + `drift_flutter` (SQLite), `shared_preferences`, `path_provider`, `share_plus`
- `flutter_localizations` + `intl`, with English and Japanese ARB files

## Commands

| Task | Command |
|---|---|
| Install packages | `flutter pub get` |
| Regenerate drift code | `dart run build_runner build --delete-conflicting-outputs` |
| Host tests | `flutter test` |
| Lint | `flutter analyze` |
| Device tests | `flutter test integration_test/<file>.dart -d <device-id>` |
| Run on phone | `flutter run -d <device-id>` |

## Layout

| Path | Contents |
|---|---|
| `lib/core/` | Pure Dart: models, result parser, stats, histogram, CSV. No Flutter imports |
| `lib/data/` | drift schema and `Repository` |
| `lib/capture/` | Capture pipeline: source, text reader, controller, session handoff |
| `lib/overlay/` | The overlay engine's app: bubble and edit panel |
| `lib/ui/` | Main app screens and shared widgets |
| `packages/screen_capture/` | Local Flutter plugin with the Kotlin capture service |
| `test/fixtures/ocr/` | Real ML Kit output recorded from the corpus |
| `ref-script/` | The original PC script and 206 rehearsal result captures (OCR test corpus) |
| `docs/` | Spec, plan, spike notes, manual test checklist |

## Design system (keep it consistent)

The visual identity is pending. It will be chosen with Impeccable, and `DESIGN.md` will replace this section. Until then:

- One theme, `buildTheme(Brightness)` in `lib/ui/theme.dart`, serves both engines in light and dark.
- The `Colors.indigo` seed is a placeholder. It stays fixed, with no Dynamic Color.
- Every text style uses tabular figures, so score columns line up.
- Use theme colors (`colorScheme.*`, `textTheme.*`); don't hard-code colors or font sizes.
- Numbers display through `lib/ui/format.dart`.
- UI copy lives in `lib/l10n/app_en.arb` and `app_ja.arb`, never in Dart.

See `PRODUCT.md` for users, terminology, and brand commitments.

## Gotchas (learned the hard way)

- Never use the Android emulator. Ask the user to connect their phone, then check `adb devices`.
- In Git Bash, prefix `adb` commands that take `/sdcard/...` paths with `MSYS_NO_PATHCONV=1`, or the path gets rewritten to a Windows path.
- The app runs two Flutter engines. Native code both engines need must live in a plugin package; code in `MainActivity` is invisible to the overlay engine.
- Both engines open the same SQLite file. Drift streams don't cross engines, so screens re-query on resume.
- The app id, Gradle `namespace`, and `MainActivity` package are all `dev.concapt.app`. The manifest's `.MainActivity` resolves against `namespace`, so changing one without the others crashes the app on launch.

## Verifying changes

- `flutter analyze` and `flutter test` pass before every commit.
- Changes to capture, overlay, or screens also go through `docs/manual-test-checklist.md` on the user's phone.
- Parser changes must keep `test/core/fixture_test.dart` green, so captures that read correctly on the phone keep reading correctly.
