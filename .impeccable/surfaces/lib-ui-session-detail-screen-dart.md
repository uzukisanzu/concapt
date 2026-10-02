---
version: 1
slug: "lib-ui-session-detail-screen-dart"
primary_target: "lib/ui/session_detail_screen.dart"
related_targets: ["lib/ui/stats_card.dart","lib/ui/series_detail_screen.dart"]
---

# Session detail

Confirmed with the user on 2026-10-02 through `/impeccable shape session detail`. Session detail sets the visual world for the whole app; series detail and the other screens inherit it.

## Scope and mode

- Targets: `lib/ui/session_detail_screen.dart`, `lib/ui/stats_card.dart`, `lib/ui/series_detail_screen.dart`
- Mode: Operate
- Build path: code-led (no image generation on this machine)

## Job and audience

- The player opens it on their phone in ordinary daylight, after or between rehearsals.
- First read: which slot scores what, meaning the mean for each stage × slot.

## Direction

- World: Japanese Wiki Density, a Japanese high-density site
- Seed key `264b7ebc`; the user chose dealt challenger `japanese-high-density-web` (card kind: challenger)
- Quality bar, for craft level only and not composition:
  - board: https://impeccable.style/worlds/cards/japanese-high-density-web.webp
  - hero: https://impeccable.style/worlds/cards/japanese-high-density-web-hero.webp
- The world lends type, palette, density, and one signature move. Layout and controls stay standard Material 3.

### Palette

Fixed light scheme with no Dynamic Color. It replaces the indigo placeholder.

| Role | Hex |
|---|---|
| White ground | `#FFFFFF` |
| Ink | `#111111` |
| Utility red (primary) | `#E60012` |
| Light gray fill | `#F2F2F2` |
| Line gray rule | `#E0E0E0` |
| Mid gray | `#D6D6D6` |
| Dark gray secondary text | `#7A7A7A` |

Dark mode gets its own designed scheme, never an inversion. Both engines use it.

### Type

- Compact gothic: Roboto, with Noto Sans JP as the Japanese fallback. Leading is tight and every style keeps tabular figures.
- Numerals stay Roboto, with no extra face bundled (the user decided this).
- Means use a price-numeral voice, set bold and larger.

### Signature move

Each stage is a hairline-ruled module under a small red numbered tab ("01 Stage 1"). Modules pack edge to edge, with no elevated card shells.

## Layout

- App bar: the session name, with Export CSV as an action.
- Stats: three stage modules, each holding the full seven-row table (n, mean, median, min, max, P25, P75) under L / M / R columns.
  - The mean row is clearly the largest.
  - All three modules fit in about one phone screen, and rows never go below 12sp.
  - Tapping a column opens series detail. Keys stay `slot-<stage>-<slot>`.
- Runs: its own red tab with the run count.
  - Each run is a dense ruled row: run number and time on the left, a 3×3 block of scores on the right.
  - "Edited" is an outlined red tag.
  - Tap edits a run; long-press deletes it.
- Capture: a red extended FAB with two states, Start capturing and Stop capturing.
- Series detail: histogram bars in ink or gray, the mean marker in red, the median marker in ink.

## States and ranges

- 0–500 runs, with 5- to 7-digit scores
- An empty series shows "—"; an empty session shows a runs message next to the FAB
- Loading, capturing, and capture consent declined (snackbar)

## Boundaries

- Ruled out by the user: idol fan-site styling, bare-spreadsheet Material cards, fitness/finance KPI tiles, long scrolling.
- Don't imitate the wiki itself. That means no tiny type and no badge clutter.
- Keep the plan's behavior, strings, widget keys, and tests. Copy stays in the ARB files; numbers go through `lib/ui/format.dart`.

## Direction contract

- **THESIS:** The session is a printed rate table, not a dashboard. Nine means read at a glance from three ruled stage modules; it refuses the category default of stacked elevated stat cards, KPI tiles, and long scroll.
- **OWN-WORLD:** White ground, ink #111111 type, 1px #E0E0E0 hairline rules, #F2F2F2 header bands, one utility red #E60012 for tabs, the FAB, the mean marker, and the outlined "edited" tag. Small red numbered tabs ("01") sit on the top rule of each module. Modules butt edge to edge with no shadows or radii. Roboto tabular figures; means bold and large like price numerals. Dark mode is designed: near-black ground, warm off-white ink, a red lifted for contrast.
- **STORY:** The player sees which slot scores what, trusts it (n is in the table), taps a column for the spread, scrolls to runs to fix or remove one, and starts or stops capture from the FAB.
- **FIRST VIEWPORT:** App bar with the session name and an Export CSV action. Below it, three stage modules fill about one screen, each with an L/M/R header row, a dominant bold mean row, and six compact rows (≥12sp). The Runs tab and its count peek at the bottom edge. The red extended FAB (Start/Stop capturing) sits bottom-right.
- **FORM:** Japanese high-density web table (`japanese-high-density-web`, the dealt challenger chosen over the canon), seed key `264b7ebc`, operate mode, code-led.
- **FINISH:** unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance

## Still to do

- Build Tasks 11–15 against this contract, then run the finish review. The documenter writes `DESIGN.md` and `.impeccable/design.json`.
