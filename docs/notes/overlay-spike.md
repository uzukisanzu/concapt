# Overlay spike results

- Date: 2026-10-02
- Phone: POCO F6 (24069PC21G), Android 16, 1220x2712, density 480 (dpr 3.0), wireless adb
- flutter_overlay_window version: 0.5.0

| # | Check | Result | Notes |
|---|---|---|---|
| 1 | Bubble over game, transparent surround | pass | On first show the bubble is clipped, because `showOverlay` width/height are pixels (56 px is about 19 dp) and the 28 dp radius avatar is cropped. |
| 2 | Drag | pass | |
| 3 | Size units | dp (resizeOverlay) | logical size shown: about 340 x 400, dpr: 3.0. `OverlayService.resizeOverlay` applies `dpToPx`; `showOverlay` passes width/height to `WindowManager.LayoutParams` unconverted. After Collapse (`resizeOverlay` 56x56) the bubble is full size. |
| 4 | Plugins + SharedPreferencesAsync in overlay engine | pass | Showed "written by main at ...". |
| 5 | Keyboard in panel | pass | |
| 6 | Collapse + drag | pass | |
| 7 | Survives main app swipe-away | pass | |
| 8 | Close from overlay | pass | |

## Findings for Task 12

- `showOverlay` sizes are pixels; `resizeOverlay` sizes are dp. Pass `showOverlay` a pixel size (dp x devicePixelRatio) or call `resizeOverlay` right after showing.
- The overlay FlutterEngine is cached and survives `closeOverlay`, along with its Dart state. Closing from the expanded panel and showing again drew the panel into the 56 px bubble window (invisible; the window is present per `dumpsys`). The overlay UI must reset to the collapsed bubble state whenever the overlay is shown or closed.
