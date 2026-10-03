# concapt for Windows — Design Spec

- **Date:** 2026-10-03
- **Status:** Draft for review
- **Platform:** Windows 10 1903+ / Windows 11, alongside the Android app
- **Builds on:** `2026-10-02-concapt-design.md` (the Android spec). Everything not covered here is unchanged.

## 1. Goal

Capture rehearsal results on PC, replacing `ref-script/contest.py`. The player runs the game in a window on Windows (the PC client, or the phone mirrored with scrcpy), presses a global hotkey, and concapt captures that window, reads it, checks each stage's sum, and saves the run.

## 2. Scope

### In scope

- Windows target for the existing Flutter app
- Window picker: capture any visible top-level window
- Global hotkey trigger, rebindable
- Windows Graphics Capture (WGC) of the chosen window
- OCR with `Windows.Media.Ocr`
- A capturing view in the main window, with the edit form inline
- OCR accuracy test on the PC

### Out of scope

- Packaging, installer, signing. Runs from the repo (`flutter run -d windows` or a local release build)
- Sharing sessions between phone and PC
- Floating button or separate HUD window
- Auto-detecting the result screen (unchanged from Android)

## 3. Requirements

| Area | Requirement |
|---|---|
| Users | The developer only |
| Trigger | Global hotkey, default F9; works while the game has focus |
| Target | Any visible top-level window, picked by the user; remembered between starts |
| Focus | concapt never takes focus from the game; a failed check only flashes the taskbar button |
| Data | Sessions live in the PC's own database |
| Shared code | `lib/core/`, `lib/data/`, theme, l10n, and all analysis screens are shared with Android |

## 4. Architecture

### 4.1 Overview

```
hotkey ─► CaptureController.trigger()
             │
             ├─ WindowCaptureSource ──► window_capture: captureWindow(hwnd) ─► PNG
             ├─ WindowsOcrTextReader ─► window_capture: recognize(png) ─► TextPiece[]
             ├─ ResultParser + sum check (shared)
             └─ Repository (shared)
                  │
             CaptureScreen ◄── outcome
```

Windows runs one Flutter engine. Drift streams work normally, and no screen needs to re-query on resume.

### 4.2 Native plugin: `packages/window_capture`

A new local plugin with C++/WinRT, Windows only. `packages/screen_capture` stays Android-only, since its API (consent, notifications, toasts) is shaped around MediaProjection.

| Call | Does |
|---|---|
| `listWindows()` | Visible top-level windows with a title, minimized ones included: handle, title, process name |
| `captureWindow(handle, path)` | Grabs one WGC frame, crops to the client area, saves PNG. Sets `IsBorderRequired = false` where supported |
| `registerHotkey(key)` | `RegisterHotKey` on the runner window; returns false if the key is taken |
| `unregisterHotkey()` | Releases the hotkey |
| `hotkeyPresses` | Event stream, one event per press |
| `recognize(path)` | `Windows.Media.Ocr` words with bounding boxes |
| `ocrAvailable()` | Whether an OCR language is usable (§6.3) |
| `flashWindow()` | `FlashWindowEx` on the runner window, taskbar button only |
| `setAlwaysOnTop(bool)` | Toggles `HWND_TOPMOST` on the runner window |

### 4.3 Dart components

| Path | Role |
|---|---|
| `lib/capture/window_capture_source.dart` | `CaptureSource` for one window handle; throws a typed error when the window is closed or minimized |
| `lib/capture/windows_ocr_text_reader.dart` | `TextReader` over `recognize`, one `TextPiece` per OCR word |
| `lib/capture/window_target.dart` | Remembered window (process name + title) in `shared_preferences`; matching logic |
| `lib/desktop/capture_screen.dart` | The capturing view (§5) |
| `lib/ui/capture_strip.dart` | Moved from `lib/overlay/`; used by both the overlay panel and the capture screen |

`lib/desktop/` is the Windows counterpart to `lib/overlay/`. New copy goes in `app_en.arb` and `app_ja.arb`.

### 4.4 Platform switch

- `startCapture` branches on `Platform.isWindows`. Windows skips notifications, overlay permission, and consent, and pushes `CaptureScreen`. Android is unchanged.
- `flutter_overlay_window`, `google_mlkit_text_recognition`, and `screen_capture` have no Windows implementation. Windows code never calls them.
- On Windows, `CaptureController`'s `hideBubble` and `showBubble` are no-ops. WGC captures the window's own content, so the concapt window can overlap it.

### 4.5 Runner window

The runner opens a narrow window of about 420×860 logical pixels, so the phone-shaped layouts fit beside the game unchanged.

## 5. Capture screen

Shown while a session is capturing.

| Element | Behavior |
|---|---|
| Session name, run count | Live from the repository |
| Window picker | Lists windows by title and process. Preselects the remembered window if it is found; otherwise nothing is selected |
| Hotkey | Shows the bound key; a rebind control captures the next key press |
| Last run | The most recent saved run's nine scores |
| Outcome line | The latest outcome message, replacing Android's toasts |
| Edit form | On `CaptureNeedsReview`, `RunForm` and the capture strip appear inline; the taskbar button flashes; focus stays with the game |
| Always on top | Toggle, off by default |
| Stop | Unregisters the hotkey and returns to the session |

Remembered-window matching tries process name and title first, then process name alone if exactly one window matches.

## 6. Error handling

### 6.1 New outcome

`CaptureWindowUnavailable` joins the sealed `CaptureOutcome` family, with a reason of `closed` or `minimized`. Nothing is saved. On `closed` the picker opens.

### 6.2 Cases

| Case | Behavior |
|---|---|
| Chosen window closed | `CaptureWindowUnavailable(closed)`; the outcome line says the window is gone; the picker opens |
| Chosen window minimized | `CaptureWindowUnavailable(minimized)`; WGC yields no frames for minimized windows |
| Hotkey taken by another app | `registerHotkey` returns false; the capture screen says so and offers a rebind. No captures fire until a key is bound |
| Hotkey during a capture | Ignored; `trigger()` returns null while busy |
| Hotkey while the edit form is open | Ignored; the outcome line asks to save or discard first |
| Remembered window not found | Picker opens with nothing selected |

### 6.3 OCR language

The reader prefers `en-US`, then any installed Latin-script OCR language. If neither exists, `ocrAvailable()` is false and the capture screen explains how to add English in Windows Settings. A session cannot start capturing until then.

## 7. CSV export

Export stays shared. If `share_plus` can't hand a file over on Windows, Windows writes the CSV through a save dialog (`file_selector`). The plan verifies this first.

## 8. Testing

| Test | Runs on | Checks |
|---|---|---|
| Existing host suites | `flutter test` | Unchanged |
| Window target unit | Host | Matching by process + title, process alone, ambiguous, missing |
| Windows OCR accuracy | `flutter test integration_test/windows_ocr_accuracy_test.dart -d windows` | Every image in `ref-script/result/` (206 PC crops) and `ref-script/result-2026-10/` (phone captures) through `WindowsOcrTextReader`, `ResultParser`, and the sum check. Reports the pass rate; writes fixture JSON to `test/fixtures/ocr-windows/` |
| Fixture test | Host | `fixture_test.dart` also loads `ocr-windows/`, so parser changes keep both readers green |
| Manual | The developer's PC | New Windows section in `docs/manual-test-checklist.md`: game window, scrcpy window, overlapping windows, minimized and closed target, hotkey conflict, failed check flashes without taking focus, always on top |

The accuracy test reads the corpus in place, so the phone-wipe gotcha doesn't apply.

## 9. Risks

| Risk | Mitigation |
|---|---|
| `Windows.Media.Ocr` reads the corpus worse than ML Kit | Plan task 1 is the accuracy spike. The developer decides whether to go on. Fallbacks in order: upscale the frame before OCR, then Tesseract. A fallback amends this spec first |
| OCR word splits differ from ML Kit's and break the parser | Same spike; parser changes must keep both fixture sets green |
| Black bars or window chrome around the game confuse the parser | Capture crops to the client area; the parser works from positions relative to the totals; the spike covers scrcpy captures |
| Game runs elevated and blocks hotkeys or capture | `RegisterHotKey` works across integrity levels; if WGC fails on an elevated window, run concapt elevated too and note it in the README |
| WGC yellow border shows on Windows 10 | Cosmetic; `IsBorderRequired = false` removes it on Windows 11 |

## 10. Decisions

| Decision | Choice | Reason |
|---|---|---|
| Codebase | Same Flutter app, Windows target | Core, data, and screens carry over |
| Native code | New plugin `window_capture` | Android plugin's API is MediaProjection-shaped; one C++/WinRT build for capture, hotkey, and OCR |
| Trigger | Global hotkey | Keeps hands and focus on the game |
| Target | User-picked window | Covers the PC client and scrcpy |
| Capture | WGC | Captures GPU-rendered and occluded windows |
| OCR | `Windows.Media.Ocr` | Built in, offline, returns word boxes like ML Kit |
| Feedback | Capturing view in the main window | One engine; no multi-window |
| Failed check | Inline edit form, taskbar flash | Never steals focus from the game |
| Distribution | Run from the repo | Developer only for now |
