# Capture strips in the edit panel

## Problem

- The edit panel covers part of the game's result screen.
- With the keyboard open, the bottom ~40% of the screen is gone too.
- No panel position shows every stage, so checking a number means moving the panel or closing it.

## Goal

The panel shows each failing stage's numbers as captured, so the user never needs the game behind it.

## Behavior

### Edit panel (overlay)

| Stage state on open | Shows |
|---|---|
| Doesn't add up | Band, capture strip, five fields |
| Adds up | Band only (folded) |

- **Capture strip:** a crop of the captured frame, from the stage total down through the member scores and the crown bonus. Full panel width, height from the crop's aspect ratio.
- **Hide strip:** tap the strip. It collapses to a one-line row, "Show capture" / 「キャプチャを表示」, with an image icon. Tap the row to bring the strip back.
- **Fold stage:** tap a stage band to fold or unfold it. A chevron at the band's right end shows the state. Folded stages show only the band.
- Folding and the strip are independent. An unfolded passing stage shows a strip too, collapsed by default.
- The quick fix and Save anyway behave as today.

### Run editor (main app)

- Unchanged. No strips, no folding, all stages open.

## Data flow

```
CaptureController.trigger
  → source.capture()            frame path (cacheDir/capture.png)
  → reader.read(path)           pieces
  → ResultParser.parse(pieces)  ParsedRun(draft, stageBounds)
  → CaptureNeedsReview(draft, framePath, stageBounds)
OverlayHome._openPanel
  → decode frame once → ui.Image
  → RunForm(stagePreviews: [CaptureStrip(image, bounds[i]) …], foldPassing: true)
```

- The next capture overwrites `capture.png`, but the panel holds the decoded image, and no capture can start while the panel is open.
- The overlay disposes the image when the panel closes or the overlay restarts.

## Interfaces

| Unit | Change |
|---|---|
| `lib/core/pixel_rect.dart` (new) | `PixelRect(left, top, right, bottom)`, doubles, frame pixels. Pure Dart |
| `ParsedRun` | Adds `List<PixelRect?> stageBounds`, one per stage |
| `CaptureNeedsReview` | Adds `String framePath`, `List<PixelRect?> stageBounds` |
| `lib/overlay/capture_strip.dart` (new) | `CaptureStrip(image, rect)`: paints `rect` of `image` at full width; tap to collapse |
| `RunForm` | Adds optional `List<Widget?>? stagePreviews` and `bool foldPassing = false` |

## Stage bounds

- **Pieces:** the stage total, its member row, and its bonus, if read.
- **Left / right:** min left and max right of those pieces.
- **Top:** the total's top.
- **Bottom:** the lowest bottom among member and bonus pieces, or the total's bottom when neither was read.
- **Margin:** half the median piece height (the parser's existing row tolerance) on every side.
- **Clamp:** the strip painter clamps the rect to the image size.

## Failure handling

| Case | Result |
|---|---|
| Frame fails to decode | No strips; the panel works as today |
| A stage has null bounds | That stage has no strip |

## Strings

| Key | English | Japanese |
|---|---|---|
| `showCapture` | Show capture | キャプチャを表示 |
| `hideCapture` (semantics) | Hide capture | キャプチャを隠す |

## Testing

- **Parser:** on every fixture in `test/fixtures/ocr/` that parses, each stage's bounds contain that stage's total, members, and bonus pieces, and don't reach the next stage's total.
- **Form:** with `foldPassing`, a passing stage shows no fields until its band is tapped; a failing stage shows its preview; tapping the preview collapses it to "Show capture", and tapping that restores it.
- **Form:** without `foldPassing` or previews, the form renders as today (existing tests stay green).
- **Phone:** new checklist rows for the strip, the fold, and the strip toggle, using `concapt-row9.png`; rows 9, 10, 20, and 26 retested.

## Out of scope

- Keeping frames for editing runs later in the main app.
- Zooming or panning the strip.
