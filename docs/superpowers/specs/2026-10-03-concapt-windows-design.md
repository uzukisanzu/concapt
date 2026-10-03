# concapt for Windows — Design Spec

- **Date:** 2026-10-03
- **Status:** Approved; amended 2026-10-03 after the OCR spike and the computed bonus (§5.1)
- **Platform:** Windows 10 2004+ / Windows 11, alongside the Android app
- **Builds on:** `2026-10-02-concapt-design.md` (the Android spec). Everything not covered here is unchanged.

## 1. Goal

Capture rehearsal results on PC, replacing `ref-script/contest.py`. The player runs the game in a window on Windows (the PC client, or the phone mirrored with scrcpy), presses a global hotkey, and concapt captures that window, reads it, checks each stage's sum, and saves the run.

## 2. Scope

### In scope

- Windows target for the existing Flutter app
- Window picker: capture any visible top-level window
- Global hotkey trigger, rebindable
- Windows Graphics Capture (WGC) of the chosen window
- OCR with `Windows.Media.Ocr`, one pass, with the bonus computed (§5.1)
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
| `recognize(path, region, scale)` | `Windows.Media.Ocr` words with bounding boxes in the image's own pixels. With `region`, reads only that part, enlarged `scale` times (§5.1) |
| `ocrAvailable()` | Whether an OCR language is usable (§7.3) |
| `flashWindow()` | `FlashWindowEx` on the runner window, taskbar button only |
| `setAlwaysOnTop(bool)` | Toggles `HWND_TOPMOST` on the runner window |

### 4.3 Dart components

| Path | Role |
|---|---|
| `lib/capture/window_capture_source.dart` | `CaptureSource` for one window handle; throws a typed error when the window is closed or minimized |
| `lib/capture/windows_ocr_text_reader.dart` | `TextReader` over `recognize`: both passes' words as `TextPiece`s, plain pass first |
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

## 5. Reading a frame

### 5.1 OCR and the computed bonus

The spike measured `Windows.Media.Ocr` against the corpus and a live scrcpy frame:

| Input | Result |
|---|---|
| Live scrcpy window, 442 × 984 | Reads all totals and member scores; misses every bonus |
| Corpus, 237 images | Drops bonuses, and on phone captures whole member rows |

The bonus no longer needs reading. Every stage's bonus equals its highest member score ÷ 5, rounded down (618 / 618 corpus stages; Android spec §3.1). The sum check computes it, so the reader makes one pass:

- The frame as captured, shrunk to at most 1300 px on its longest side. Taller frames lose whole member rows. Boxes map back to frame pixels.

With the computed bonus, this one pass reads 228 / 237 corpus images and both readable live scrcpy frames. A second pass keyed to the blue bonus pills, tried first, scored no higher: scrcpy's video carries color at half resolution, which blurred bonus 3s into 5s.

Window capture grabs the window as drawn, so a taller scrcpy window gives each digit more pixels.

Windows OCR drops or garbles totals holding `444` (`204,444Pt` vanishes, `444,386Pt` reads as `3` `86pt`), yet reads them once a crop cuts off `Pt`. So when a stage fails the sum check but has all three members, the controller re-reads its total line: the crop's right edge sweeps leftward in steps of a sixth of the line's height, each crop read at 2× and 3×. A reading counts only if it equals the members plus the bonus. A total still missing opens the edit form with that field empty (Android spec §5.4). Live samples: 3 of 3 `444` frames recover; `206,666Pt` and `411,599Pt` read without help.

Windows OCR cannot read 7-digit totals such as `1,022,411Pt`, even cropped and enlarged. Those runs fail the sum check and open the edit form.

`ResultParser` is shared with Android and sees what ML Kit would give it, with one fix: a lone `+` joins the number to its right, since Windows OCR often reads `+` and `46150` as two words. Bonus words still bound the member row when found.

### 5.2 Acceptance

The gate is live captures, not the corpus. The 461 × 764 corpus crops read worse than live windows. The developer captures about 20 real results through the finished pipeline; most should save without the edit form. Every miss is caught by the sum check and opens the edit form, so none reaches the statistics. The corpus accuracy test stays as a regression measure and records fixtures.

## 6. Capture screen

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

## 7. Error handling

### 7.1 New outcome

`CaptureWindowUnavailable` joins the sealed `CaptureOutcome` family, with a reason of `closed` or `minimized`. Nothing is saved. On `closed` the picker opens.

### 7.2 Cases

| Case | Behavior |
|---|---|
| Chosen window closed | `CaptureWindowUnavailable(closed)`; the outcome line says the window is gone; the picker opens |
| Chosen window minimized | `CaptureWindowUnavailable(minimized)`; WGC yields no frames for minimized windows |
| Hotkey taken by another app | `registerHotkey` returns false; the capture screen says so and offers a rebind. No captures fire until a key is bound |
| Hotkey during a capture | Ignored; `trigger()` returns null while busy |
| Hotkey while the edit form is open | Ignored; the outcome line asks to save or discard first |
| Remembered window not found | Picker opens with nothing selected |

### 7.3 OCR language

The reader prefers `en-US`, then any installed Latin-script OCR language. If neither exists, `ocrAvailable()` is false and the capture screen explains how to add English in Windows Settings. A session cannot start capturing until then.

## 8. CSV export

Export stays shared on Android. On Windows, the share sheet can't take a file from an app run outside a package (W13 showed "We couldn't show you all the ways you could share"), so Export CSV opens a save dialog (`file_selector`) suggesting `<session>.csv` and writes the file there.

## 9. Testing

| Test | Runs on | Checks |
|---|---|---|
| Existing host suites | `flutter test` | Unchanged |
| Window target unit | Host | Matching by process + title, process alone, ambiguous, missing |
| Windows OCR accuracy | `flutter test integration_test/windows_ocr_accuracy_test.dart -d windows` | Every image in `ref-script/result/` (206 PC crops) and `ref-script/result-2026-10/` (phone captures) through `WindowsOcrTextReader`, `ResultParser`, and the sum check. Reports the pass rate as a regression measure, not a gate; writes fixture JSON to `test/fixtures/ocr-windows/` |
| Live acceptance | The developer's PC | About 20 real results captured through the finished pipeline (§5.2) |
| Fixture test | Host | `fixture_test.dart` also loads `ocr-windows/`, so parser changes keep both readers green |
| Manual | The developer's PC | New Windows section in `docs/manual-test-checklist.md`: game window, scrcpy window, overlapping windows, minimized and closed target, hotkey conflict, failed check flashes without taking focus, always on top |

The accuracy test reads the corpus in place, so the phone-wipe gotcha doesn't apply.

## 10. Risks

| Risk | Mitigation |
|---|---|
| OCR still misreads too many live members or totals | The live acceptance run (§5.2) decides. Next fallback: Tesseract, after amending this spec |
| The game changes its bonus rule | Every run fails the sum check and opens the edit form; nothing wrong saves silently |
| OCR word splits differ from ML Kit's and break the parser | Same spike; parser changes must keep both fixture sets green |
| Black bars or window chrome around the game confuse the parser | Capture crops to the client area; the parser works from positions relative to the totals; the spike covers scrcpy captures |
| Game runs elevated and blocks hotkeys or capture | `RegisterHotKey` works across integrity levels; if WGC fails on an elevated window, run concapt elevated too and note it in the README |
| WGC yellow border shows on Windows 10 | Cosmetic; `IsBorderRequired = false` removes it on Windows 11 |

## 11. Decisions

| Decision | Choice | Reason |
|---|---|---|
| Codebase | Same Flutter app, Windows target | Core, data, and screens carry over |
| Native code | New plugin `window_capture` | Android plugin's API is MediaProjection-shaped; one C++/WinRT build for capture, hotkey, and OCR |
| Trigger | Global hotkey | Keeps hands and focus on the game |
| Target | User-picked window | Covers the PC client and scrcpy |
| Capture | WGC | Captures GPU-rendered and occluded windows |
| OCR | `Windows.Media.Ocr`, one pass | Built in, offline, returns word boxes like ML Kit |
| Bonus | Computed: highest member ÷ 5, rounded down | Holds in 618 / 618 stages; reading it was the main source of misses |
| Acceptance | Live captures | The corpus crops are harder than live windows; the sum check catches every miss |
| Feedback | Capturing view in the main window | One engine; no multi-window |
| Failed check | Inline edit form, taskbar flash | Never steals focus from the game |
| Distribution | Run from the repo | Developer only for now |
