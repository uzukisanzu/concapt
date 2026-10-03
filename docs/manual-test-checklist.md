# Manual test checklist

Run on the user's phone (never the emulator) after any change to capture, overlay, or screens.

| # | Area | Steps | Expected |
|---|---|---|---|
| 1 | Session | New session "Test" | Opens the session; stats show "—"; Export is disabled |
| 2 | Permissions | Start capturing on a fresh install, allow notifications | Android's notification prompt, then an explanation dialog and Android's "Display over other apps" settings |
| 3 | Consent | Continue, choose Entire screen, Start | Bubble appears and the app minimizes; reopened, the button reads "Stop capturing" |
| 4 | Declined consent | Stop, Start again, Cancel on Android's dialog | Snackbar "Screen capture was declined."; no bubble |
| 5 | Auto-save | In the game, open a rehearsal result, tap the bubble | Spinner, then toast "Run 1 saved" over the three stage totals, which match the game; the bubble is not in any captured frame |
| 6 | Duplicate | Tap the bubble again on the same result | Toast "Same as run 1, skipped" |
| 7 | Not a result | Tap the bubble on the game's home screen | Toast "No result screen detected" |
| 8 | Double tap | Tap the bubble twice quickly on a new result | One run saved, one toast. Android shows at most about 3 toasts per 20 s from a background app, so pause between rows |
| 9 | Edit panel | Use any capture that opens the panel. If none did in rows 5–8, tap the bubble while the result screen is still appearing | Panel opens; failing stage outlined; keyboard works; Save anyway asks to confirm; toast "Run N saved" |
| 10 | Panel cancel | Open the panel, Cancel | Back to the bubble; nothing saved |
| 11 | Background save | Return to the app | New runs listed; stats updated without restarting |
| 12 | Series | Tap a slot column | Histogram with mean and median lines and seven stats |
| 13 | Edit run | Tap a run, change a number, Save. Then open another run and Save without changes | The changed run gets the "edited" mark and the stats change; the unchanged one stays unmarked |
| 14 | Delete run | Long-press a run, Delete | Run gone; next capture still gets a new number |
| 15 | CSV | Export CSV, share to a file app | Header plus one row per run, oldest first |
| 16 | Screen lock | While capturing, lock and unlock. Separately, end sharing from the status bar with the screen on, if the phone offers it (HyperOS doesn't; check logcat for a toast right after the lock's projection stop instead) | After unlock the bubble is gone. Ending from the status bar closes the bubble with toast "Capture stopped. Start again from the app."; Stop capturing in the app shows no toast |
| 17 | App killed | Start capturing, swipe the app from Recents, capture a result | Toast "Run N saved"; reopening the app shows the run |
| 18 | Delete active session | While capturing into a session, delete it from the sessions list | Bubble closes; session removed |
| 19 | Japanese | Set the phone language to 日本語, then repeat rows 1, 5, 7, and 12 | Every screen, dialog, toast, and the capture notification is in Japanese; no English left over |
| 20 | Dark theme | Turn on system dark mode, then open the session detail, a series, and the edit panel | Both engines switch to dark; pass/fail, "edited", and markers stay readable; score columns line up |
| 21 | Restart capture | While the bubble is showing, Stop capturing then Start capturing straight away | One bubble; the next tap saves into the session once |
| 22 | Switch session | While capturing into session A, open session B and Start capturing | Bubble stays; the next capture saves into B, not A |
| 23 | Permission return | On the overlay permission screen, grant it and press Back | The app continues to the capture consent dialog without a second tap |
| 24 | Bold type | Open a session with runs | Titles and means render bold in Latin and Japanese alike |
| 25 | Notifications denied | Clear app data, start capturing, deny notifications, capture a result | Capture still works; the run saves without a toast |
| 26 | Quick fix | Open the edit panel on a stage that doesn't add up, tap the wrong field | The band offers "#N → value" without changing height; tapping it fills the field and the stage adds up |
| 27 | Capture mark | Start capturing into a session, return to the sessions list | Only that session shows the red "Capturing" tab; it disappears after Stop capturing |
| 28 | Column cue | Open a session with runs | Each slot header shows a chart icon; tapping the column opens its histogram |
| 29 | Capture strip | Open the edit panel from `concapt-row9.png` | Stage 1 opens with a strip of its own numbers from the capture above its fields; stages 2 and 3 are folded to their bands |
| 30 | Strip toggle | Tap stage 1's strip, then "Show capture" | The strip folds to a one-line row and comes back |
| 31 | Stage fold | Tap stage 2's band, then tap it again | Stage 2 unfolds with its fields and a folded "Show capture" row, then folds again |
| 32 | Panel handle | Open the panel, unfold every stage, scroll; then tap the grip at the panel top and drag the panel | The list scrolls; after tapping the grip (it turns red), the next drag moves the panel and lifting the finger returns to scrolling |

## Windows

Run on the developer's PC with `flutter run -d windows`.

| # | Area | Steps | Expected |
|---|---|---|---|
| W0 | Live acceptance (gate) | Capture about 20 real results, from the game window and from scrcpy, including one scrcpy window at full phone resolution (no `-m` limit) enlarged to most of the screen height | Count runs saved without the edit form; report the count before closing the branch |
| W1 | Open | With the game open, open a session and Start capturing | Capture screen; the picker lists the game as "title — process"; the bottom line reads "Press F9 on a result screen to capture." |
| W2 | Auto-save | Pick the game, focus it, open a rehearsal result, press F9 | "Run 1 saved" over three totals that match the game; the game keeps focus |
| W3 | scrcpy | Pick a scrcpy window mirroring the phone on a result, press F9 | Run saved; totals match |
| W4 | Covered target | Move the concapt window so it covers the game's scores, then press F9 | Saved correctly: capture reads the game window itself, so concapt on top isn't in the frame |
| W5 | Failed check | Open a saved result frame with a 7-digit total (Windows OCR can't read one) in Paint or Photos at about 100%, pick that window, press F9 | The run form replaces the controls with capture strips; the taskbar button flashes; the game keeps focus; F9 again shows "Save or cancel the open run first." |
| W6 | Minimized | Minimize the game, press F9 | "The captured window is minimized…"; nothing saved |
| W7 | Closed | Close scrcpy, press F9 | "The captured window is gone…"; picker empty; after reopening scrcpy, Refresh lists it |
| W8 | Hotkey conflict | Bind F9 in another app first, then Start capturing | "F9 is in use by another app…"; Change, press F10, and F10 captures |
| W9 | Remembered | Leave the screen, restart the app, Start capturing | The game window is preselected; the rebound key is kept |
| W10 | Keep on top | Turn it on, click the game; then leave the screen | concapt stays above the game; after leaving, it no longer does |
| W11 | DPI-unaware target | On a monitor scaled above 100%, set scrcpy.exe's Properties › Compatibility › Change high DPI settings › Override › System, restart scrcpy, force a failed check | The capture strips show each stage, not the top-left part of the frame |
| W12 | Japanese | Set the Windows display language to 日本語, repeat W1 and W2 | Every string on the capture screen is Japanese |
| W13 | CSV | Export CSV from a session | Windows' share sheet offers the CSV; note the result if it can't save to a file |
| W14 | Elevated game | If the game runs as administrator, press F9 | Captures; if not, rerun concapt as administrator and note it in the README |
