# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

- **Primary:** the developer, a Gakuen Idolmaster player running contest rehearsals on their own Android 14+ phone.
- **Later:** friends who also play, given a sideloaded APK. They know the game but not the app, so first-run and permission steps must explain themselves.
- **Situation:** the game is in the foreground and the player taps through hundreds of rehearsals per session. concapt sits on top as a bubble, then gets used on its own afterwards to read the numbers.

## Product Purpose

concapt turns rehearsal result screens into statistics. One tap on a floating bubble captures the result screen, reads the 9 member scores with on-device OCR, checks each stage's sum, and adds the run to a named session. Sessions show per-slot statistics, histograms, and CSV export.

Players use the numbers to:

- judge how consistent a setup is, from spread (P25/P75, histogram) as well as the average;
- compare teams or setups across sessions;
- watch how one character's score in a slot behaves over many runs;
- export CSV for spreadsheets or to share with others.

Success means a 200–500 run session gets captured with near-zero typing, and no misread score ever reaches the statistics.

## Positioning

The sum check sets concapt apart. Each stage's three member scores plus the crown bonus must equal the stage total, so every saved run has been verified against the game's own arithmetic. A run that fails opens an edit panel over the game while the result is still on screen. concapt replaces a PC script (pyautogui + Tesseract) that had no such check.

## Operating Context

- Capture happens mid-game. The bubble must stay out of the way, never appear in its own capture, and give feedback without leaving the game (toasts, an edit panel over the game).
- Analysis happens later, in the main app: sessions list, session detail with three stage cards (L/M/R), series detail with a histogram.
- One session = one fixed team. Each slot holds the same character for every run; a character change means a new session.
- Sessions typically hold 200–500 runs.

## Capabilities and Constraints

- **Terminology:** session, run, stage (1–3), slot (left / middle / right), series (stage × slot, 9 per session), stage total (`Pt`), crown bonus (`+`), sum check, edited run.
- **Stats per series:** n, mean (whole number), median, min, max, P25, P75 (Excel `PERCENTILE.INC`). Empty series shows "—".
- **Capture outcomes:** auto-save on pass; edit panel on a failed sum or missing field; toasts for no result screen, partial reads, and duplicates of the last run.
- **Out of scope:** auto-tapping, auto-detecting the result screen, sync, recognizing characters by portrait.
- **Technical:** Android only for now (`minSdk` 26), sideloaded. Two Flutter engines (main app and overlay) share one SQLite database. PC and iOS builds are planned later through platform seams.
- **Language:** the app UI ships in English and Japanese. The spec's copy is written in English only; Japanese strings are not yet planned.

## Brand Commitments

- **Name:** concapt.
- **Design system:** Material 3 in both the main app and the overlay. Theme colors and text styles only; no hard-coded colors or font sizes. Numbers display through `lib/ui/format.dart`.
- **Visual identity:** "The Printed Rate Table", recorded in `DESIGN.md`.

## Evidence on Hand

- `ref-script/result/`: 206 real rehearsal result captures (461×764 PNG crops), the OCR test corpus.
- `ref-script/contest.py`: the original PC script.
- No users beyond the developer, no testimonials, no accuracy figures yet. Phone-capture OCR accuracy is still to be measured.

## Product Principles

1. **Never let a bad number in.** The sum check guards every saved run; when it fails, fixing beats skipping.
2. **Stay out of the game's way.** Capture is one tap with feedback in place, and the player never leaves the game to save a run.
3. **Show the spread as well as the average.** Consistency matters as much as the mean when comparing setups.
4. **Raw data stays portable.** CSV export carries every raw value, so analysis can continue outside the app.

## Accessibility & Inclusion

- English and Japanese UI.
