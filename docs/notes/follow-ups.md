# Follow-ups

Work set aside when the Android branch wrapped up (2026-10-03), with the reason and what picking it up takes.

## From the overlay finish review

| Item | Why set aside | To pick it up |
|---|---|---|
| Panel fits its content | Biggest change; reworks resize and move code that took two device rounds | Shrink-wrap `RunForm`'s list, measure the panel, `resizeOverlay(340, min(measured, 560))`; re-measure on fold and strip toggles and in `_setMoving`. Change DESIGN.md's Overlay line to "up to 560dp tall". The fixed 560dp now leaves over 85dp blank over the game |
| White ring on the bubble | New visual not in DESIGN.md | 2px `onPrimary` border on `_Bubble`'s circle; add it to DESIGN.md. Red on the game's gray is about 1.3:1 in luminance, so only hue sets it apart |
| Grouped digits in fields | Changes typing in the main app's editor too; caret handling needs care | `TextInputFormatter` that regroups with `formatInt`, caret at the end; seed controllers with `formatInt`. `_draft` already strips commas |

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

## Not verified on the device

- The bubble-failed toast (3c049ba)
- The save, export, and load failure snackbars, which need a failing database or file system to trigger
