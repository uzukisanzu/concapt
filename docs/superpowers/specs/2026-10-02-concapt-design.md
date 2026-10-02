# concapt — Design Spec

- **Date:** 2026-10-02
- **Status:** Draft for review
- **Platform:** Android first (Flutter); PC and iOS later

## 1. Goal

Collect per-member scores from Gakuen Idolmaster contest rehearsal results (リハーサル結果) across N runs and show statistics for them. Capture happens in-game with one tap on a floating bubble.

Replaces the PC workflow in `ref-script/contest.py` (pyautogui + Tesseract) with an Android app. The app also adds a sum check, which catches misreads before they reach the statistics.

## 2. Scope

### In scope

- Floating bubble over the game that captures the result screen
- On-device OCR and position-based parsing of the result screen
- Sum check per stage, auto-save on pass, edit panel on fail
- Named sessions holding runs
- Per-session statistics for 9 series
- CSV export per session

### Out of scope

- Auto-tapping through rehearsals
- Auto-detecting the result screen (manual bubble tap only)
- PC and iOS builds (seams are designed in; see §9)
- Sync between devices
- Recognizing characters by portrait

## 3. Requirements

### 3.1 The result screen

All three stages are visible on one screen. Each stage shows:

| Element | Example | Used for |
|---|---|---|
| Stage total | `214,882Pt` | Sum check; stored |
| Member scores (3, left to right) | `120,918  39,482  30,299` | **Statistics**; stored |
| Crown bonus | `+24183` | Sum check; stored |
| Total power (総合力) | `58929` | Ignored |

**Sum check:** `left + middle + right + bonus == total`, per stage. This holds for all three stages of the reference screenshot (`ref-script/result/Wed Jan 28 08_34_17 2026.png`).

### 3.2 Statistics

- **Series:** 9, one per stage × slot (S1-L, S1-M, S1-R, …, S3-R)
- **Assumption:** each slot holds the same character for every run in a session; a team change means a new session
- **Per series:** n, mean, median, min, max, P25, P75
- **Mean:** shown rounded to a whole number
- **Median:** average of the two middle values when n is even
- **Percentiles:** linear interpolation, matching Excel `PERCENTILE.INC`
- **Empty series:** shown as "—"

### 3.3 Device

- Android 14+ phone (the user's device)
- `minSdk` 26
- Personal use, sideloaded

## 4. Architecture

### 4.1 Overview

```
Main app engine (Dart)          Overlay engine (Dart)              Native (Kotlin)
──────────────────────          ─────────────────────              ───────────────
Sessions, stats, run editor     Bubble ⇄ edit panel, toast         CaptureService
"Start capturing" ─────────────────────────────────────────────▶   consent + projection
                                tap → capture() ─── channel ───▶   latest frame → PNG
                                ◀────────────────────────────────  bytes
                                TextReader → ResultParser → SumCheck
                                → save to the database file
Reloads on resume ◀── same SQLite database (WAL mode) ──┘
```

### 4.2 Components

| Component | Layer | Responsibility |
|---|---|---|
| Main app | Flutter, main engine | Sessions, stats, run editor, CSV export, starts capture |
| Overlay | Flutter, second engine via `flutter_overlay_window` | Bubble, toast, edit panel; runs the capture pipeline |
| CaptureService | Kotlin, foreground service (`mediaProjection` type) | Holds the projection and virtual display; returns the latest frame as PNG bytes; reports projection stop |
| TextReader | Dart, `google_mlkit_text_recognition` (Latin) | Bitmap → list of `TextPiece` |
| ResultParser | Pure Dart | `TextPiece`s → `ParseResult` |
| SumCheck | Pure Dart | Validates each stage |
| Stats | Pure Dart | Values → `Summary` |
| Repository | Dart, drift on SQLite (WAL) | Sessions and runs; opened by both engines |

### 4.3 Platform seams

The core never imports Android code. Three interfaces isolate the platform:

| Interface | Android (now) | PC (later) | iOS (later) |
|---|---|---|---|
| `CaptureTrigger` | Overlay bubble | Global hotkey | Back Tap Shortcut |
| `CaptureSource` | MediaProjection channel | Windows Graphics Capture of the game window | Screenshot handed in via App Intent |
| `TextReader` | ML Kit | `Windows.Media.Ocr` | ML Kit |

### 4.4 Engine boundaries

- The main app shows the capture consent prompt, since it needs an Activity. It starts CaptureService, then launches the overlay with the session id.
- The overlay runs the full pipeline itself, so capture keeps working if Android kills the main app.
- Both engines open the same database file. Drift stream updates don't cross engines, so the main app re-queries on resume.

## 5. Capture and parsing

### 5.1 Capture

1. User taps the bubble.
2. Overlay hides the bubble.
3. CaptureService waits for a frame with a timestamp after the hide, then encodes it to PNG.
4. Overlay shows the bubble again and passes the bytes to TextReader.

### 5.2 TextReader output

```dart
class TextPiece {
  final String text;
  final Rect box;
}
```

Pieces come from ML Kit elements (words), not lines. ML Kit can merge the three member scores into one line, and elements keep them apart.

### 5.3 ResultParser

1. **Classify.** Strip commas and spaces. Inside otherwise-numeric tokens, map `O`→`0` and `l`/`I`→`1`. Then:
   - **Total:** a number with `Pt` attached or as the adjacent piece
   - **Bonus:** `+` followed by digits; drop junk before the `+` (the crown icon)
   - **Plain number:** anything else numeric
2. **Find stages.** Require exactly 3 totals. Sort them by y as Stages 1–3. A stage's band runs from its total down to the next total (or the image bottom).
3. **Find members.** In each band, take the first row below the total with exactly 3 plain numbers. Pieces share a row when their vertical centers differ by less than half the median piece height. Sort the row by x into left, middle, and right.
4. **Find bonus.** The bonus piece in the band.

The 総合力 number sits alone on its row, so step 3 never picks it.

### 5.4 Outcomes

| Result | Behavior |
|---|---|
| 3 stages parsed, all sums pass | Auto-save; toast "Run N saved" |
| Parsed but a sum fails, or a field is missing | Edit panel opens, pre-filled with the parsed values; failing stages highlighted |
| No totals found | Toast "No result screen detected"; nothing saved |
| Identical to the session's last run (9 scores + 3 totals) | Toast "Same as run N, skipped"; nothing saved |

### 5.5 Edit panel

- 15 fields: per stage, left, middle, right, bonus, and total
- Re-runs the sum check as values change
- Save with all sums passing → save as edited
- Save with a sum still failing → confirm "Save anyway?", then save as edited
- Cancel → discard the capture

## 6. Data

### 6.1 Schema (drift)

| Table | Columns |
|---|---|
| `sessions` | `id`, `name`, `created_at` |
| `runs` | `id`, `session_id` → sessions, `seq` (run number within session), `captured_at`, `edited` |
| `stage_results` | `run_id` → runs, `stage` (1–3), `left`, `middle`, `right`, `bonus`, `total`; PK (`run_id`, `stage`) |

Deleting a session cascades to its runs and stage results.

### 6.2 CSV export

One row per run, raw values only, shared through `share_plus`:

```
run,captured_at,s1_left,s1_middle,s1_right,s1_bonus,s1_total,s2_left,…,s3_total
1,2026-10-02T08:34:17,120918,39482,30299,24183,214882,…
```

## 7. Screens

### 7.1 Sessions

- List: name, run count, last capture time
- New session (name prompt)
- Rename and delete (with confirm)

### 7.2 Session detail

- **Start capturing:** overlay permission check → capture consent → CaptureService → overlay bound to this session
- **Stats:** three cards, one per stage; columns L/M/R; rows n, mean, median, min, max, P25, P75
- **Runs:** newest first; time, 9 scores, "edited" mark; tap to edit, long-press to delete
- **Export CSV**

### 7.3 Run editor

The same form as the overlay edit panel, opened from the run list.

## 8. Error handling

| Situation | Behavior |
|---|---|
| Overlay permission missing | Open "Display over other apps" settings with an explanation |
| Capture consent declined | Stay on session detail; show a message |
| Projection stopped (status-bar chip, screen lock) | CaptureService signals the overlay; bubble and service close; next Start re-prompts |
| "Single app" sharing aimed at the wrong app | Results in "No result screen detected"; the pre-prompt screen tells the user to pick the game or the entire screen |
| ML Kit error or timeout | Toast "Couldn't read screen, try again"; nothing saved |

## 9. Testing

### 9.1 Test corpus

`ref-script/result/` holds 206 rehearsal result captures (461×764 PNG crops from the PC version). They're lower resolution than phone captures, which makes them a harder OCR case.

### 9.2 Tests

| Test | Runs on | Checks |
|---|---|---|
| ResultParser unit | Host (`flutter test`) | Fixtures: `TextPiece` JSON recorded from the corpus. Synthetic: missing number, merged tokens, `O`/`0` misread, only 2 totals, 総合力 row |
| Accuracy | Device or emulator (integration test) | All 206 images through TextReader + ResultParser + SumCheck; reports the pass rate; exports the fixture JSON |
| Stats unit | Host | Hand-computed values, including even-n median and percentile interpolation |
| Repository | Host | In-memory drift database; cascade deletes; seq numbering |
| Overlay and capture | Phone, manual | Checklist: permission flow, bubble drag, capture excludes bubble, auto-save toast, edit panel, projection stop on screen lock |

## 10. Risks

| Risk | Mitigation |
|---|---|
| `flutter_overlay_window` falls short (drag, resizing between bubble and panel, engine lifetime) | Prove it first in the plan. Fallback: a small Kotlin host showing a Flutter view; the Dart overlay code stays the same |
| Two engines writing the same SQLite file | WAL mode; the overlay only inserts; the main app re-queries on resume |
| OCR accuracy on phone captures differs from the corpus | Measure on real phone captures early; the sum check guards every saved run |
| Game UI changes | The parser relies only on `Pt`, `+`, and row structure, not coordinates |

## 11. Decisions

| Decision | Choice | Reason |
|---|---|---|
| Stack | Flutter | User knows it; core carries over to PC and iOS |
| OCR | ML Kit on-device (Latin) | Free, offline, fast; only digits, `Pt`, and `+` are needed |
| Storage | drift | Actively maintained; typed queries |
| Trigger | Bubble tap | Predictable; auto-detect costs battery and risks duplicates |
| Grouping | Stage × slot | Simple and reliable given fixed teams per session |
| Failed checks | Edit panel over the game | Fix while the result is still on screen |
