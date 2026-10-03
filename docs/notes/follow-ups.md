# Follow-ups

Work set aside when the Android and Windows branches wrapped up (2026-10-03), with the reason and what picking it up takes.

## From the overlay finish review

| Item | Why set aside | To pick it up |
|---|---|---|
| Panel fits its content | Biggest change; reworks resize and move code that took two device rounds | Shrink-wrap `RunForm`'s list, measure the panel, `resizeOverlay(340, min(measured, 560))`; re-measure on fold and strip toggles and in `_setMoving`. Change DESIGN.md's Overlay line to "up to 560dp tall". The fixed 560dp now leaves over 85dp blank over the game |
| White ring on the bubble | New visual not in DESIGN.md | 2px `onPrimary` border on `_Bubble`'s circle; add it to DESIGN.md. Red on the game's gray is about 1.3:1 in luminance, so only hue sets it apart |
| Grouped digits in fields | Changes typing in the main app's editor too; caret handling needs care | `TextInputFormatter` that regroups with `formatInt`, caret at the end; seed controllers with `formatInt`. `_draft` already strips commas |

## From the capture screen finish review

| Item | Why set aside | To pick it up |
|---|---|---|
| Minimum window size | The layout holds at 360 × 560; below about 320dp wide, 7-digit values crowd the member fields | Handle `WM_GETMINMAXINFO` in `windows/runner/win32_window.cpp`, setting `ptMinTrackSize` to 360 × 560 logical scaled by `GetDpiForWindow` |

## Deferred minors left as is

| Item | Why |
|---|---|
| ML Kit read timeout doesn't cancel the read | The plugin has no cancel API |
| `overlayListener` is single-subscription | Only breaks on hot restart |
| `CaptureStrip` asserts on a zero-size rect | The parser always pads stage bounds |
| No test for `CaptureTarget` | A two-line wrapper; testing it needs `shared_preferences_platform_interface` as a dev dependency |
| `CaptureTarget` not cleared on stop | A stale value is gated by `isRunning` and `isActive`, and start overwrites it |
| `capture.png` has a fixed name and is never deleted | One cache file, overwritten per capture; deleting it on stop would race the panel's decode |
| `addRun`'s raw SQL uses snake_case column names | Drift's name getters would hurt readability; the concurrency test fails on a rename |
| Panel opens after the frame decodes | Review path only; chosen to leave it |

## Windows deferred minors

| Item | Why |
|---|---|
| The detached OCR worker can touch a freed plugin if concapt closes mid-read | Only on closing during a read; the process is exiting |
| An unknown OCR-done message id is undefined behavior in `jobs_.extract` | Ids come only from `Recognize`; no other sender |
| A late `FrameArrived` callback could signal a closed event handle | The handler is removed before the handle closes; a race window only |
| A `DwmGetWindowAttribute` failure in `ClientCrop` is ignored | Falls back to the full frame, which still reads |
| A run saved after leaving the capture screen mid-capture shows only after a reload | Rare; session detail re-queries on resume |
| All captures share `capture.png` | One capture at a time; the re-read stops at the capture's deadline |
| An unmodified letter or digit hotkey swallows that key system-wide, without a warning | Defaults to F9; the user picks the key |
| The capture screen stays blank if its startup throws, for example on corrupt prefs | Needs corrupt prefs; restart clears it |
| The `+` join could pair `Lv+` with `12` | The sum check catches it |
| Refresh doesn't fall back to the remembered window, so a reopened scrcpy must be picked again | Developer declined for now; when nothing is selected after a refresh, use `RememberedWindow.findIn` |
| The total re-read sweeps fully (about 30–40 small reads) on member misreads too, delaying the edit form | Under a second; only on failing stages |
| If the game changes its bonus rule, the true bonus can't be typed; "Save anyway" stores the computed one | Every run would fail loudly first; members and totals still save |
| The Windows CSV save doesn't add `.csv` to a typed name and shows no confirmation | The dialog suggests `<session>.csv` |
| `CLAUDE.md` doesn't list `file_selector`, and `file_selector_android` ships unused in the APK | Docs gap; no permissions added |
| No test for a recovered stage with an empty band in `ResultParser._bounds` | Unreachable today: recovery needs a member row |

## Not verified on the device

- The bubble-failed toast (3c049ba)
- The save, export, and load failure snackbars, which need a failing database or file system to trigger
- Windows W12 (Japanese display language): this PC runs Windows 11 Home Single Language. Host tests cover the strings; Windows passing a Japanese locale to Flutter is unverified
- Windows W14 (elevated game) and the PC game client versions of W1, W2, and W4: the game isn't installed; all four passed against scrcpy where they apply
