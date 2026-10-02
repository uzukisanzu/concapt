---
name: concapt
description: Rehearsal score capture and statistics for Gakuen Idolmaster, set as a printed rate table.
colors:
  utility-red: "#E60012"
  red-tint: "#FFE5E6"
  red-deep: "#7A0009"
  ink: "#111111"
  white-ground: "#FFFFFF"
  band-gray: "#F2F2F2"
  hairline-gray: "#E0E0E0"
  stroke-gray: "#D6D6D6"
  secondary-gray: "#6B6B6B"
  alarm-red: "#C4000F"
  alarm-tint: "#FDECEC"
  alarm-deep: "#8C000B"
  dark-lifted-red: "#FF5A5F"
  dark-on-red: "#2B0003"
  dark-ground: "#151413"
  dark-ink: "#EDE8E3"
  dark-band: "#2A2826"
  dark-hairline: "#33312F"
  dark-stroke: "#4A4744"
  dark-secondary: "#A39E99"
  dark-alarm-tint: "#4A1210"
  dark-alarm-ink: "#FFDAD6"
typography:
  mean-numeral:
    fontFamily: "Roboto, Noto Sans JP, sans-serif"
    fontSize: "22sp"
    fontWeight: 700
    lineHeight: 1.2
    fontFeature: "tnum"
  title:
    fontFamily: "Roboto, Noto Sans JP, sans-serif"
    fontSize: "14sp"
    fontWeight: 700
    lineHeight: 1.2
    fontFeature: "tnum"
  title-medium:
    fontFamily: "Roboto, Noto Sans JP, sans-serif"
    fontSize: "16sp"
    fontWeight: 700
    lineHeight: 1.2
    fontFeature: "tnum"
  body:
    fontFamily: "Roboto, Noto Sans JP, sans-serif"
    fontSize: "14sp"
    fontWeight: 400
    lineHeight: 1.3
    fontFeature: "tnum"
  body-small:
    fontFamily: "Roboto, Noto Sans JP, sans-serif"
    fontSize: "12sp"
    fontWeight: 400
    lineHeight: 1.3
    fontFeature: "tnum"
  label:
    fontFamily: "Roboto, Noto Sans JP, sans-serif"
    fontSize: "12sp"
    fontWeight: 400
    lineHeight: 1.2
    fontFeature: "tnum"
  axis-label:
    fontFamily: "Roboto, Noto Sans JP, sans-serif"
    fontSize: "11sp"
    fontWeight: 400
    lineHeight: 1.2
    fontFeature: "tnum"
rounded:
  none: "0px"
  field: "2px"
  control: "4px"
spacing:
  hair: "2px"
  xs: "4px"
  sm: "8px"
  gutter: "12px"
  md: "16px"
components:
  module-band:
    backgroundColor: "{colors.band-gray}"
    textColor: "{colors.ink}"
    typography: "{typography.title}"
    rounded: "{rounded.none}"
    padding: "0 12px 8px 12px"
  module-tab:
    backgroundColor: "{colors.utility-red}"
    textColor: "{colors.white-ground}"
    typography: "{typography.label}"
    rounded: "{rounded.none}"
    padding: "2px 6px"
  stat-row:
    backgroundColor: "{colors.white-ground}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    padding: "2px 8px"
  stat-row-mean:
    backgroundColor: "{colors.white-ground}"
    textColor: "{colors.ink}"
    typography: "{typography.mean-numeral}"
    padding: "4px 8px"
  run-row:
    backgroundColor: "{colors.white-ground}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    padding: "8px 12px"
  edited-tag:
    backgroundColor: "{colors.white-ground}"
    textColor: "{colors.utility-red}"
    typography: "{typography.label}"
    rounded: "{rounded.none}"
    padding: "0 4px"
  fab-capture:
    backgroundColor: "{colors.utility-red}"
    textColor: "{colors.white-ground}"
    rounded: "{rounded.control}"
  button-filled:
    backgroundColor: "{colors.utility-red}"
    textColor: "{colors.white-ground}"
    rounded: "{rounded.control}"
  button-text:
    textColor: "{colors.utility-red}"
    rounded: "{rounded.control}"
  input-field:
    backgroundColor: "{colors.band-gray}"
    textColor: "{colors.ink}"
    typography: "{typography.body}"
    rounded: "{rounded.field}"
    padding: "10px"
  capture-bubble:
    backgroundColor: "{colors.utility-red}"
    textColor: "{colors.white-ground}"
    size: "56dp"
---

# Design System: concapt

## Overview

**Creative North Star: "The Printed Rate Table"**

concapt reads like a page from a Japanese high-density reference site. Each session sits on white paper as ruled tables, the way a fare chart or a price list does. Nine means read at a glance from three stage modules that butt edge to edge. There are no floating cards, KPI tiles, or decorative fills. Density comes from hairline rules and tight leading, while text never drops below a legible size.

The world lends type, palette, density, and one signature move: a small red numbered tab hanging from the top rule of each module. Layout and controls stay standard Material 3. One theme, `buildTheme(Brightness)` in `lib/ui/theme.dart`, serves both Flutter engines (the main app and the capture overlay) in light and dark. Both schemes are fixed. There is no Dynamic Color, so pass/fail colors, the edited tag, and histogram markers look the same on every phone. Dark mode is designed in its own right, with a near-black warm ground, warm off-white ink, and a lifted red. It is not an inversion of light.

The user ruled out idol fan-site styling, bare-spreadsheet Material cards, fitness or finance KPI tiles, and long scrolling. The wiki is a reference for craft, not a template, so the app avoids tiny type and badge clutter.

**Key Characteristics:**
- White ground, ink type, 1px hairline rules, gray header bands
- One utility red for tabs, the FAB, the bubble, the mean marker, and the edited tag
- Modules flush edge to edge, square corners, no shadows on content
- Roboto with tabular figures everywhere; means set bold and large like price numerals
- Fixed light and dark schemes shared by both engines

## Colors

A white-and-ink palette with a single utility red and a ladder of neutral grays. Values map to Material `ColorScheme` roles in `lib/ui/theme.dart`.

### Primary
- **Utility Red** (`primary`): module tabs, the capture FAB, the overlay bubble, filled buttons, the histogram mean line, the outlined edited tag, and the focused input border.
- **Red Tint** (`primaryContainer`) and **Red Deep** (`onPrimaryContainer`): the Material container pair for red surfaces.
- **Lifted Red** (dark `primary`): the dark-mode red, raised for contrast on the near-black ground. It carries **Dark On-Red** text.

### Secondary
- **Ink** (`secondary`, `onSurface`, `inverseSurface`): all primary text, the histogram median line, and the band titles. Secondary is ink, so Material's secondary accents stay neutral.

### Neutral
- **White Ground** (`surface`): every screen background and the overlay panel.
- **Band Gray** (`surfaceContainerHighest`, `secondaryContainer`): module header bands and input fills.
- **Hairline Gray** (`outlineVariant`): every 1px rule, including table rows, column dividers, module top rules, the app-bar bottom rule, and run-row separators.
- **Stroke Gray** (`outline`): input borders, histogram bars, and the overlay panel border.
- **Secondary Gray** (`onSurfaceVariant`): stat labels, slot headers, timestamps, axis labels, and empty-state text. The user pinned #7A7A7A; the build uses #6B6B6B as an approved accessibility adaptation (5.33:1 on white, 4.76:1 on the band gray).
- Dark mode mirrors each role: **Dark Ground**, **Dark Ink**, **Dark Band**, **Dark Hairline**, **Dark Stroke**, **Dark Secondary**.

### Error
- **Alarm Red** (`error`), **Alarm Tint** (`errorContainer`), **Alarm Deep** (`onErrorContainer`): a failed sum check. The stage band turns alarm tint and its status reads bold in alarm deep. Dark mode uses **Dark Alarm Tint** and **Dark Alarm Ink**.

### Named Rules
**The One Red Rule.** Utility red marks only the things the player acts on or must find: tabs, the FAB, the bubble, the mean marker, and the edited tag. It never fills a surface or decorates.

**The Fixed Palette Rule.** Colors come from `colorScheme.*` only. No hard-coded colors, no Dynamic Color, and dark is its own designed scheme.

## Typography

**Body Font:** Roboto 3.016 static Regular and Bold, bundled from `assets/fonts` (OFL)
**Japanese Fallback:** Noto Sans JP, then the system CJK font

**Character:** A compact gothic set tight. Roboto is bundled because the system sans-serif varies by OEM (the test phone's is MiSans), so the system font can't guarantee Roboto or a bold weight. Only two weights exist, 400 and 700.

### Hierarchy
Sizes stay on the Material 3 scale; the theme sets only family, weight, leading, and figures.
- **Mean Numeral** (`titleLarge`, 700, 22sp, 1.2): the mean row in stage modules and series detail. It is the largest number on screen.
- **Title** (`titleSmall`, 700, 14sp, 1.2): band titles ("Stage 1") and run numbers.
- **Title Medium** (`titleMedium`, 700, 16sp, 1.2): session names in the sessions list.
- **Body** (`bodyMedium`, 400, 14sp, 1.3): stat values, run scores, legend text.
- **Body Small** (`bodySmall`, 400, 12sp, 1.3): stat labels and timestamps, in secondary gray.
- **Label** (`labelMedium`, 400, 12sp, 1.2): slot headers and the edited tag. The module tab sets it bold. The mean label uses `labelLarge` (14sp) bold.
- **Axis Label** (`labelSmall`, 400, 11sp, 1.2): histogram axis ticks only.
- Display and headline roles are bold with 1.1 and 1.15 leading but no screen uses them yet.

### Named Rules
**The Tabular Figures Rule.** Every text style carries `tnum`, so score columns line up digit for digit.

**The Price Numeral Rule.** The mean is the only number set at 22sp bold. Every other value stays at body size, so the mean row reads first.

**The 12sp Floor Rule.** Table rows never go below 12sp. Only histogram axis ticks use 11sp.

## Layout

- Single column, full bleed. Modules span the screen width and stack with no gaps between them.
- A 12dp horizontal gutter sits inside every module, row, and band. The sessions list uses 16dp.
- Spacing steps are 2, 4, 8, 12, and 16dp. Stat rows pad 2dp vertically, the mean row 4dp, run rows 8dp.
- Stage modules hold a seven-row table (n, mean, median, min, max, P25, P75) under L / M / R columns. All three fit in about one phone screen.
- Each slot column is one tap target, split from its neighbor by a vertical hairline.
- Runs follow the stats under their own band. Each run row holds the number and time on the left (2 parts) and a 3×3 score block on the right (5 parts).
- Lists end with 88dp of bottom padding so the FAB never covers the last row.
- Values that overflow a column scale down to fit on one line rather than wrap.
- Numbers display through `lib/ui/format.dart`; UI copy lives in `lib/l10n/app_en.arb` and `app_ja.arb`.

## Elevation & Depth

The system is flat. Depth comes from tone and rules: gray bands open modules, hairlines separate rows, and the app bar ends in a hairline instead of a shadow. Cards, the app bar, and dialogs sit at zero elevation with surface tint disabled. The capture FAB is the one lifted element, at Material elevation 2, because it floats over scrolling content.

### Shadow Vocabulary
- **FAB lift** (Material elevation 2): the extended capture FAB only.

### Named Rules
**The Flat Page Rule.** Content never casts a shadow. A new container gets a hairline or a band, not elevation.

## Shapes

- Content is square. Modules, bands, tabs, rows, and the edited tag have no radius.
- Controls get a barely softened corner (4dp): the FAB, filled and text buttons, dialogs, and the overlay panel.
- Input fields use 2dp corners.
- The overlay bubble is the one circle (56dp).
- Borders are 1px. Only focused inputs and the median/mean markers draw 2px.

## Components

### Module Band and Tab (signature)
The world's signature move. A band-gray strip opens each module under a 1px hairline top rule. A red tab hangs flush from that rule, holding a two-digit number ("01") or the runs count, set bold label in white. The band title sits beside the tab on its baseline. The same band opens stage modules, the runs list, and each stage in the run form, where a failed sum turns it alarm tint.

### Stats Table
- **Rows:** seven stats, ruled by hairlines; labels in secondary gray at body small.
- **Mean row:** label bold at 14sp, values in Mean Numeral.
- **Columns:** right-aligned, tabular, one tap target per slot with a vertical hairline between.

### Run Row
- **Structure:** run number (title) and timestamp (body small, gray) on the left; three rows of three scores on the right.
- **Divider:** a hairline bottom rule.
- **Interaction:** tap edits, long-press deletes.

### Edited Tag
A 1px utility-red outline around red label text with 4dp side padding and square corners. It never fills.

### Buttons
- **Shape:** 4dp corners.
- **Filled:** utility red with white text, used for the confirming action (save, delete, create).
- **Text:** utility red text, used for cancel.
- **Capture FAB:** extended, utility red, a camera or stop icon with Start / Stop capturing, elevation 2.

### Inputs / Fields
- **Style:** dense, filled band gray, 1px stroke-gray border, 2dp corners, 10dp padding.
- **Focus:** the border turns utility red at 2px.
- **Error:** alarm red border, 2px when focused.

### Navigation
A flat app bar on the white ground, ink title, and a hairline bottom rule. It stays flat when content scrolls under it. Actions are icon buttons with tooltips.

### Histogram
Stroke-gray bars with 1px gaps, a secondary-gray axis, a solid 2px utility-red mean line, and a dashed 2px ink median line. Each marker has a 4px ground-colored halo so it stays legible over bars. A legend below names both values.

### Overlay
The capture bubble is a 56dp utility-red circle with a white camera icon or spinner, the same in both themes because it sits on the game, not the app's ground. The edit panel (340 × 560dp) is white with a 1px stroke-gray border and 4dp corners, and it reuses the run form.

## Do's and Don'ts

### Do:
- **Do** use `colorScheme.*` and `textTheme.*` for every color and text style.
- **Do** open every new module with a `ModuleBand` and a red `ModuleTab`.
- **Do** separate rows with 1px hairline-gray rules and keep modules flush edge to edge.
- **Do** set the one number a screen is about in Mean Numeral and keep the rest at body size.
- **Do** keep a 12dp gutter and the 2 / 4 / 8 / 12 / 16dp spacing steps.
- **Do** design dark mode values deliberately when adding a role, never by inversion.

### Don't:
- **Don't** use elevated cards, KPI tiles, or shadows on content.
- **Don't** use utility red as a fill for surfaces or decoration.
- **Don't** set table text below 12sp.
- **Don't** round content containers; only controls get the 4dp corner.
- **Don't** hard-code colors or font sizes, or put UI copy in Dart.
- **Don't** add Dynamic Color or a third font weight.
