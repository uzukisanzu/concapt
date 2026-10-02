# concapt Android Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build an Android Flutter app whose floating bubble captures Gakuen Idolmaster rehearsal result screens, reads the 9 member scores with on-device OCR, checks them against each stage total, and shows per-session statistics and histograms.

**Architecture:** Two Flutter engines share one SQLite file. The main engine runs the session screens. The overlay engine (`flutter_overlay_window`) runs the bubble and the whole capture pipeline. A local plugin package (`packages/screen_capture`) holds the Kotlin MediaProjection foreground service, so both engines can reach it. Parsing, sum checks, stats, histogram binning, and CSV are pure Dart with host-side tests.

**Tech Stack:** Flutter 3.41.4 / Dart 3.11.1, Kotlin, `flutter_overlay_window`, `google_mlkit_text_recognition` (Latin), `drift` + `drift_flutter`, `shared_preferences` (`SharedPreferencesAsync`), `path_provider`, `share_plus`, `flutter_localizations` + `intl` (English and Japanese), `integration_test`.

**Product context:** `PRODUCT.md` (users, terminology, brand commitments).

**Spec:** `docs/superpowers/specs/2026-10-02-concapt-design.md`

## Global Constraints

- Shell: Git Bash on Windows. Prefix any `adb` command that has a `/sdcard/...` argument with `MSYS_NO_PATHCONV=1`.
- **Never use the Android emulator.** Steps marked **[device]** start by asking the user to connect their phone (Android 14+), then confirming it with `adb devices`.
- App id, Gradle `namespace`, and `MainActivity` package are all `dev.concapt.app`; Dart package `concapt`; `minSdk = 26`.
- Plugin package `screen_capture`, Kotlin package `dev.concapt.screen_capture`, method channel `concapt/screen_capture`, event channel `concapt/screen_capture/events`.
- Sum check per stage: `left + middle + right + bonus == total`.
- Series: 3 stages × 3 slots, slot order left (0), middle (1), right (2). Stage index 0–2 in Dart, stored as 1–3.
- Stats per series: n, mean, median, min, max, P25, P75. Percentiles use linear interpolation (Excel `PERCENTILE.INC`). Values display rounded with thousands separators; missing values display as `—`.
- Histogram: Freedman–Diaconis width `2 × IQR / n^(1/3)`, rounded up to a 1/2/5 × 10^k step, 8–40 bins, edges aligned to multiples of the step.
- Plain numbers under 100 are ignored by the parser.
- CSV header: `run,captured_at,s1_left,s1_middle,s1_right,s1_bonus,s1_total,s2_left,s2_middle,s2_right,s2_bonus,s2_total,s3_left,s3_middle,s3_right,s3_bonus,s3_total`
- Theme: one `buildTheme(Brightness)` in `lib/ui/theme.dart`, used by both engines.
  - Fixed `Colors.indigo` seed as a placeholder until `DESIGN.md` exists; no Dynamic Color, so pass/fail, "edited", and histogram markers look the same on every phone.
  - Light and dark schemes are both first-class; every `MaterialApp` sets `theme` and `darkTheme`.
  - Tabular figures in every text style, so score columns line up.
- Localization: English and Japanese from Task 11 on. No hard-coded UI strings in Dart; all copy lives in `lib/l10n/app_en.arb` and `lib/l10n/app_ja.arb`. Native strings live in Android `res/values` and `res/values-ja`.
- Gate: Tasks 1–10 run as written. Before Task 11, the user shapes the visual direction with Impeccable in a separate session (see the note above Task 11).
- English copy for capture outcomes (exact):
  - `Run N saved`
  - `Same as run N, skipped`
  - `No result screen detected`
  - `Couldn't read all three stages, try again`
  - `Couldn't read screen, try again`
  - `Capture stopped. Start again from the app.`
- Every commit message ends with the line `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Placement badges and stage labels read as scores.** The 1/2/3 badges sit on their own row below the members. If OCR drops a stage's member row, the parser must leave those slots empty rather than store 1, 2, 3 or the 総合力 number. Pinned in Task 3 (`missing member row leaves slots empty`).
2. **Double tap on the bubble.** A second tap while a capture is still reading must be ignored, not start a second capture or save a duplicate. Pinned in Task 10 (`ignores a tap while a capture is in progress`).
3. **Tap after Android stopped the projection** (screen lock, status-bar chip). The tap must yield the "Capture stopped" outcome and restore the bubble state, not throw. Pinned in Task 10 (`reports stopped capture and still restores the bubble`).
4. **Both engines writing at once.** Concurrent inserts from two connections must neither fail with `SQLITE_BUSY` nor give two runs the same number. Pinned in Task 7 (`two connections insert concurrently with unique seq`).
5. **Empty session.** Stats show `—`, the histogram shows "No runs yet", and CSV is header-only, with no crash on `reduce` or division by zero. Pinned in Tasks 4, 5, 6, and 15 (`empty` tests).

---

## File Structure

```
pubspec.yaml
android/app/build.gradle.kts            minSdk 26
android/app/src/main/AndroidManifest.xml  overlay permissions + OverlayService
l10n.yaml                               gen-l10n config
lib/
  main.dart                             main() and overlayMain() entry points
  l10n/                                 app_en.arb, app_ja.arb, generated AppLocalizations
  core/                                 pure Dart, no Flutter imports
    text_piece.dart                     OCR word + box
    models.dart                         StageScores, RunScores, StageDraft, RunDraft, RunRecord
    result_parser.dart                  TextPiece list → ParseResult
    stats.dart                          Summary, summarize, percentile, seriesValues
    histogram.dart                      Histogram, buildHistogram, nice steps
    csv.dart                            buildCsv
  data/
    database.dart (+ database.g.dart)   drift schema, AppDatabase
    repository.dart                     sessions and runs API
  capture/
    capture_source.dart                 CaptureSource, CaptureStoppedException
    screen_capture_source.dart          CaptureSource backed by the plugin
    text_reader.dart                    TextReader interface
    mlkit_text_reader.dart              ML Kit implementation
    capture_target.dart                 session id shared between engines
    capture_controller.dart             tap → outcome pipeline
  overlay/
    overlay_sizes.dart                  bubble/panel window sizes
    outcome_messages.dart               localized toast text per capture outcome
    overlay_app.dart                    bubble, busy state, edit panel
  ui/
    theme.dart                          buildTheme (shared by both engines)
    format.dart                         formatInt, formatCompact, formatTime
    dialogs.dart                        confirm, promptText
    run_form.dart                       15-field editor with live sum check
    start_capture.dart                  permission → consent → overlay
    stats_card.dart                     per-stage stats table
    histogram_chart.dart                CustomPainter histogram
    sessions_screen.dart
    session_detail_screen.dart
    series_detail_screen.dart
    run_editor_screen.dart
packages/screen_capture/                local Flutter plugin (Android only)
  lib/screen_capture.dart
  android/src/main/AndroidManifest.xml
  android/src/main/kotlin/dev/concapt/screen_capture/
    ScreenCapturePlugin.kt
    CaptureSession.kt
    CaptureService.kt
test/
  helpers/sample.dart                   reference run scores
  helpers/screen.dart                   synthetic OCR layouts
  core/…_test.dart, data/…, capture/…, ui/…
  fixtures/ocr/*.json                   real ML Kit output from the corpus
integration_test/
  capture_test.dart                     plugin round trip [device]
  ocr_accuracy_test.dart                corpus pass rate [device]
docs/notes/overlay-spike.md
docs/manual-test-checklist.md
```

---

### Task 1: Scaffold the app and prove the overlay plugin [device]

The overlay plugin is the riskiest dependency (spec §10). This task proves it before anything is built on it. The spike UI is throwaway; Task 12 replaces `overlayMain` and Task 13 replaces `main`.

**Files:**
- Create: Flutter project in the repo root (`flutter create`)
- Modify: `android/app/build.gradle.kts`, `android/app/src/main/AndroidManifest.xml`
- Move: `android/app/src/main/kotlin/dev/concapt/concapt/MainActivity.kt` → `android/app/src/main/kotlin/dev/concapt/app/MainActivity.kt`
- Replace: `lib/main.dart`
- Delete: `test/widget_test.dart`
- Create: `docs/notes/overlay-spike.md`

**Interfaces:**
- Produces: `overlayMain()` entry point in `lib/main.dart` (annotated `@pragma('vm:entry-point')`); recorded answers in `docs/notes/overlay-spike.md`, especially whether overlay sizes are dp or pixels (used by Task 12).

- [ ] **Step 1: Create the project**

Run from the repo root:

```bash
flutter create --platforms android --org dev.concapt --project-name concapt .
rm test/widget_test.dart
flutter pub add flutter_overlay_window shared_preferences
```

Expected: `All done!` and both packages added to `pubspec.yaml`.

- [ ] **Step 2: Set the app id, namespace, and minSdk**

In `android/app/build.gradle.kts`, replace the generated `namespace = "dev.concapt.concapt"` line with:

```kotlin
    namespace = "dev.concapt.app"
```

Inside `defaultConfig`, replace the generated `applicationId = "dev.concapt.concapt"` and `minSdk = flutter.minSdkVersion` lines with:

```kotlin
        applicationId = "dev.concapt.app"
        minSdk = 26
```

The manifest names the activity `.MainActivity`, which resolves against `namespace`. Move the activity into the matching package, or the app crashes on launch with `ClassNotFoundException`:

```bash
mkdir -p android/app/src/main/kotlin/dev/concapt/app
mv android/app/src/main/kotlin/dev/concapt/concapt/MainActivity.kt android/app/src/main/kotlin/dev/concapt/app/
rmdir android/app/src/main/kotlin/dev/concapt/concapt
sed -i 's/^package dev\.concapt\.concapt\b/package dev.concapt.app/' android/app/src/main/kotlin/dev/concapt/app/MainActivity.kt
head -1 android/app/src/main/kotlin/dev/concapt/app/MainActivity.kt
```

Expected: `package dev.concapt.app`.

- [ ] **Step 3: Declare the overlay permissions and service**

In `android/app/src/main/AndroidManifest.xml`, add these lines directly inside `<manifest …>`, before `<application`:

```xml
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE" />
```

Add this inside `<application …>`, after the closing `</activity>`:

```xml
        <service
            android:name="flutter.overlay.window.flutter_overlay_window.OverlayService"
            android:exported="false"
            android:foregroundServiceType="specialUse">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="Floating capture bubble over the game" />
        </service>
```

- [ ] **Step 4: Write the spike UI**

Replace `lib/main.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const MaterialApp(home: SpikeHome()));

@pragma('vm:entry-point')
void overlayMain() => runApp(
      const MaterialApp(debugShowCheckedModeBanner: false, home: SpikeOverlay()),
    );

class SpikeHome extends StatelessWidget {
  const SpikeHome({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overlay spike')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          FilledButton(
            onPressed: () => FlutterOverlayWindow.requestPermission(),
            child: const Text('1. Grant overlay permission'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              await SharedPreferencesAsync()
                  .setString('spike', 'written by main at ${DateTime.now()}');
              await FlutterOverlayWindow.showOverlay(
                width: 56,
                height: 56,
                enableDrag: true,
                alignment: OverlayAlignment.centerRight,
                overlayTitle: 'concapt spike',
                overlayContent: 'Bubble active',
              );
            },
            child: const Text('2. Show bubble'),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => FlutterOverlayWindow.closeOverlay(),
            child: const Text('3. Close bubble'),
          ),
        ],
      ),
    );
  }
}

class SpikeOverlay extends StatefulWidget {
  const SpikeOverlay({super.key});

  @override
  State<SpikeOverlay> createState() => _SpikeOverlayState();
}

class _SpikeOverlayState extends State<SpikeOverlay> {
  bool _expanded = false;
  String _prefs = '(loading)';

  @override
  void initState() {
    super.initState();
    SharedPreferencesAsync().getString('spike').then((value) {
      if (mounted) setState(() => _prefs = value ?? '(null)');
    });
  }

  Future<void> _expand() async {
    await FlutterOverlayWindow.resizeOverlay(340, 400, true);
    await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
    setState(() => _expanded = true);
  }

  Future<void> _collapse() async {
    await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
    await FlutterOverlayWindow.resizeOverlay(56, 56, true);
    setState(() => _expanded = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return Material(
      type: MaterialType.transparency,
      child: _expanded
          ? Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('prefs: $_prefs'),
                    Text(
                      'logical size: ${size.width.toStringAsFixed(0)} x '
                      '${size.height.toStringAsFixed(0)}, dpr ${dpr.toStringAsFixed(2)}',
                    ),
                    const TextField(
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'Type a number'),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(onPressed: _collapse, child: const Text('Collapse')),
                        TextButton(
                          onPressed: () => FlutterOverlayWindow.closeOverlay(),
                          child: const Text('Close'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            )
          : GestureDetector(
              onTap: _expand,
              child: const CircleAvatar(radius: 28, child: Icon(Icons.camera_alt)),
            ),
    );
  }
}
```

- [ ] **Step 5: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 6: Connect the phone [device]**

Ask the user to connect their Android phone with USB debugging on. Run `adb devices` and confirm exactly one device is listed. Do not start an emulator.

- [ ] **Step 7: Run and walk through the checks with the user [device]**

Run: `flutter run -d <device-id>`

Ask the user to perform each check and report what they see:

| # | Check | Expected |
|---|---|---|
| 1 | Tap 1, grant permission, return, tap 2, then open the game | A round bubble floats over the game with no box around it |
| 2 | Drag the bubble | It follows the finger |
| 3 | Tap the bubble | A panel opens; its "logical size" line reads about `340 x 400` (sizes are dp) or about `340/dpr x 400/dpr` (sizes are pixels) |
| 4 | Read the `prefs:` line | It shows "written by main at …", so plugins and `SharedPreferencesAsync` work in the overlay engine |
| 5 | Tap the text field and type | The keyboard opens and digits appear |
| 6 | Tap Collapse, then drag | Back to a bubble that still drags |
| 7 | Swipe the app away from Recents, then tap the bubble | The bubble still responds |
| 8 | Tap the bubble, then Close | The overlay disappears |

- [ ] **Step 8: Record the results**

Create `docs/notes/overlay-spike.md`:

```markdown
# Overlay spike results

- Date: <today>
- Phone: <model, Android version>
- flutter_overlay_window version: <from pubspec.lock>

| # | Check | Result | Notes |
|---|---|---|---|
| 1 | Bubble over game, transparent surround | pass/fail | |
| 2 | Drag | pass/fail | |
| 3 | Size units | dp/pixels | logical size shown: … dpr: … |
| 4 | Plugins + SharedPreferencesAsync in overlay engine | pass/fail | |
| 5 | Keyboard in panel | pass/fail | |
| 6 | Collapse + drag | pass/fail | |
| 7 | Survives main app swipe-away | pass/fail | |
| 8 | Close from overlay | pass/fail | |
```

Fill in every cell with what the user reported.

**Gate:** if check 1, 2, 4, 5, or 8 fails, stop and report to the user. The spec's fallback (a Kotlin overlay host) needs its own task, and later tasks assume the plugin works. A failure of check 3 or 7 alone is not a blocker. Note it and continue.

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "chore: scaffold Flutter app and overlay spike" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Core models

**Files:**
- Create: `lib/core/text_piece.dart`, `lib/core/models.dart`, `test/helpers/sample.dart`
- Test: `test/core/models_test.dart`

**Interfaces:**
- Produces:
  - `TextPiece(String text, double left, double top, double right, double bottom)` with `centerX`, `centerY`, `height`, `toJson()`, `TextPiece.fromJson(Map<String, dynamic>)`
  - `StageScores({left, middle, right, bonus, total})` with `members`, `sum`, `sumOk`, value equality
  - `RunScores(List<StageScores>)` (exactly 3) with `stageCount = 3`, `allSumsOk`, `member(stage, slot)`, value equality
  - `StageDraft({int? left, middle, right, bonus, total})`, `StageDraft.fromFields(List<int?>)`, `StageDraft.fromScores(StageScores)`, `fields`, `toScores()`, `isValid`
  - `RunDraft(List<StageDraft>)` (exactly 3), `RunDraft.fromScores(RunScores)`, `invalidStages`, `toScores()`
  - `RunRecord({id, seq, capturedAt, edited, scores})`
  - Test helpers `referenceScores()` and `scoresWithLeft(int)`

- [ ] **Step 1: Write the test helper**

Create `test/helpers/sample.dart`:

```dart
import 'package:concapt/core/models.dart';

/// The run in `ref-script/result/Wed Jan 28 08_34_17 2026.png`.
RunScores referenceScores() => RunScores(const [
      StageScores(left: 120918, middle: 39482, right: 30299, bonus: 24183, total: 214882),
      StageScores(left: 107065, middle: 39562, right: 38123, bonus: 21413, total: 206163),
      StageScores(left: 125812, middle: 14862, right: 15385, bonus: 25162, total: 181221),
    ]);

/// A valid run like [referenceScores] whose Stage 1 left score is [left].
RunScores scoresWithLeft(int left) {
  final reference = referenceScores();
  final s1 = reference.stages[0];
  return RunScores([
    StageScores(
      left: left,
      middle: s1.middle,
      right: s1.right,
      bonus: s1.bonus,
      total: left + s1.middle + s1.right + s1.bonus,
    ),
    reference.stages[1],
    reference.stages[2],
  ]);
}
```

- [ ] **Step 2: Write the failing tests**

Create `test/core/models_test.dart`:

```dart
import 'package:concapt/core/models.dart';
import 'package:concapt/core/text_piece.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';

void main() {
  group('StageScores', () {
    test('sum check passes when members plus bonus equal total', () {
      expect(referenceScores().stages.every((s) => s.sumOk), isTrue);
    });

    test('sum check fails when off by one', () {
      const s = StageScores(left: 1, middle: 2, right: 3, bonus: 4, total: 11);
      expect(s.sum, 10);
      expect(s.sumOk, isFalse);
    });
  });

  group('RunScores', () {
    test('requires exactly three stages', () {
      expect(() => RunScores(const []), throwsArgumentError);
    });

    test('has value equality', () {
      expect(referenceScores(), referenceScores());
      expect(referenceScores() == scoresWithLeft(1), isFalse);
    });

    test('member reads stage and slot', () {
      expect(referenceScores().member(2, 1), 14862);
    });
  });

  group('RunDraft', () {
    test('round-trips complete scores', () {
      final draft = RunDraft.fromScores(referenceScores());
      expect(draft.toScores(), referenceScores());
      expect(draft.invalidStages, isEmpty);
    });

    test('a missing field makes the stage invalid and toScores null', () {
      final full = RunDraft.fromScores(referenceScores());
      final draft = RunDraft([
        full.stages[0],
        StageDraft.fromFields([107065, null, 38123, 21413, 206163]),
        full.stages[2],
      ]);
      expect(draft.invalidStages, {1});
      expect(draft.toScores(), isNull);
    });

    test('a wrong sum makes the stage invalid but toScores still returns', () {
      final draft = RunDraft([
        StageDraft.fromFields([1, 2, 3, 4, 11]),
        ...RunDraft.fromScores(referenceScores()).stages.skip(1),
      ]);
      expect(draft.invalidStages, {0});
      expect(draft.toScores(), isNotNull);
    });
  });

  test('TextPiece round-trips through JSON', () {
    const piece = TextPiece('214,882Pt', 10, 20, 110, 44);
    final copy = TextPiece.fromJson(piece.toJson());
    expect(copy.text, piece.text);
    expect([copy.left, copy.top, copy.right, copy.bottom], [10, 20, 110, 44]);
    expect(copy.centerY, 32);
    expect(copy.height, 24);
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/core/models_test.dart`
Expected: FAIL with compile errors (`models.dart` not found).

- [ ] **Step 4: Write `lib/core/text_piece.dart`**

```dart
/// One word recognized by OCR, with its box in image pixels.
class TextPiece {
  const TextPiece(this.text, this.left, this.top, this.right, this.bottom);

  factory TextPiece.fromJson(Map<String, dynamic> json) => TextPiece(
        json['text'] as String,
        (json['l'] as num).toDouble(),
        (json['t'] as num).toDouble(),
        (json['r'] as num).toDouble(),
        (json['b'] as num).toDouble(),
      );

  final String text;
  final double left;
  final double top;
  final double right;
  final double bottom;

  double get centerX => (left + right) / 2;
  double get centerY => (top + bottom) / 2;
  double get height => bottom - top;

  Map<String, Object> toJson() =>
      {'text': text, 'l': left, 't': top, 'r': right, 'b': bottom};

  @override
  String toString() => 'TextPiece("$text" @ $left,$top–$right,$bottom)';
}
```

- [ ] **Step 5: Write `lib/core/models.dart`**

```dart
/// Scores read from one stage of a rehearsal result.
class StageScores {
  const StageScores({
    required this.left,
    required this.middle,
    required this.right,
    required this.bonus,
    required this.total,
  });

  final int left;
  final int middle;
  final int right;
  final int bonus;
  final int total;

  List<int> get members => [left, middle, right];
  int get sum => left + middle + right + bonus;
  bool get sumOk => sum == total;

  @override
  bool operator ==(Object other) =>
      other is StageScores &&
      other.left == left &&
      other.middle == middle &&
      other.right == right &&
      other.bonus == bonus &&
      other.total == total;

  @override
  int get hashCode => Object.hash(left, middle, right, bonus, total);

  @override
  String toString() => 'StageScores($left, $middle, $right, +$bonus = $total)';
}

/// The three stages of one rehearsal run.
class RunScores {
  RunScores(List<StageScores> stages) : stages = List.unmodifiable(stages) {
    if (stages.length != stageCount) {
      throw ArgumentError.value(stages.length, 'stages', 'expected $stageCount');
    }
  }

  static const stageCount = 3;

  final List<StageScores> stages;

  bool get allSumsOk => stages.every((s) => s.sumOk);

  int member(int stage, int slot) => stages[stage].members[slot];

  @override
  bool operator ==(Object other) {
    if (other is! RunScores) return false;
    for (var i = 0; i < stageCount; i++) {
      if (other.stages[i] != stages[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(stages);
}

/// A stage as read or typed; any field may be missing.
class StageDraft {
  const StageDraft({this.left, this.middle, this.right, this.bonus, this.total});

  /// Fields in [fields] order: left, middle, right, bonus, total.
  factory StageDraft.fromFields(List<int?> f) =>
      StageDraft(left: f[0], middle: f[1], right: f[2], bonus: f[3], total: f[4]);

  factory StageDraft.fromScores(StageScores s) => StageDraft(
        left: s.left,
        middle: s.middle,
        right: s.right,
        bonus: s.bonus,
        total: s.total,
      );

  final int? left;
  final int? middle;
  final int? right;
  final int? bonus;
  final int? total;

  List<int?> get fields => [left, middle, right, bonus, total];

  StageScores? toScores() {
    final l = left, m = middle, r = right, b = bonus, t = total;
    if (l == null || m == null || r == null || b == null || t == null) return null;
    return StageScores(left: l, middle: m, right: r, bonus: b, total: t);
  }

  /// Complete and passing the sum check.
  bool get isValid => toScores()?.sumOk ?? false;
}

/// A run as read or typed, before it is saved.
class RunDraft {
  RunDraft(List<StageDraft> stages) : stages = List.unmodifiable(stages) {
    if (stages.length != RunScores.stageCount) {
      throw ArgumentError.value(stages.length, 'stages', 'expected ${RunScores.stageCount}');
    }
  }

  factory RunDraft.fromScores(RunScores scores) =>
      RunDraft([for (final s in scores.stages) StageDraft.fromScores(s)]);

  final List<StageDraft> stages;

  /// Indices of stages that are incomplete or fail the sum check.
  Set<int> get invalidStages =>
      {for (var i = 0; i < stages.length; i++) if (!stages[i].isValid) i};

  /// Null while any field is missing; sums are not checked.
  RunScores? toScores() {
    final scores = [for (final s in stages) s.toScores()];
    if (scores.any((s) => s == null)) return null;
    return RunScores(scores.cast<StageScores>());
  }
}

/// A saved run.
class RunRecord {
  const RunRecord({
    required this.id,
    required this.seq,
    required this.capturedAt,
    required this.edited,
    required this.scores,
  });

  final int id;

  /// Run number within its session, starting at 1.
  final int seq;
  final DateTime capturedAt;

  /// True when the user corrected the numbers by hand.
  final bool edited;
  final RunScores scores;
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `flutter test test/core/models_test.dart`
Expected: all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/core test/core test/helpers
git commit -m "feat: add core score models" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: ResultParser

**Files:**
- Create: `lib/core/result_parser.dart`, `test/helpers/screen.dart`
- Test: `test/core/result_parser_test.dart`

**Interfaces:**
- Consumes: `TextPiece`, `StageDraft`, `RunDraft`, `RunScores` (Task 2)
- Produces:
  - `sealed class ParseResult` with `NoResultScreen()`, `IncompleteScreen(int totalsFound)`, `ParsedRun(RunDraft draft)`
  - `ResultParser.parse(List<TextPiece>) → ParseResult`
  - `ResultParser.number(String) → int?`
  - Test helpers `p(...)`, `stagePieces(...)`, `screenPieces(RunScores)`

- [ ] **Step 1: Write the layout helper**

Create `test/helpers/screen.dart`. Coordinates mimic the 461×764 corpus crops:

```dart
import 'package:concapt/core/models.dart';
import 'package:concapt/core/text_piece.dart';

TextPiece p(String text, double left, double top, {double width = 60, double height = 16}) =>
    TextPiece(text, left, top, left + width, top + height);

String commas(int value) {
  final s = value.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// One stage block as OCR sees it, starting at [y].
List<TextPiece> stagePieces({
  required double y,
  required String total,
  required List<String> members,
  required String bonus,
  String power = '58929',
}) =>
    [
      p('${(y / 240).round() + 1}', 250, y - 30, width: 12), // ステージN label digit
      p(total, 170, y, width: 130, height: 24),
      for (var i = 0; i < members.length; i++) p(members[i], [128.0, 205.0, 268.0][i], y + 32),
      p(bonus, 120, y + 52, width: 70),
      p('1', 135, y + 110, width: 10), // placement badges
      p('2', 207, y + 110, width: 10),
      p('3', 280, y + 110, width: 10),
      p(power, 238, y + 158, width: 70), // 総合力
    ];

const stageTops = [60.0, 300.0, 540.0];

/// A whole result screen for [scores].
List<TextPiece> screenPieces(RunScores scores) => [
      for (var i = 0; i < 3; i++)
        ...stagePieces(
          y: stageTops[i],
          total: '${commas(scores.stages[i].total)}Pt',
          members: [for (final m in scores.stages[i].members) commas(m)],
          bonus: '+${scores.stages[i].bonus}',
        ),
    ];
```

- [ ] **Step 2: Write the failing tests**

Create `test/core/result_parser_test.dart`:

```dart
import 'package:concapt/core/models.dart';
import 'package:concapt/core/result_parser.dart';
import 'package:concapt/core/text_piece.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';
import '../helpers/screen.dart';

RunDraft parsedDraft(List<TextPiece> pieces) {
  final result = ResultParser.parse(pieces);
  expect(result, isA<ParsedRun>());
  return (result as ParsedRun).draft;
}

void main() {
  group('number', () {
    test('strips commas and periods', () {
      expect(ResultParser.number('120,918'), 120918);
      expect(ResultParser.number('39.482'), 39482);
    });

    test('maps lookalike letters inside numeric tokens', () {
      expect(ResultParser.number('12O,918'), 120918);
      expect(ResultParser.number('l5,385'), 15385);
      expect(ResultParser.number('|4,862'), 14862);
    });

    test('rejects words and letter-only tokens', () {
      expect(ResultParser.number('Pt'), isNull);
      expect(ResultParser.number('lOl'), isNull);
      expect(ResultParser.number('58929x'), isNull);
    });
  });

  test('reads the reference screen', () {
    final draft = parsedDraft(screenPieces(referenceScores()));
    expect(draft.toScores(), referenceScores());
    expect(draft.invalidStages, isEmpty);
  });

  test('reads Pt as a separate piece', () {
    final pieces = screenPieces(referenceScores())
        .where((piece) => piece.text != '214,882Pt')
        .toList()
      ..addAll([p('214,882', 170, 60, width: 100, height: 24), p('Pt', 272, 64, width: 20)]);
    expect(parsedDraft(pieces).toScores(), referenceScores());
  });

  test('splits a piece holding several numbers', () {
    final pieces = screenPieces(referenceScores())
        .where((piece) => !['120,918', '39,482', '30,299'].contains(piece.text))
        .toList()
      ..add(p('120,918 39,482 30,299', 128, 92, width: 200));
    expect(parsedDraft(pieces).toScores(), referenceScores());
  });

  test('drops crown junk before the bonus', () {
    final pieces = [
      for (final piece in screenPieces(referenceScores()))
        piece.text == '+24183'
            ? TextPiece('@+24183', piece.left, piece.top, piece.right, piece.bottom)
            : piece,
    ];
    expect(parsedDraft(pieces).stages[0].bonus, 24183);
  });

  test('ignores placement badges, stage labels, and the total power row', () {
    final draft = parsedDraft(screenPieces(referenceScores()));
    for (final stage in draft.stages) {
      expect(stage.fields.where((v) => v != null && v < 100), isEmpty);
      expect(stage.fields, isNot(contains(58929)));
    }
  });

  test('a missing number fills the other slots by position', () {
    final pieces =
        screenPieces(referenceScores()).where((piece) => piece.text != '39,562').toList();
    final stage = parsedDraft(pieces).stages[1];
    expect(stage.left, 107065);
    expect(stage.middle, isNull);
    expect(stage.right, 38123);
    expect(stage.total, 206163);
  });

  test('missing member row leaves slots empty', () {
    final pieces = screenPieces(referenceScores())
        .where((piece) => !['120,918', '39,482', '30,299'].contains(piece.text))
        .toList();
    final draft = parsedDraft(pieces);
    expect(draft.stages[0].left, isNull);
    expect(draft.stages[0].middle, isNull);
    expect(draft.stages[0].right, isNull);
    expect(draft.invalidStages, {0});
  });

  test('a wrong digit fails the sum check for that stage only', () {
    final pieces = [
      for (final piece in screenPieces(referenceScores()))
        piece.text == '14,862'
            ? TextPiece('14,882', piece.left, piece.top, piece.right, piece.bottom)
            : piece,
    ];
    expect(parsedDraft(pieces).invalidStages, {2});
  });

  test('two totals is an incomplete screen', () {
    final pieces =
        screenPieces(referenceScores()).where((piece) => piece.text != '181,221Pt').toList();
    final result = ResultParser.parse(pieces);
    expect(result, isA<IncompleteScreen>());
    expect((result as IncompleteScreen).totalsFound, 2);
  });

  test('no totals is not a result screen', () {
    expect(ResultParser.parse([p('Hello', 10, 10), p('12345', 10, 40)]), isA<NoResultScreen>());
    expect(ResultParser.parse(const []), isA<NoResultScreen>());
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/core/result_parser_test.dart`
Expected: FAIL with compile errors (`result_parser.dart` not found).

- [ ] **Step 4: Write `lib/core/result_parser.dart`**

```dart
import 'dart:math' as math;

import 'models.dart';
import 'text_piece.dart';

sealed class ParseResult {
  const ParseResult();
}

/// No stage totals at all: not a result screen.
class NoResultScreen extends ParseResult {
  const NoResultScreen();
}

/// Some totals found, but not exactly three.
class IncompleteScreen extends ParseResult {
  const IncompleteScreen(this.totalsFound);

  final int totalsFound;
}

class ParsedRun extends ParseResult {
  const ParsedRun(this.draft);

  final RunDraft draft;
}

enum _Kind { total, bonus, number }

class _Token {
  const _Token(this.kind, this.value, this.piece);

  final _Kind kind;
  final int value;
  final TextPiece piece;

  double get centerX => piece.centerX;
  double get centerY => piece.centerY;
}

/// Reads a rehearsal result screen from OCR pieces by their positions.
abstract final class ResultParser {
  static final _ptSuffix = RegExp(r'^(.*?)\s*[Pp][Tt]\.?$');
  static final _ptAlone = RegExp(r'^[Pp][Tt]\.?$');
  static final _bonus = RegExp(r'\+\s*([^+]+)$');
  static final _digitLike = RegExp(r'^[\dOolI|,.]+$');
  static final _anyDigit = RegExp(r'\d');
  static final _separators = RegExp(r'[,.]');
  static const _lookalikes = {'O': '0', 'o': '0', 'l': '1', 'I': '1', '|': '1'};

  /// Smallest plain number kept; below this are badges and stage labels.
  static const _minPlainNumber = 100;

  static const _slots = 3;

  /// Parses [raw] as a number, tolerating separators and lookalike letters.
  static int? number(String raw) {
    final s = raw.trim();
    if (!_digitLike.hasMatch(s) || !_anyDigit.hasMatch(s)) return null;
    final digits =
        s.split('').map((c) => _lookalikes[c] ?? c).join().replaceAll(_separators, '');
    return digits.isEmpty ? null : int.parse(digits);
  }

  static ParseResult parse(List<TextPiece> pieces) {
    final tokens = _classify(pieces);
    final totals = tokens.where((t) => t.kind == _Kind.total).toList()
      ..sort((a, b) => a.centerY.compareTo(b.centerY));
    if (totals.isEmpty) return const NoResultScreen();
    if (totals.length != RunScores.stageCount) return IncompleteScreen(totals.length);

    final tolerance = _median([for (final t in tokens) t.piece.height]) / 2;
    final memberRows = <List<_Token>>[];
    final bonuses = <_Token?>[];
    for (var i = 0; i < totals.length; i++) {
      final top = totals[i].centerY + tolerance;
      final bottom =
          i + 1 < totals.length ? totals[i + 1].centerY - tolerance : double.infinity;
      final band = tokens.where((t) => t.centerY > top && t.centerY < bottom).toList();
      final bonus = _topmost(band.where((t) => t.kind == _Kind.bonus));
      final limit = bonus == null ? bottom : bonus.centerY - tolerance;
      final rows = _groupRows(
        band.where((t) => t.kind == _Kind.number && t.centerY < limit),
        tolerance,
      );
      memberRows.add(rows.isEmpty ? const [] : rows.first);
      bonuses.add(bonus);
    }

    final anchors = _slotAnchors(memberRows);
    return ParsedRun(RunDraft([
      for (var i = 0; i < totals.length; i++)
        _stage(memberRows[i], anchors, bonuses[i]?.value, totals[i].value),
    ]));
  }

  static List<_Token> _classify(List<TextPiece> pieces) {
    final words = pieces.expand(_splitWords).toList();
    final ptMarks = words.where((w) => _ptAlone.hasMatch(w.text.trim())).toList();
    final tokens = <_Token>[];
    for (final word in words) {
      final text = word.text.trim();

      final suffix = _ptSuffix.firstMatch(text);
      if (suffix != null && suffix.group(1)!.isNotEmpty) {
        final value = number(suffix.group(1)!);
        if (value != null) {
          tokens.add(_Token(_Kind.total, value, word));
          continue;
        }
      }

      final bonus = _bonus.firstMatch(text);
      if (bonus != null) {
        final value = number(bonus.group(1)!);
        if (value != null) {
          tokens.add(_Token(_Kind.bonus, value, word));
          continue;
        }
      }

      final value = number(text);
      if (value == null || value < _minPlainNumber) continue;
      final isTotal = ptMarks.any((pt) => _isRightNeighbor(word, pt));
      tokens.add(_Token(isTotal ? _Kind.total : _Kind.number, value, word));
    }
    return tokens;
  }

  /// Splits a piece containing spaces into words, sharing its width by length.
  static Iterable<TextPiece> _splitWords(TextPiece piece) sync* {
    final words = piece.text.trim().split(RegExp(r'\s+'));
    if (words.length <= 1) {
      yield piece;
      return;
    }
    final chars = words.fold<int>(0, (n, w) => n + w.length) + words.length - 1;
    final charWidth = (piece.right - piece.left) / chars;
    var x = piece.left;
    for (final word in words) {
      final width = word.length * charWidth;
      yield TextPiece(word, x, piece.top, x + width, piece.bottom);
      x += width + charWidth;
    }
  }

  static bool _isRightNeighbor(TextPiece number, TextPiece pt) {
    final h = math.max(number.height, pt.height);
    return (pt.centerY - number.centerY).abs() < h / 2 &&
        pt.left >= number.right - h / 2 &&
        pt.left - number.right < h * 1.5;
  }

  static List<List<_Token>> _groupRows(Iterable<_Token> tokens, double tolerance) {
    final sorted = tokens.toList()..sort((a, b) => a.centerY.compareTo(b.centerY));
    final rows = <List<_Token>>[];
    for (final t in sorted) {
      if (rows.isNotEmpty && (t.centerY - rows.last.first.centerY).abs() < tolerance) {
        rows.last.add(t);
      } else {
        rows.add([t]);
      }
    }
    for (final row in rows) {
      row.sort((a, b) => a.centerX.compareTo(b.centerX));
    }
    return rows;
  }

  /// Average x of each slot across stages whose member row read completely.
  static List<double>? _slotAnchors(List<List<_Token>> rows) {
    final complete = rows.where((r) => r.length == _slots).toList();
    if (complete.isEmpty) return null;
    return [
      for (var s = 0; s < _slots; s++)
        complete.map((r) => r[s].centerX).reduce((a, b) => a + b) / complete.length,
    ];
  }

  static StageDraft _stage(List<_Token> row, List<double>? anchors, int? bonus, int total) {
    final slots = List<int?>.filled(_slots, null);
    if (row.length == _slots) {
      for (var s = 0; s < _slots; s++) {
        slots[s] = row[s].value;
      }
    } else if (anchors != null && row.length < _slots) {
      final claimed = <int>{};
      for (final t in row) {
        final slot = _nearest(anchors, t.centerX);
        slots[slot] = claimed.add(slot) ? t.value : null;
      }
    }
    return StageDraft(
      left: slots[0],
      middle: slots[1],
      right: slots[2],
      bonus: bonus,
      total: total,
    );
  }

  static int _nearest(List<double> anchors, double x) {
    var best = 0;
    for (var i = 1; i < anchors.length; i++) {
      if ((anchors[i] - x).abs() < (anchors[best] - x).abs()) best = i;
    }
    return best;
  }

  static _Token? _topmost(Iterable<_Token> tokens) {
    _Token? best;
    for (final t in tokens) {
      if (best == null || t.centerY < best.centerY) best = t;
    }
    return best;
  }

  static double _median(List<double> values) {
    if (values.isEmpty) return 0;
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/core/result_parser_test.dart`
Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/result_parser.dart test/core/result_parser_test.dart test/helpers/screen.dart
git commit -m "feat: parse result screens from OCR pieces" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: Stats and display formatting

**Files:**
- Create: `lib/core/stats.dart`, `lib/ui/format.dart`
- Test: `test/core/stats_test.dart`, `test/ui/format_test.dart`

**Interfaces:**
- Consumes: `RunRecord` (Task 2)
- Produces:
  - `Summary({required int n, double? mean, median, min, max, p25, p75})`
  - `summarize(List<int>) → Summary`
  - `percentile(List<int> sorted, double p) → double`
  - `seriesValues(List<RunRecord>, int stage, int slot) → List<int>`
  - `formatInt(num?) → String`, `formatCompact(int) → String`, `formatTime(DateTime) → String`

- [ ] **Step 1: Write the failing tests**

Create `test/core/stats_test.dart`:

```dart
import 'package:concapt/core/models.dart';
import 'package:concapt/core/stats.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';

void main() {
  test('empty series has n 0 and no values', () {
    final s = summarize(const []);
    expect(s.n, 0);
    expect([s.mean, s.median, s.min, s.max, s.p25, s.p75], everyElement(isNull));
  });

  test('single value fills every stat', () {
    final s = summarize(const [5]);
    expect([s.mean, s.median, s.min, s.max, s.p25, s.p75], everyElement(5));
  });

  test('even count matches PERCENTILE.INC', () {
    final s = summarize(const [4, 1, 3, 2]);
    expect(s.n, 4);
    expect(s.mean, 2.5);
    expect(s.median, 2.5);
    expect(s.min, 1);
    expect(s.max, 4);
    expect(s.p25, 1.75);
    expect(s.p75, 3.25);
  });

  test('odd count', () {
    final s = summarize(const [50, 10, 40, 20, 30]);
    expect(s.median, 30);
    expect(s.p25, 20);
    expect(s.p75, 40);
  });

  test('seriesValues picks one stage and slot from each run', () {
    final runs = [
      for (final (i, scores) in [referenceScores(), scoresWithLeft(100000)].indexed)
        RunRecord(id: i, seq: i + 1, capturedAt: DateTime(2026), edited: false, scores: scores),
    ];
    expect(seriesValues(runs, 0, 0), [120918, 100000]);
    expect(seriesValues(runs, 2, 1), [14862, 14862]);
  });
}
```

Create `test/ui/format_test.dart`:

```dart
import 'package:concapt/ui/format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatInt rounds and groups thousands', () {
    expect(formatInt(null), '—');
    expect(formatInt(0), '0');
    expect(formatInt(999), '999');
    expect(formatInt(1000), '1,000');
    expect(formatInt(120918.4), '120,918');
    expect(formatInt(2.5), '3');
    expect(formatInt(-1234), '-1,234');
  });

  test('formatCompact shortens whole thousands', () {
    expect(formatCompact(115000), '115k');
    expect(formatCompact(2500), '2,500');
    expect(formatCompact(500), '500');
    expect(formatCompact(0), '0');
  });

  test('formatTime shows month, day, and minutes', () {
    expect(formatTime(DateTime(2026, 1, 28, 8, 4, 17)), '01-28 08:04');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/stats_test.dart test/ui/format_test.dart`
Expected: FAIL with compile errors.

- [ ] **Step 3: Write `lib/core/stats.dart`**

```dart
import 'models.dart';

class Summary {
  const Summary({
    required this.n,
    this.mean,
    this.median,
    this.min,
    this.max,
    this.p25,
    this.p75,
  });

  final int n;
  final double? mean;
  final double? median;
  final double? min;
  final double? max;
  final double? p25;
  final double? p75;
}

Summary summarize(List<int> values) {
  if (values.isEmpty) return const Summary(n: 0);
  final sorted = [...values]..sort();
  final total = sorted.fold<int>(0, (a, v) => a + v);
  return Summary(
    n: sorted.length,
    mean: total / sorted.length,
    median: percentile(sorted, 0.5),
    min: sorted.first.toDouble(),
    max: sorted.last.toDouble(),
    p25: percentile(sorted, 0.25),
    p75: percentile(sorted, 0.75),
  );
}

/// Linear interpolation between closest ranks, like Excel's PERCENTILE.INC.
/// [sorted] must be non-empty and ascending.
double percentile(List<int> sorted, double p) {
  final rank = p * (sorted.length - 1);
  final lo = rank.floor();
  final hi = rank.ceil();
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (rank - lo);
}

/// One member's scores across runs: [stage] 0–2, [slot] 0 left, 1 middle, 2 right.
List<int> seriesValues(List<RunRecord> runs, int stage, int slot) =>
    [for (final run in runs) run.scores.member(stage, slot)];
```

- [ ] **Step 4: Write `lib/ui/format.dart`**

```dart
/// Rounds to a whole number with thousands separators; null shows as a dash.
String formatInt(num? value) {
  if (value == null) return '—';
  final n = value.round();
  final digits = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) b.write(',');
    b.write(digits[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// Axis label: whole thousands as `115k`, anything else in full.
String formatCompact(int value) =>
    value != 0 && value % 1000 == 0 ? '${value ~/ 1000}k' : formatInt(value);

String formatTime(DateTime t) =>
    '${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';

String _two(int v) => v.toString().padLeft(2, '0');
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/core/stats_test.dart test/ui/format_test.dart`
Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/core/stats.dart lib/ui/format.dart test/core/stats_test.dart test/ui/format_test.dart
git commit -m "feat: add series statistics and number formatting" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Histogram binning

**Files:**
- Create: `lib/core/histogram.dart`
- Test: `test/core/histogram_test.dart`

**Interfaces:**
- Consumes: `percentile` (Task 4)
- Produces:
  - `Histogram({required int start, required int step, required List<int> counts})` with `Histogram.empty`, `lowerEdge(int bin)`, `end`
  - `buildHistogram(List<int>) → Histogram`
  - `niceStep(double) → int`, `largerNiceStep(int) → int`, `smallerNiceStep(int) → int?`
  - Constants `minBins = 8`, `maxBins = 40`

- [ ] **Step 1: Write the failing tests**

Create `test/core/histogram_test.dart`:

```dart
import 'package:concapt/core/histogram.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nice steps', () {
    test('niceStep rounds up to 1, 2, or 5 times a power of ten', () {
      expect(niceStep(0.3), 1);
      expect(niceStep(1.5), 2);
      expect(niceStep(1000), 1000);
      expect(niceStep(1001), 2000);
      expect(niceStep(2300), 5000);
      expect(niceStep(9500), 10000);
    });

    test('larger and smaller steps walk the sequence', () {
      expect(largerNiceStep(1), 2);
      expect(largerNiceStep(2), 5);
      expect(largerNiceStep(5), 10);
      expect(largerNiceStep(50000), 100000);
      expect(smallerNiceStep(1), isNull);
      expect(smallerNiceStep(2), 1);
      expect(smallerNiceStep(10), 5);
      expect(smallerNiceStep(1000), 500);
    });
  });

  test('empty input gives no bins', () {
    expect(buildHistogram(const []).counts, isEmpty);
  });

  test('all values equal gives a single bar', () {
    final h = buildHistogram(const [5, 5, 5]);
    expect(h.start, 5);
    expect(h.counts, [3]);
  });

  test('zero IQR with spread still bins', () {
    final h = buildHistogram(const [100, 100, 100, 100, 200]);
    expect(h.step, 10);
    expect(h.counts.length, 11);
    expect(h.counts.first, 4);
    expect(h.counts.last, 1);
  });

  test('too few bins shrinks the step to reach the minimum', () {
    final h = buildHistogram(const [0, 1000]);
    expect(h.step, 100);
    expect(h.counts.length, 11);
    expect(h.counts.first, 1);
    expect(h.counts.last, 1);
  });

  test('an outlier widens the step to stay under the maximum', () {
    final values = [for (var i = 0; i < 500; i++) 100000 + i * 2, 1000000];
    final h = buildHistogram(values);
    expect(h.step, 50000);
    expect(h.counts.length, 19);
    expect(h.counts.length, lessThanOrEqualTo(maxBins));
  });

  test('edges align to the step and cover every value', () {
    final values = [for (var i = 0; i < 300; i++) 113000 + (i * 7919) % 15000];
    final h = buildHistogram(values);
    expect(h.start % h.step, 0);
    expect(h.start, lessThanOrEqualTo(values.reduce((a, b) => a < b ? a : b)));
    expect(h.end, greaterThan(values.reduce((a, b) => a > b ? a : b)));
    expect(h.counts.reduce((a, b) => a + b), values.length);
    expect(h.counts.length, inInclusiveRange(minBins, maxBins));
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `flutter test test/core/histogram_test.dart`
Expected: FAIL with compile errors.

- [ ] **Step 3: Write `lib/core/histogram.dart`**

```dart
import 'dart:math' as math;

import 'stats.dart';

const minBins = 8;
const maxBins = 40;

/// Equal-width bins: bin `i` covers `[start + i*step, start + (i+1)*step)`.
class Histogram {
  const Histogram({required this.start, required this.step, required this.counts});

  static const empty = Histogram(start: 0, step: 1, counts: []);

  final int start;
  final int step;
  final List<int> counts;

  int lowerEdge(int bin) => start + bin * step;
  int get end => lowerEdge(counts.length);
}

/// Freedman–Diaconis width, rounded up to a nice step, clamped to 8–40 bins.
Histogram buildHistogram(List<int> values) {
  if (values.isEmpty) return Histogram.empty;
  final sorted = [...values]..sort();
  final lo = sorted.first;
  final hi = sorted.last;
  if (lo == hi) return Histogram(start: lo, step: 1, counts: [sorted.length]);

  final iqr = percentile(sorted, 0.75) - percentile(sorted, 0.25);
  final raw = iqr > 0 ? 2 * iqr / math.pow(sorted.length, 1 / 3) : (hi - lo) / minBins;
  var step = niceStep(raw);
  while (_binCount(lo, hi, step) > maxBins) {
    step = largerNiceStep(step);
  }
  while (_binCount(lo, hi, step) < minBins) {
    final smaller = smallerNiceStep(step);
    if (smaller == null || _binCount(lo, hi, smaller) > maxBins) break;
    step = smaller;
  }

  final start = lo ~/ step * step;
  final counts = List<int>.filled(_binCount(lo, hi, step), 0);
  for (final v in sorted) {
    counts[(v - start) ~/ step]++;
  }
  return Histogram(start: start, step: step, counts: counts);
}

int _binCount(int lo, int hi, int step) => hi ~/ step - lo ~/ step + 1;

/// Smallest 1, 2, or 5 × 10^k that is at least [raw], and at least 1.
int niceStep(double raw) {
  if (raw <= 1) return 1;
  var magnitude = 1;
  while (magnitude * 10 <= raw) {
    magnitude *= 10;
  }
  for (final m in const [1, 2, 5]) {
    if (m * magnitude >= raw) return m * magnitude;
  }
  return 10 * magnitude;
}

int largerNiceStep(int step) {
  final magnitude = _magnitude(step);
  return switch (step ~/ magnitude) {
    1 => 2 * magnitude,
    2 => 5 * magnitude,
    _ => 10 * magnitude,
  };
}

int? smallerNiceStep(int step) {
  if (step <= 1) return null;
  final magnitude = _magnitude(step);
  return switch (step ~/ magnitude) {
    1 => magnitude ~/ 10 * 5,
    2 => magnitude,
    _ => 2 * magnitude,
  };
}

int _magnitude(int step) {
  var magnitude = 1;
  while (magnitude * 10 <= step) {
    magnitude *= 10;
  }
  return magnitude;
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `flutter test test/core/histogram_test.dart`
Expected: all tests PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/histogram.dart test/core/histogram_test.dart
git commit -m "feat: add histogram binning" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: CSV export builder

**Files:**
- Create: `lib/core/csv.dart`
- Test: `test/core/csv_test.dart`

**Interfaces:**
- Consumes: `RunRecord` (Task 2)
- Produces: `buildCsv(List<RunRecord>) → String`, rows ordered by `seq` ascending, `\n` line endings, trailing newline

- [ ] **Step 1: Write the failing test**

Create `test/core/csv_test.dart`:

```dart
import 'package:concapt/core/csv.dart';
import 'package:concapt/core/models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';

const header = 'run,captured_at,'
    's1_left,s1_middle,s1_right,s1_bonus,s1_total,'
    's2_left,s2_middle,s2_right,s2_bonus,s2_total,'
    's3_left,s3_middle,s3_right,s3_bonus,s3_total';

void main() {
  test('empty session exports the header only', () {
    expect(buildCsv(const []), '$header\n');
  });

  test('rows are raw values ordered by run number', () {
    final runs = [
      RunRecord(
        id: 9,
        seq: 2,
        capturedAt: DateTime(2026, 10, 2, 9, 0, 5),
        edited: true,
        scores: scoresWithLeft(100000),
      ),
      RunRecord(
        id: 4,
        seq: 1,
        capturedAt: DateTime(2026, 1, 28, 8, 34, 17),
        edited: false,
        scores: referenceScores(),
      ),
    ];
    final lines = buildCsv(runs).split('\n');
    expect(lines[0], header);
    expect(
      lines[1],
      '1,2026-01-28T08:34:17,'
      '120918,39482,30299,24183,214882,'
      '107065,39562,38123,21413,206163,'
      '125812,14862,15385,25162,181221',
    );
    expect(lines[2], startsWith('2,2026-10-02T09:00:05,100000,'));
    expect(lines[3], '');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/core/csv_test.dart`
Expected: FAIL with compile errors.

- [ ] **Step 3: Write `lib/core/csv.dart`**

```dart
import 'models.dart';

const _fields = ['left', 'middle', 'right', 'bonus', 'total'];

/// One row per run, raw values only, ordered by run number.
String buildCsv(List<RunRecord> runs) {
  final header = [
    'run',
    'captured_at',
    for (var s = 1; s <= RunScores.stageCount; s++)
      for (final f in _fields) 's${s}_$f',
  ];
  final ordered = [...runs]..sort((a, b) => a.seq.compareTo(b.seq));
  final b = StringBuffer()..writeln(header.join(','));
  for (final run in ordered) {
    b.writeln([
      run.seq,
      _timestamp(run.capturedAt),
      for (final s in run.scores.stages) ...[s.left, s.middle, s.right, s.bonus, s.total],
    ].join(','));
  }
  return b.toString();
}

String _timestamp(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-${_two(t.month)}-${_two(t.day)}'
    'T${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

String _two(int v) => v.toString().padLeft(2, '0');
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/core/csv_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/core/csv.dart test/core/csv_test.dart
git commit -m "feat: build session CSV export" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: Database and repository

**Files:**
- Create: `lib/data/database.dart`, `lib/data/database.g.dart` (generated), `lib/data/repository.dart`
- Test: `test/data/repository_test.dart`

**Interfaces:**
- Consumes: `RunScores`, `StageScores`, `RunRecord` (Task 2)
- Produces:
  - `AppDatabase(QueryExecutor)`, `AppDatabase.open()`; generated data class `Session` (`id`, `name`, `createdAt`)
  - `SessionSummary({id, name, createdAt, runCount, lastCapturedAt})`
  - `Repository(AppDatabase)` with:
    - `createSession(String name, {DateTime? createdAt}) → Future<int>`
    - `session(int id) → Future<Session>`
    - `renameSession(int id, String name) → Future<void>`
    - `deleteSession(int id) → Future<void>`
    - `listSessions() → Future<List<SessionSummary>>` (newest first)
    - `addRun(int sessionId, RunScores scores, {required bool edited, DateTime? capturedAt}) → Future<int>` (returns seq)
    - `runs(int sessionId) → Future<List<RunRecord>>` (newest first)
    - `lastRun(int sessionId) → Future<RunRecord?>`
    - `updateRun(int runId, RunScores scores) → Future<void>` (marks edited)
    - `deleteRun(int runId) → Future<void>`

- [ ] **Step 1: Add dependencies**

```bash
flutter pub add drift drift_flutter path_provider dev:drift_dev dev:build_runner
```

Expected: packages added; `flutter pub get` succeeds.

- [ ] **Step 2: Write the failing tests**

Create `test/data/repository_test.dart`:

```dart
import 'dart:io';

import 'package:concapt/data/database.dart';
import 'package:concapt/data/repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';

void main() {
  late AppDatabase db;
  late Repository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = Repository(db);
  });

  tearDown(() => db.close());

  test('a new session lists with no runs', () async {
    await repo.createSession('Week 3 · A', createdAt: DateTime(2026, 10, 1));
    final sessions = await repo.listSessions();
    expect(sessions.single.name, 'Week 3 · A');
    expect(sessions.single.runCount, 0);
    expect(sessions.single.lastCapturedAt, isNull);
  });

  test('sessions list newest first with counts', () async {
    final older = await repo.createSession('older', createdAt: DateTime(2026, 9, 1));
    await repo.createSession('newer', createdAt: DateTime(2026, 10, 1));
    await repo.addRun(older, referenceScores(), edited: false, capturedAt: DateTime(2026, 9, 2, 10));
    final sessions = await repo.listSessions();
    expect(sessions.map((s) => s.name), ['newer', 'older']);
    expect(sessions[1].runCount, 1);
    expect(sessions[1].lastCapturedAt, DateTime(2026, 9, 2, 10));
  });

  test('runs number from 1 and round-trip their scores', () async {
    final sid = await repo.createSession('s');
    expect(await repo.addRun(sid, referenceScores(), edited: false), 1);
    expect(await repo.addRun(sid, scoresWithLeft(1), edited: true), 2);
    final runs = await repo.runs(sid);
    expect(runs.map((r) => r.seq), [2, 1]);
    expect(runs[1].scores, referenceScores());
    expect(runs[0].edited, isTrue);
    expect((await repo.lastRun(sid))!.seq, 2);
  });

  test('numbering is per session', () async {
    final a = await repo.createSession('a');
    final b = await repo.createSession('b');
    await repo.addRun(a, referenceScores(), edited: false);
    expect(await repo.addRun(b, referenceScores(), edited: false), 1);
  });

  test('deleting a run never reuses a higher number', () async {
    final sid = await repo.createSession('s');
    for (var i = 0; i < 3; i++) {
      await repo.addRun(sid, referenceScores(), edited: false);
    }
    final second = (await repo.runs(sid)).firstWhere((r) => r.seq == 2);
    await repo.deleteRun(second.id);
    expect(await repo.addRun(sid, referenceScores(), edited: false), 4);
  });

  test('updating a run replaces scores and marks it edited', () async {
    final sid = await repo.createSession('s');
    await repo.addRun(sid, referenceScores(), edited: false);
    final run = (await repo.lastRun(sid))!;
    await repo.updateRun(run.id, scoresWithLeft(5));
    final updated = (await repo.lastRun(sid))!;
    expect(updated.scores, scoresWithLeft(5));
    expect(updated.edited, isTrue);
    expect(updated.seq, run.seq);
  });

  test('deleting a session cascades to runs and stages', () async {
    final sid = await repo.createSession('s');
    await repo.addRun(sid, referenceScores(), edited: false);
    await repo.deleteSession(sid);
    expect(await db.select(db.runs).get(), isEmpty);
    expect(await db.select(db.stageResults).get(), isEmpty);
  });

  test('rename', () async {
    final sid = await repo.createSession('old');
    await repo.renameSession(sid, 'new');
    expect((await repo.session(sid)).name, 'new');
  });

  test('two connections insert concurrently with unique seq', () async {
    final dir = await Directory.systemTemp.createTemp('concapt_db');
    final file = File('${dir.path}/shared.sqlite');
    final a = AppDatabase(NativeDatabase.createInBackground(file));
    final b = AppDatabase(NativeDatabase.createInBackground(file));
    try {
      final repoA = Repository(a);
      final repoB = Repository(b);
      final sid = await repoA.createSession('shared');
      await repoB.listSessions(); // opens b after the schema exists
      final seqs = await Future.wait([
        for (var i = 0; i < 20; i++)
          (i.isEven ? repoA : repoB).addRun(sid, referenceScores(), edited: false),
      ]);
      expect(seqs.toSet().length, 20);
      expect((await repoA.runs(sid)).length, 20);
    } finally {
      await a.close();
      await b.close();
      await dir.delete(recursive: true);
    }
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/data/repository_test.dart`
Expected: FAIL with compile errors.

- [ ] **Step 4: Write `lib/data/database.dart`**

```dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
}

class Runs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();

  /// Run number within the session, assigned on insert.
  IntColumn get seq => integer()();
  DateTimeColumn get capturedAt => dateTime()();
  BoolColumn get edited => boolean().withDefault(const Constant(false))();
}

/// `_score` suffix because LEFT and RIGHT are SQL keywords.
class StageResults extends Table {
  IntColumn get runId => integer().references(Runs, #id, onDelete: KeyAction.cascade)();

  /// 1–3.
  IntColumn get stage => integer()();
  IntColumn get leftScore => integer()();
  IntColumn get middleScore => integer()();
  IntColumn get rightScore => integer()();
  IntColumn get bonus => integer()();
  IntColumn get total => integer()();

  @override
  Set<Column> get primaryKey => {runId, stage};
}

@DriftDatabase(tables: [Sessions, Runs, StageResults])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The app's database file; both Flutter engines open it.
  factory AppDatabase.open() => AppDatabase(driftDatabase(
        name: 'concapt',
        native: const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory),
      ));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
          await customStatement('PRAGMA busy_timeout = 5000');
          await customStatement('PRAGMA journal_mode = WAL');
        },
      );
}
```

- [ ] **Step 5: Generate the drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/data/database.g.dart` created; output ends with `Succeeded`.

- [ ] **Step 6: Write `lib/data/repository.dart`**

```dart
import 'package:drift/drift.dart';

import '../core/models.dart';
import 'database.dart';

class SessionSummary {
  const SessionSummary({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.runCount,
    this.lastCapturedAt,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final int runCount;
  final DateTime? lastCapturedAt;
}

class Repository {
  Repository(this._db);

  final AppDatabase _db;

  Future<int> createSession(String name, {DateTime? createdAt}) => _db
      .into(_db.sessions)
      .insert(SessionsCompanion.insert(name: name, createdAt: createdAt ?? DateTime.now()));

  Future<Session> session(int id) =>
      (_db.select(_db.sessions)..where((s) => s.id.equals(id))).getSingle();

  Future<void> renameSession(int id, String name) =>
      (_db.update(_db.sessions)..where((s) => s.id.equals(id)))
          .write(SessionsCompanion(name: Value(name)));

  Future<void> deleteSession(int id) =>
      (_db.delete(_db.sessions)..where((s) => s.id.equals(id))).go();

  Future<List<SessionSummary>> listSessions() async {
    final runCount = _db.runs.id.count();
    final lastCaptured = _db.runs.capturedAt.max();
    final query = _db.select(_db.sessions).join([
      leftOuterJoin(_db.runs, _db.runs.sessionId.equalsExp(_db.sessions.id)),
    ])
      ..addColumns([runCount, lastCaptured])
      ..groupBy([_db.sessions.id])
      ..orderBy([
        OrderingTerm.desc(_db.sessions.createdAt),
        OrderingTerm.desc(_db.sessions.id),
      ]);
    final rows = await query.get();
    return [
      for (final row in rows)
        _summary(row.readTable(_db.sessions), row.read(runCount) ?? 0, row.read(lastCaptured)),
    ];
  }

  SessionSummary _summary(Session s, int runCount, DateTime? lastCaptured) => SessionSummary(
        id: s.id,
        name: s.name,
        createdAt: s.createdAt,
        runCount: runCount,
        lastCapturedAt: lastCaptured,
      );

  /// Saves a run and returns its number within the session.
  ///
  /// The number is assigned inside the INSERT, so concurrent writers from
  /// the two engines can't take the same one.
  Future<int> addRun(
    int sessionId,
    RunScores scores, {
    required bool edited,
    DateTime? capturedAt,
  }) {
    return _db.transaction(() async {
      final runId = await _db.customInsert(
        'INSERT INTO runs (session_id, seq, captured_at, edited) '
        'SELECT ?1, COALESCE(MAX(seq), 0) + 1, ?2, ?3 FROM runs WHERE session_id = ?1',
        variables: [
          Variable.withInt(sessionId),
          Variable.withDateTime(capturedAt ?? DateTime.now()),
          Variable.withBool(edited),
        ],
        updates: {_db.runs},
      );
      await _insertStages(runId, scores);
      final run = await (_db.select(_db.runs)..where((r) => r.id.equals(runId))).getSingle();
      return run.seq;
    });
  }

  Future<List<RunRecord>> runs(int sessionId) async {
    final rows = await (_db.select(_db.runs)
          ..where((r) => r.sessionId.equals(sessionId))
          ..orderBy([(r) => OrderingTerm.desc(r.seq)]))
        .get();
    return _withScores(rows);
  }

  Future<RunRecord?> lastRun(int sessionId) async {
    final rows = await (_db.select(_db.runs)
          ..where((r) => r.sessionId.equals(sessionId))
          ..orderBy([(r) => OrderingTerm.desc(r.seq)])
          ..limit(1))
        .get();
    final records = await _withScores(rows);
    return records.isEmpty ? null : records.first;
  }

  Future<void> updateRun(int runId, RunScores scores) => _db.transaction(() async {
        await (_db.delete(_db.stageResults)..where((s) => s.runId.equals(runId))).go();
        await _insertStages(runId, scores);
        await (_db.update(_db.runs)..where((r) => r.id.equals(runId)))
            .write(const RunsCompanion(edited: Value(true)));
      });

  Future<void> deleteRun(int runId) =>
      (_db.delete(_db.runs)..where((r) => r.id.equals(runId))).go();

  Future<void> _insertStages(int runId, RunScores scores) => _db.batch((b) {
        b.insertAll(_db.stageResults, [
          for (var i = 0; i < scores.stages.length; i++)
            StageResultsCompanion.insert(
              runId: runId,
              stage: i + 1,
              leftScore: scores.stages[i].left,
              middleScore: scores.stages[i].middle,
              rightScore: scores.stages[i].right,
              bonus: scores.stages[i].bonus,
              total: scores.stages[i].total,
            ),
        ]);
      });

  Future<List<RunRecord>> _withScores(List<Run> rows) async {
    if (rows.isEmpty) return const [];
    final stageRows = await (_db.select(_db.stageResults)
          ..where((s) => s.runId.isIn(rows.map((r) => r.id))))
        .get();
    final byRun = <int, List<StageResult>>{};
    for (final s in stageRows) {
      (byRun[s.runId] ??= []).add(s);
    }
    return [
      for (final r in rows)
        RunRecord(
          id: r.id,
          seq: r.seq,
          capturedAt: r.capturedAt,
          edited: r.edited,
          scores: _scores(byRun[r.id]!),
        ),
    ];
  }

  RunScores _scores(List<StageResult> rows) {
    rows.sort((a, b) => a.stage.compareTo(b.stage));
    return RunScores([
      for (final s in rows)
        StageScores(
          left: s.leftScore,
          middle: s.middleScore,
          right: s.rightScore,
          bonus: s.bonus,
          total: s.total,
        ),
    ]);
  }
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `flutter test test/data/repository_test.dart`
Expected: all tests PASS. If the concurrent test fails with `database is locked`, confirm `busy_timeout` runs in `beforeOpen` and that both connections use `createInBackground`. Don't lower the run count to make it pass.

- [ ] **Step 8: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/data test/data
git commit -m "feat: add drift database and repository" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: screen_capture plugin [device]

**Files:**
- Create: `packages/screen_capture/` (via `flutter create --template=plugin`), then:
  - Replace: `packages/screen_capture/pubspec.yaml`, `packages/screen_capture/lib/screen_capture.dart`, `packages/screen_capture/android/src/main/AndroidManifest.xml`
  - Replace: `packages/screen_capture/android/src/main/kotlin/dev/concapt/screen_capture/ScreenCapturePlugin.kt`
  - Create: `.../CaptureSession.kt`, `.../CaptureService.kt`
  - Create: `packages/screen_capture/android/src/main/res/values/strings.xml`, `.../res/values-ja/strings.xml`
  - Delete: generated `example/`, `test/`, `android/src/test/`, `lib/screen_capture_platform_interface.dart`, `lib/screen_capture_method_channel.dart`
- Modify: root `pubspec.yaml`
- Test: `integration_test/capture_test.dart`

**Interfaces:**
- Produces (Dart, `package:screen_capture/screen_capture.dart`):
  - `ScreenCapture.requestConsent() → Future<bool>` (main engine only; needs the Activity)
  - `ScreenCapture.isRunning() → Future<bool>`
  - `ScreenCapture.capture() → Future<String>` (PNG file path; throws `PlatformException` code `not_running` when stopped)
  - `ScreenCapture.stop() → Future<void>`
  - `ScreenCapture.toast(String message) → Future<void>`
  - `ScreenCapture.events → Stream<String>` (emits `stopped`)

- [ ] **Step 1: Generate the plugin and remove the parts we don't use**

```bash
flutter create --template=plugin --platforms=android --org dev.concapt --project-name screen_capture packages/screen_capture
rm -rf packages/screen_capture/example packages/screen_capture/test packages/screen_capture/android/src/test
rm packages/screen_capture/lib/screen_capture_platform_interface.dart packages/screen_capture/lib/screen_capture_method_channel.dart
```

- [ ] **Step 2: Replace the plugin pubspec**

`packages/screen_capture/pubspec.yaml`:

```yaml
name: screen_capture
description: MediaProjection screen capture for concapt.
version: 0.0.1
publish_to: none

environment:
  sdk: ^3.11.0
  flutter: ">=3.41.0"

dependencies:
  flutter:
    sdk: flutter

flutter:
  plugin:
    platforms:
      android:
        package: dev.concapt.screen_capture
        pluginClass: ScreenCapturePlugin
```

- [ ] **Step 3: Write the Dart API**

`packages/screen_capture/lib/screen_capture.dart`:

```dart
import 'package:flutter/services.dart';

/// Screen capture through a MediaProjection foreground service.
///
/// Capture state lives in the Android process, so every Flutter engine
/// sees the same session.
abstract final class ScreenCapture {
  static const _methods = MethodChannel('concapt/screen_capture');
  static const _events = EventChannel('concapt/screen_capture/events');

  /// Shows Android's capture prompt and starts the service on approval.
  /// Needs the main app's Activity in the foreground.
  static Future<bool> requestConsent() async =>
      await _methods.invokeMethod<bool>('requestConsent') ?? false;

  static Future<bool> isRunning() async =>
      await _methods.invokeMethod<bool>('isRunning') ?? false;

  /// Writes the newest screen frame to a PNG file and returns its path.
  /// Throws [PlatformException] with code `not_running` when capture stopped.
  static Future<String> capture() async => (await _methods.invokeMethod<String>('capture'))!;

  static Future<void> stop() => _methods.invokeMethod<void>('stop');

  static Future<void> toast(String message) =>
      _methods.invokeMethod<void>('toast', {'message': message});

  /// Emits `stopped` when the projection ends for any reason.
  static Stream<String> get events => _events.receiveBroadcastStream().cast<String>();
}
```

- [ ] **Step 4: Write the plugin manifest**

`packages/screen_capture/android/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_MEDIA_PROJECTION" />

    <application>
        <service
            android:name="dev.concapt.screen_capture.CaptureService"
            android:exported="false"
            android:foregroundServiceType="mediaProjection" />
    </application>
</manifest>
```

- [ ] **Step 5: Write `CaptureSession.kt`**

`packages/screen_capture/android/src/main/kotlin/dev/concapt/screen_capture/CaptureSession.kt`:

```kotlin
package dev.concapt.screen_capture

import android.content.Context
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.Image
import android.media.ImageReader
import android.media.projection.MediaProjection
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import android.os.SystemClock
import android.util.DisplayMetrics
import android.view.Display
import java.io.File
import java.io.FileOutputStream

class NotRunningException : Exception("Screen capture is not running")
class NoFrameException : Exception("No frame arrived from the screen")

/** Process-wide capture state shared by every engine's plugin instance. Main-thread only, except [lock]ed frame access. */
object CaptureSession {
    /** How long a capture waits for a frame newer than the request before using the latest one. */
    private const val FRESH_FRAME_WAIT_MS = 300L
    private const val POLL_MS = 20L

    private val main = Handler(Looper.getMainLooper())
    private val lock = Any()
    private val stopListeners = mutableSetOf<() -> Unit>()

    private var projection: MediaProjection? = null
    private var display: VirtualDisplay? = null
    private var reader: ImageReader? = null
    private var thread: HandlerThread? = null
    private var worker: Handler? = null
    private var latest: Image? = null
    private var latestAt = 0L

    /** Set by the plugin before starting the service; called once with the start result. */
    var onStarted: ((Boolean) -> Unit)? = null

    val isRunning: Boolean get() = projection != null

    fun start(context: Context, mediaProjection: MediaProjection) {
        val metrics = DisplayMetrics()
        val screen = context.getSystemService(DisplayManager::class.java).getDisplay(Display.DEFAULT_DISPLAY)
        @Suppress("DEPRECATION")
        screen.getRealMetrics(metrics)

        val captureThread = HandlerThread("concapt-capture").apply { start() }
        val handler = Handler(captureThread.looper)
        val imageReader = ImageReader.newInstance(metrics.widthPixels, metrics.heightPixels, PixelFormat.RGBA_8888, 3)
        imageReader.setOnImageAvailableListener({ source ->
            val image = source.acquireLatestImage() ?: return@setOnImageAvailableListener
            synchronized(lock) {
                latest?.close()
                latest = image
                latestAt = SystemClock.uptimeMillis()
            }
        }, handler)

        // Android 14 requires the callback before createVirtualDisplay.
        mediaProjection.registerCallback(object : MediaProjection.Callback() {
            override fun onStop() {
                main.post { release() }
            }
        }, main)

        projection = mediaProjection
        reader = imageReader
        thread = captureThread
        worker = handler
        display = mediaProjection.createVirtualDisplay(
            "concapt", metrics.widthPixels, metrics.heightPixels, metrics.densityDpi,
            DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR, imageReader.surface, null, handler,
        )
        reportStarted(true)
    }

    fun reportStarted(ok: Boolean) {
        onStarted?.invoke(ok)
        onStarted = null
    }

    /** Takes the first frame after this call, or the latest frame after [FRESH_FRAME_WAIT_MS]. */
    fun capture(context: Context, callback: (Result<String>) -> Unit) {
        val handler = worker
        if (projection == null || handler == null) {
            callback(Result.failure(NotRunningException()))
            return
        }
        val requestedAt = SystemClock.uptimeMillis()
        val deadline = requestedAt + FRESH_FRAME_WAIT_MS
        handler.post(object : Runnable {
            override fun run() {
                val fresh = synchronized(lock) { latestAt >= requestedAt }
                if (!fresh && SystemClock.uptimeMillis() < deadline) {
                    handler.postDelayed(this, POLL_MS)
                    return
                }
                val result = runCatching { writePng(context) }
                main.post { callback(result) }
            }
        })
    }

    fun stop() {
        val current = projection ?: return
        current.stop() // onStop releases
    }

    fun addStopListener(listener: () -> Unit) {
        stopListeners += listener
    }

    fun removeStopListener(listener: () -> Unit) {
        stopListeners -= listener
    }

    private fun release() {
        if (projection == null) return
        display?.release()
        display = null
        synchronized(lock) {
            latest?.close()
            latest = null
            latestAt = 0L
        }
        reader?.close()
        reader = null
        thread?.quitSafely()
        thread = null
        worker = null
        projection = null
        stopListeners.toList().forEach { it() }
    }

    private fun writePng(context: Context): String {
        val bitmap = synchronized(lock) {
            val image = latest ?: throw NoFrameException()
            toBitmap(image)
        }
        val file = File(context.cacheDir, "capture.png")
        FileOutputStream(file).use { bitmap.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bitmap.recycle()
        return file.absolutePath
    }

    private fun toBitmap(image: Image): Bitmap {
        val plane = image.planes[0]
        val rowPixels = plane.rowStride / plane.pixelStride
        val padded = Bitmap.createBitmap(rowPixels, image.height, Bitmap.Config.ARGB_8888)
        plane.buffer.rewind()
        padded.copyPixelsFromBuffer(plane.buffer)
        if (rowPixels == image.width) return padded
        val cropped = Bitmap.createBitmap(padded, 0, 0, image.width, image.height)
        padded.recycle()
        return cropped
    }
}
```

- [ ] **Step 6: Write `CaptureService.kt`**

`packages/screen_capture/android/src/main/kotlin/dev/concapt/screen_capture/CaptureService.kt`:

```kotlin
package dev.concapt.screen_capture

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.IBinder

/** Foreground service that owns the MediaProjection while capture runs. */
class CaptureService : Service() {
    companion object {
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA = "data"
        private const val CHANNEL_ID = "concapt_capture"
        private const val NOTIFICATION_ID = 41
    }

    private val onSessionStopped: () -> Unit = { stopSelf() }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startInForeground()
        val data = intent?.let { readData(it) }
        val resultCode = intent?.getIntExtra(EXTRA_RESULT_CODE, 0) ?: 0
        if (data == null) {
            CaptureSession.reportStarted(false)
            stopSelf()
            return START_NOT_STICKY
        }
        try {
            val manager = getSystemService(MediaProjectionManager::class.java)
            CaptureSession.start(this, manager.getMediaProjection(resultCode, data))
            CaptureSession.addStopListener(onSessionStopped)
        } catch (e: Exception) {
            CaptureSession.reportStarted(false)
            stopSelf()
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        CaptureSession.removeStopListener(onSessionStopped)
        CaptureSession.stop()
        super.onDestroy()
    }

    private fun readData(intent: Intent): Intent? =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(EXTRA_DATA, Intent::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(EXTRA_DATA)
        }

    private fun startInForeground() {
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(CHANNEL_ID, getString(R.string.capture_channel_name), NotificationManager.IMPORTANCE_LOW),
        )
        val notification = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(getString(R.string.capture_notification_title))
            .setContentText(getString(R.string.capture_notification_text))
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }
}
```

The notification text comes from Android string resources, in English and Japanese like the rest of the UI.

`packages/screen_capture/android/src/main/res/values/strings.xml`:

```xml
<resources>
    <string name="capture_channel_name">Screen capture</string>
    <string name="capture_notification_title">concapt is capturing</string>
    <string name="capture_notification_text">Tap the bubble on a result screen</string>
</resources>
```

`packages/screen_capture/android/src/main/res/values-ja/strings.xml`:

```xml
<resources>
    <string name="capture_channel_name">画面キャプチャ</string>
    <string name="capture_notification_title">concaptでキャプチャ中</string>
    <string name="capture_notification_text">リザルト画面でバブルをタップしてください</string>
</resources>
```

- [ ] **Step 7: Write `ScreenCapturePlugin.kt`**

Replace `packages/screen_capture/android/src/main/kotlin/dev/concapt/screen_capture/ScreenCapturePlugin.kt`:

```kotlin
package dev.concapt.screen_capture

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.media.projection.MediaProjectionManager
import android.widget.Toast
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry

class ScreenCapturePlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    EventChannel.StreamHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    companion object {
        private const val REQUEST_CONSENT = 4107
    }

    private lateinit var context: Context
    private lateinit var methods: MethodChannel
    private lateinit var events: EventChannel
    private var activityBinding: ActivityPluginBinding? = null
    private var pendingConsent: MethodChannel.Result? = null
    private var stopListener: (() -> Unit)? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        methods = MethodChannel(binding.binaryMessenger, "concapt/screen_capture")
        methods.setMethodCallHandler(this)
        events = EventChannel(binding.binaryMessenger, "concapt/screen_capture/events")
        events.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methods.setMethodCallHandler(null)
        events.setStreamHandler(null)
        stopListener?.let { CaptureSession.removeStopListener(it) }
        stopListener = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "requestConsent" -> requestConsent(result)
            "isRunning" -> result.success(CaptureSession.isRunning)
            "capture" -> CaptureSession.capture(context) { outcome ->
                outcome.fold(
                    onSuccess = { result.success(it) },
                    onFailure = { e ->
                        val code = if (e is NotRunningException) "not_running" else "capture_failed"
                        result.error(code, e.message, null)
                    },
                )
            }
            "stop" -> {
                CaptureSession.stop()
                result.success(null)
            }
            "toast" -> {
                Toast.makeText(context, call.argument<String>("message") ?: "", Toast.LENGTH_SHORT).show()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun requestConsent(result: MethodChannel.Result) {
        if (CaptureSession.isRunning) {
            result.success(true)
            return
        }
        val activity = activityBinding?.activity
        if (activity == null) {
            result.error("no_activity", "Capture consent needs the app in the foreground", null)
            return
        }
        pendingConsent = result
        val manager = context.getSystemService(MediaProjectionManager::class.java)
        activity.startActivityForResult(manager.createScreenCaptureIntent(), REQUEST_CONSENT)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CONSENT) return false
        val pending = pendingConsent ?: return true
        pendingConsent = null
        if (resultCode != Activity.RESULT_OK || data == null) {
            pending.success(false)
            return true
        }
        CaptureSession.onStarted = { ok -> pending.success(ok) }
        val intent = Intent(context, CaptureService::class.java)
            .putExtra(CaptureService.EXTRA_RESULT_CODE, resultCode)
            .putExtra(CaptureService.EXTRA_DATA, data)
        context.startForegroundService(intent)
        return true
    }

    override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
        val listener: () -> Unit = { sink.success("stopped") }
        stopListener = listener
        CaptureSession.addStopListener(listener)
    }

    override fun onCancel(arguments: Any?) {
        stopListener?.let { CaptureSession.removeStopListener(it) }
        stopListener = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() {
        activityBinding?.removeActivityResultListener(this)
        activityBinding = null
    }
}
```

- [ ] **Step 8: Depend on the plugin and on integration_test**

In the root `pubspec.yaml`, add under `dependencies:`:

```yaml
  screen_capture:
    path: packages/screen_capture
```

and under `dev_dependencies:`:

```yaml
  integration_test:
    sdk: flutter
```

Run: `flutter pub get`
Expected: succeeds.

- [ ] **Step 9: Write the device test**

Create `integration_test/capture_test.dart`:

```dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:screen_capture/screen_capture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('captures the screen after consent and stops cleanly', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: Center(child: Text('Tap "Start now" on the phone'))),
    ));

    expect(await ScreenCapture.requestConsent(), isTrue,
        reason: 'Choose "Entire screen" and tap Start on the consent dialog');
    expect(await ScreenCapture.isRunning(), isTrue);

    final path = await ScreenCapture.capture();
    final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
    final image = (await codec.getNextFrame()).image;
    final physical = tester.view.physicalSize;
    expect(image.width, physical.width.round());
    expect(image.height, greaterThanOrEqualTo(physical.height.round()));

    final pixels = (await image.toByteData())!.buffer.asUint32List();
    expect(pixels.toSet().length, greaterThan(1), reason: 'Frame is a single color');

    final stopped = ScreenCapture.events.first;
    await ScreenCapture.stop();
    expect(await stopped.timeout(const Duration(seconds: 5)), 'stopped');
    expect(await ScreenCapture.isRunning(), isFalse);
    await expectLater(
      ScreenCapture.capture(),
      throwsA(isA<PlatformException>().having((e) => e.code, 'code', 'not_running')),
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
```

- [ ] **Step 10: Analyze and build**

Run: `flutter analyze && flutter build apk --debug`
Expected: `No issues found!` and `Built build/app/outputs/flutter-apk/app-debug.apk`.

- [ ] **Step 11: Run on the phone [device]**

Ask the user to connect their phone if it isn't already, and confirm with `adb devices`. Tell them a capture consent dialog will appear and they should choose "Entire screen", then Start.

Run: `flutter test integration_test/capture_test.dart -d <device-id>`
Expected: `All tests passed!`

- [ ] **Step 12: Commit**

```bash
git add pubspec.yaml pubspec.lock packages/screen_capture integration_test/capture_test.dart
git commit -m "feat: add MediaProjection screen capture plugin" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 9: ML Kit text reader and corpus accuracy [device]

**Files:**
- Create: `lib/capture/text_reader.dart`, `lib/capture/mlkit_text_reader.dart`
- Test: `integration_test/ocr_accuracy_test.dart`, `test/core/fixture_test.dart`
- Create (pulled from phone): `test/fixtures/ocr/*.json`, `test/fixtures/ocr/report.txt`

**Interfaces:**
- Consumes: `TextPiece` (Task 2), `ResultParser` (Task 3)
- Produces:
  - `abstract interface class TextReader { Future<List<TextPiece>> read(String imagePath); }`
  - `MlKitTextReader implements TextReader` with `close()`
  - Fixture JSON format: `{"passed": bool, "pieces": [TextPiece.toJson(), …]}`

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add google_mlkit_text_recognition`

- [ ] **Step 2: Write the interface and implementation**

`lib/capture/text_reader.dart`:

```dart
import '../core/text_piece.dart';

/// Recognizes words in an image file.
abstract interface class TextReader {
  Future<List<TextPiece>> read(String imagePath);
}
```

`lib/capture/mlkit_text_reader.dart`:

```dart
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../core/text_piece.dart';
import 'text_reader.dart';

/// On-device ML Kit recognizer, Latin script. Returns words, not lines,
/// so ML Kit can't merge the three member scores into one piece.
class MlKitTextReader implements TextReader {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<List<TextPiece>> read(String imagePath) async {
    final result = await _recognizer.processImage(InputImage.fromFilePath(imagePath));
    return [
      for (final block in result.blocks)
        for (final line in block.lines)
          for (final e in line.elements)
            TextPiece(
              e.text,
              e.boundingBox.left,
              e.boundingBox.top,
              e.boundingBox.right,
              e.boundingBox.bottom,
            ),
    ];
  }

  Future<void> close() => _recognizer.close();
}
```

- [ ] **Step 3: Write the accuracy test**

Create `integration_test/ocr_accuracy_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:concapt/capture/mlkit_text_reader.dart';
import 'package:concapt/core/result_parser.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Reads every corpus image, records ML Kit's output as fixtures, and
/// reports how many pass the sum check.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OCR accuracy over the rehearsal corpus', (tester) async {
    final base = (await getExternalStorageDirectory())!;
    final corpus = Directory('${base.path}/corpus');
    final out = Directory('${base.path}/fixtures')..createSync(recursive: true);
    final images = corpus.existsSync()
        ? (corpus.listSync().whereType<File>().where((f) => f.path.endsWith('.png')).toList()
          ..sort((a, b) => a.path.compareTo(b.path)))
        : <File>[];
    expect(images, isNotEmpty, reason: 'Push the corpus to ${corpus.path} first');

    final reader = MlKitTextReader();
    var passed = 0;
    final failures = <String>[];
    for (final image in images) {
      final name = image.uri.pathSegments.last.replaceAll('.png', '');
      final pieces = await reader.read(image.path);
      final result = ResultParser.parse(pieces);
      final ok = result is ParsedRun && (result.draft.toScores()?.allSumsOk ?? false);
      if (ok) {
        passed++;
      } else {
        failures.add('$name: ${_describe(result)}');
      }
      File('${out.path}/$name.json').writeAsStringSync(jsonEncode({
        'passed': ok,
        'pieces': [for (final piece in pieces) piece.toJson()],
      }));
    }
    await reader.close();

    final rate = passed / images.length;
    final report = 'Passed $passed/${images.length} (${(rate * 100).toStringAsFixed(1)}%)\n'
        '${failures.join('\n')}\n';
    File('${out.path}/report.txt').writeAsStringSync(report);
    debugPrint(report);
    expect(rate, greaterThanOrEqualTo(0.9), reason: report);
  }, timeout: const Timeout(Duration(minutes: 10)));
}

String _describe(ParseResult result) => switch (result) {
      NoResultScreen() => 'no totals',
      IncompleteScreen(:final totalsFound) => '$totalsFound totals',
      ParsedRun(:final draft) =>
        'stages ${draft.invalidStages.map((i) => i + 1).join(',')} invalid: '
            '${[for (final s in draft.stages) s.fields].join(' | ')}',
    };
```

- [ ] **Step 4: Install the app and push the corpus [device]**

Ask the user to connect their phone if it isn't already, and confirm with `adb devices`.

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
MSYS_NO_PATHCONV=1 adb shell mkdir -p /sdcard/Android/data/dev.concapt.app/files/corpus
MSYS_NO_PATHCONV=1 adb push ref-script/result/. /sdcard/Android/data/dev.concapt.app/files/corpus/
MSYS_NO_PATHCONV=1 adb shell ls /sdcard/Android/data/dev.concapt.app/files/corpus | wc -l
```

Expected: the last command prints `206`.

- [ ] **Step 5: Run the accuracy test [device]**

Run: `flutter test integration_test/ocr_accuracy_test.dart -d <device-id>`

Note the pass rate printed in the output.

- [ ] **Step 6: If the pass rate is below 90%, diagnose before going further**

Pull the report (Step 7 commands) and read the failure lines.

- **Digits missing or misread across most failures:** the corpus crops are small (461×764). Upscale in the test harness only; real captures are full resolution. Add this to `integration_test/ocr_accuracy_test.dart` and call `final path = await _upscaled(image, out);` before `reader.read(path)`:

  ```dart
  import 'dart:ui' as ui;

  /// The corpus is 461×764 crops; phone captures are several times larger.
  Future<String> _upscaled(File source, Directory tmp) async {
    final bytes = await source.readAsBytes();
    final probe = (await (await ui.instantiateImageCodec(bytes)).getNextFrame()).image;
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: probe.width * 2,
      targetHeight: probe.height * 2,
      allowUpscaling: true,
    );
    final image = (await codec.getNextFrame()).image;
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('${tmp.path}/upscaled.png')..writeAsBytesSync(png!.buffer.asUint8List());
    return file.path;
  }
  ```

- **A pattern the parser doesn't handle** (for example a lookalike character not in `_lookalikes`, or `Pt` read differently): add a failing case to `test/core/result_parser_test.dart` that reproduces the recorded pieces, fix `lib/core/result_parser.dart`, and rerun both test suites.

Rerun Step 5 until the rate is at least 90%. If it stays below after one round of each fix, stop and report the failure breakdown to the user.

- [ ] **Step 7: Pull the fixtures [device]**

```bash
rm -rf test/fixtures/ocr test/fixtures/fixtures
mkdir -p test/fixtures
MSYS_NO_PATHCONV=1 adb pull /sdcard/Android/data/dev.concapt.app/files/fixtures test/fixtures/
mv test/fixtures/fixtures test/fixtures/ocr
ls test/fixtures/ocr | wc -l
```

Expected: `207` (206 JSON files plus `report.txt`).

- [ ] **Step 8: Write the fixture regression test**

Create `test/core/fixture_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:concapt/core/result_parser.dart';
import 'package:concapt/core/text_piece.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';

List<TextPiece> _pieces(Map<String, dynamic> json) => [
      for (final p in json['pieces'] as List) TextPiece.fromJson(p as Map<String, dynamic>),
    ];

Map<String, dynamic> _load(File f) => jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;

/// Real ML Kit output recorded from the corpus by integration_test/ocr_accuracy_test.dart.
void main() {
  final files = Directory('test/fixtures/ocr')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'))
      .toList();

  test('fixtures are present', () => expect(files, isNotEmpty));

  test('reference screenshot parses to its known values', () {
    final json = _load(File('test/fixtures/ocr/Wed Jan 28 08_34_17 2026.json'));
    final result = ResultParser.parse(_pieces(json));
    expect((result as ParsedRun).draft.toScores(), referenceScores());
  });

  test('every capture that passed on the phone still passes', () {
    final regressions = <String>[];
    for (final f in files) {
      final json = _load(f);
      if (json['passed'] != true) continue;
      final result = ResultParser.parse(_pieces(json));
      final ok = result is ParsedRun && (result.draft.toScores()?.allSumsOk ?? false);
      if (!ok) regressions.add(f.uri.pathSegments.last);
    }
    expect(regressions, isEmpty);
  });
}
```

- [ ] **Step 9: Run all host tests**

Run: `flutter test`
Expected: all tests PASS. If the reference test fails, the reference capture didn't pass on the phone; open its JSON, find the misread, and fix the parser as in Step 6.

- [ ] **Step 10: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/capture integration_test/ocr_accuracy_test.dart test/core/fixture_test.dart test/fixtures
git commit -m "feat: add ML Kit text reader with corpus accuracy test" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 10: Capture controller

**Files:**
- Create: `lib/capture/capture_source.dart`, `lib/capture/screen_capture_source.dart`, `lib/capture/capture_target.dart`, `lib/capture/capture_controller.dart`
- Test: `test/capture/capture_controller_test.dart`

**Interfaces:**
- Consumes: `TextReader` (Task 9), `ResultParser` (Task 3), `Repository` (Task 7), `ScreenCapture` (Task 8)
- Produces:
  - `abstract interface class CaptureSource { Future<String> capture(); }`, `class CaptureStoppedException implements Exception`
  - `ScreenCaptureSource implements CaptureSource`
  - `CaptureTarget.write(int sessionId)`, `CaptureTarget.read() → Future<int?>`
  - `sealed class CaptureOutcome`: `CaptureSaved(int seq)`, `CaptureDuplicate(int seq)`, `CaptureNoResult()`, `CaptureIncomplete()`, `CaptureReadFailed()`, `CaptureStopped()`, `CaptureNeedsReview(RunDraft draft)`
  - `CaptureController({source, reader, repository, sessionId, hideBubble, showBubble, readTimeout})` with `trigger() → Future<CaptureOutcome?>` (null when ignored) and `saveReviewed(RunScores) → Future<int>`
  - User-facing messages for outcomes live in the overlay (Task 12), where localizations are available

- [ ] **Step 1: Write the source, source implementation, and target**

`lib/capture/capture_source.dart`:

```dart
/// Thrown when the screen projection has ended.
class CaptureStoppedException implements Exception {
  const CaptureStoppedException();
}

/// Captures the screen to an image file and returns its path.
abstract interface class CaptureSource {
  Future<String> capture();
}
```

`lib/capture/screen_capture_source.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:screen_capture/screen_capture.dart';

import 'capture_source.dart';

class ScreenCaptureSource implements CaptureSource {
  @override
  Future<String> capture() async {
    try {
      return await ScreenCapture.capture();
    } on PlatformException catch (e) {
      if (e.code == 'not_running') throw const CaptureStoppedException();
      rethrow;
    }
  }
}
```

`lib/capture/capture_target.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

/// The session the bubble saves into, shared between the two engines.
abstract final class CaptureTarget {
  static const _key = 'captureSessionId';

  static Future<void> write(int sessionId) => SharedPreferencesAsync().setInt(_key, sessionId);

  static Future<int?> read() => SharedPreferencesAsync().getInt(_key);
}
```

- [ ] **Step 2: Write the failing tests**

Create `test/capture/capture_controller_test.dart`:

```dart
import 'dart:async';

import 'package:concapt/capture/capture_controller.dart';
import 'package:concapt/capture/capture_source.dart';
import 'package:concapt/capture/text_reader.dart';
import 'package:concapt/core/models.dart';
import 'package:concapt/core/text_piece.dart';
import 'package:concapt/data/database.dart';
import 'package:concapt/data/repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';
import '../helpers/screen.dart';

class FakeSource implements CaptureSource {
  Object? error;
  Completer<void>? gate;
  int calls = 0;

  @override
  Future<String> capture() async {
    calls++;
    if (gate != null) await gate!.future;
    if (error != null) throw error!;
    return '/tmp/capture.png';
  }
}

class FakeReader implements TextReader {
  FakeReader(this.pieces);

  List<TextPiece> pieces;
  Object? error;
  bool hang = false;

  @override
  Future<List<TextPiece>> read(String imagePath) async {
    if (hang) await Completer<void>().future;
    if (error != null) throw error!;
    return pieces;
  }
}

void main() {
  late AppDatabase db;
  late Repository repo;
  late FakeSource source;
  late FakeReader reader;
  late List<String> events;
  late CaptureController controller;
  late int sessionId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = Repository(db);
    sessionId = await repo.createSession('s');
    source = FakeSource();
    reader = FakeReader(screenPieces(referenceScores()));
    events = [];
    controller = CaptureController(
      source: source,
      reader: reader,
      repository: repo,
      sessionId: sessionId,
      hideBubble: () async => events.add('hide'),
      showBubble: () async => events.add('show'),
      readTimeout: const Duration(milliseconds: 100),
    );
  });

  tearDown(() => db.close());

  test('a valid screen saves and hides the bubble only around the capture', () async {
    final outcome = await controller.trigger();
    expect(outcome, isA<CaptureSaved>());
    expect((outcome as CaptureSaved).seq, 1);
    expect(events, ['hide', 'show']);
    final run = (await repo.lastRun(sessionId))!;
    expect(run.scores, referenceScores());
    expect(run.edited, isFalse);
  });

  test('the same screen twice is skipped as a duplicate', () async {
    await controller.trigger();
    final outcome = await controller.trigger();
    expect(outcome, isA<CaptureDuplicate>());
    expect((outcome as CaptureDuplicate).seq, 1);
    expect(await repo.runs(sessionId), hasLength(1));
  });

  test('a different run after a saved one is not a duplicate', () async {
    await controller.trigger();
    reader.pieces = screenPieces(scoresWithLeft(100000));
    expect(await controller.trigger(), isA<CaptureSaved>());
  });

  test('a failed sum asks for review and saves nothing', () async {
    final reference = referenceScores();
    final s3 = reference.stages[2];
    reader.pieces = screenPieces(RunScores([
      reference.stages[0],
      reference.stages[1],
      StageScores(left: s3.left, middle: s3.middle, right: s3.right, bonus: s3.bonus, total: s3.total + 1),
    ]));
    final outcome = await controller.trigger();
    expect(outcome, isA<CaptureNeedsReview>());
    expect((outcome as CaptureNeedsReview).draft.invalidStages, {2});
    expect(await repo.runs(sessionId), isEmpty);
  });

  test('no totals is no result screen', () async {
    reader.pieces = [p('Home', 10, 10)];
    expect(await controller.trigger(), isA<CaptureNoResult>());
  });

  test('two totals is incomplete', () async {
    reader.pieces = screenPieces(referenceScores()).where((x) => x.text != '181,221Pt').toList();
    expect(await controller.trigger(), isA<CaptureIncomplete>());
  });

  test('a reader error is a read failure', () async {
    reader.error = StateError('ml kit');
    expect(await controller.trigger(), isA<CaptureReadFailed>());
  });

  test('a reader that never answers times out as a read failure', () async {
    reader.hang = true;
    expect(await controller.trigger(), isA<CaptureReadFailed>());
  });

  test('reports stopped capture and still restores the bubble', () async {
    source.error = const CaptureStoppedException();
    expect(await controller.trigger(), isA<CaptureStopped>());
    expect(events, ['hide', 'show']);
  });

  test('ignores a tap while a capture is in progress', () async {
    source.gate = Completer<void>();
    final first = controller.trigger();
    expect(await controller.trigger(), isNull);
    source.gate!.complete();
    expect(await first, isA<CaptureSaved>());
    expect(source.calls, 1);
    expect(await repo.runs(sessionId), hasLength(1));
  });

  test('saveReviewed stores an edited run', () async {
    expect(await controller.saveReviewed(referenceScores()), 1);
    expect((await repo.lastRun(sessionId))!.edited, isTrue);
  });
}
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `flutter test test/capture/capture_controller_test.dart`
Expected: FAIL with compile errors (`capture_controller.dart` not found).

- [ ] **Step 4: Write `lib/capture/capture_controller.dart`**

```dart
import '../core/models.dart';
import '../core/result_parser.dart';
import '../core/text_piece.dart';
import '../data/repository.dart';
import 'capture_source.dart';
import 'text_reader.dart';

sealed class CaptureOutcome {
  const CaptureOutcome();
}

class CaptureSaved extends CaptureOutcome {
  const CaptureSaved(this.seq);

  final int seq;
}

class CaptureDuplicate extends CaptureOutcome {
  const CaptureDuplicate(this.seq);

  final int seq;
}

class CaptureNoResult extends CaptureOutcome {
  const CaptureNoResult();
}

class CaptureIncomplete extends CaptureOutcome {
  const CaptureIncomplete();
}

class CaptureReadFailed extends CaptureOutcome {
  const CaptureReadFailed();
}

class CaptureStopped extends CaptureOutcome {
  const CaptureStopped();
}

class CaptureNeedsReview extends CaptureOutcome {
  const CaptureNeedsReview(this.draft);

  final RunDraft draft;
}

/// Turns one bubble tap into a saved run or a reason it wasn't saved.
class CaptureController {
  CaptureController({
    required this.source,
    required this.reader,
    required this.repository,
    required this.sessionId,
    required this.hideBubble,
    required this.showBubble,
    this.readTimeout = const Duration(seconds: 10),
  });

  final CaptureSource source;
  final TextReader reader;
  final Repository repository;
  final int sessionId;

  /// Completes once the bubble is off screen.
  final Future<void> Function() hideBubble;

  /// Brings the bubble back (in its busy state) after the frame is taken.
  final Future<void> Function() showBubble;
  final Duration readTimeout;

  bool _busy = false;

  /// Returns null when a capture is already in progress.
  Future<CaptureOutcome?> trigger() async {
    if (_busy) return null;
    _busy = true;
    try {
      final String path;
      await hideBubble();
      try {
        path = await source.capture();
      } on CaptureStoppedException {
        return const CaptureStopped();
      } catch (_) {
        return const CaptureReadFailed();
      } finally {
        await showBubble();
      }

      final List<TextPiece> pieces;
      try {
        pieces = await reader.read(path).timeout(readTimeout);
      } catch (_) {
        return const CaptureReadFailed();
      }

      switch (ResultParser.parse(pieces)) {
        case NoResultScreen():
          return const CaptureNoResult();
        case IncompleteScreen():
          return const CaptureIncomplete();
        case ParsedRun(:final draft):
          final scores = draft.toScores();
          if (scores == null || !scores.allSumsOk) return CaptureNeedsReview(draft);
          final last = await repository.lastRun(sessionId);
          if (last != null && last.scores == scores) return CaptureDuplicate(last.seq);
          return CaptureSaved(await repository.addRun(sessionId, scores, edited: false));
      }
    } finally {
      _busy = false;
    }
  }

  /// Saves a run the user corrected in the edit panel.
  Future<int> saveReviewed(RunScores scores) =>
      repository.addRun(sessionId, scores, edited: true);
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/capture/capture_controller_test.dart`
Expected: all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/capture test/capture
git commit -m "feat: add capture controller pipeline" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

> **Gate before Tasks 11–15:** stop after Task 10. The user runs `/impeccable shape session detail` in a separate session to choose the visual direction. Tasks 11–15 then build with Impeccable, and its documenter writes `DESIGN.md`. The code below fixes behavior, strings, widget keys, and tests. Visual styling may change to follow the shaped direction, but the theme rules in Global Constraints still hold.

### Task 11: Theme, localization, dialogs, and the run form

**Files:**
- Modify: `pubspec.yaml`
- Create: `l10n.yaml`, `lib/l10n/app_en.arb`, `lib/l10n/app_ja.arb`, `lib/l10n/app_localizations*.dart` (generated)
- Create: `lib/ui/theme.dart`, `lib/ui/dialogs.dart`, `lib/ui/run_form.dart`
- Create: `test/helpers/app.dart`
- Test: `test/ui/theme_test.dart`, `test/ui/l10n_test.dart`, `test/ui/run_form_test.dart`

**Interfaces:**
- Consumes: `RunDraft`, `StageDraft`, `RunScores` (Task 2), `formatInt` (Task 4)
- Produces:
  - `AppLocalizations` (generated, `package:concapt/l10n/app_localizations.dart`), `AppLocalizations.of(context)` non-null, `lookupAppLocalizations(Locale)`
  - `buildTheme(Brightness) → ThemeData`
  - `confirm(BuildContext, {required String title, required String message, required String action}) → Future<bool>`
  - `promptText(BuildContext, {required String title, String initial = '', String? hint, required String action}) → Future<String?>` (trimmed; null when cancelled or empty)
  - `RunForm({required RunDraft initial, required ValueChanged<RunScores> onSave, required VoidCallback onCancel})`; keys `field-<stage>-<field>`, `status-<stage>`, `stage-<stage>`, `save`
  - `stageStatus(AppLocalizations, StageDraft) → String`, `fieldLabels(AppLocalizations) → List<String>`
  - Test helpers `localizedApp(Widget home, {Locale locale})`, `en()`

- [ ] **Step 1: Add localization dependencies**

```bash
flutter pub add flutter_localizations --sdk=flutter
flutter pub add intl:any
```

In `pubspec.yaml`, under the top-level `flutter:` key, add:

```yaml
  generate: true
```

Create `l10n.yaml` in the repo root:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
nullable-getter: false
```

- [ ] **Step 2: Write the English strings**

Create `lib/l10n/app_en.arb`:

```json
{
  "@@locale": "en",
  "appTitle": "concapt",
  "cancel": "Cancel",
  "save": "Save",
  "delete": "Delete",
  "rename": "Rename",
  "create": "Create",
  "continueAction": "Continue",
  "listSeparator": ", ",
  "stageLabel": "Stage {stage}",
  "@stageLabel": {"placeholders": {"stage": {"type": "int"}}},
  "slotLeft": "Left",
  "slotMiddle": "Middle",
  "slotRight": "Right",
  "fieldBonus": "Bonus",
  "fieldTotal": "Total",
  "statusAddsUp": "Adds up",
  "statusMissing": "Missing values",
  "statusOffBy": "Off by {diff}",
  "@statusOffBy": {"placeholders": {"diff": {"type": "String"}}},
  "saveAnywayTitle": "Save anyway?",
  "saveAnywayMessage": "{stages} doesn't add up.",
  "@saveAnywayMessage": {"placeholders": {"stages": {"type": "String"}}},
  "saveAnywayAction": "Save anyway",
  "runSaved": "Run {seq} saved",
  "@runSaved": {"placeholders": {"seq": {"type": "int"}}},
  "runDuplicate": "Same as run {seq}, skipped",
  "@runDuplicate": {"placeholders": {"seq": {"type": "int"}}},
  "noResultScreen": "No result screen detected",
  "incompleteScreen": "Couldn't read all three stages, try again",
  "readFailed": "Couldn't read screen, try again",
  "captureStopped": "Capture stopped. Start again from the app.",
  "checkHighlightedStage": "Check the highlighted stage",
  "noSessionSelected": "No session selected. Start capturing from the app.",
  "sessionsEmpty": "No sessions yet. Make one for each team you rehearse.",
  "newSession": "New session",
  "newSessionHint": "e.g. Contest week 3 · team A",
  "renameSession": "Rename session",
  "deleteSessionTitle": "Delete \"{name}\"?",
  "@deleteSessionTitle": {"placeholders": {"name": {"type": "String"}}},
  "deleteSessionMessage": "This deletes its {count, plural, =1{1 run} other{{count} runs}}.",
  "@deleteSessionMessage": {"placeholders": {"count": {"type": "int"}}},
  "runCount": "{count, plural, =1{1 run} other{{count} runs}}",
  "@runCount": {"placeholders": {"count": {"type": "int"}}},
  "sessionSubtitle": "{runs} · last {last}",
  "@sessionSubtitle": {"placeholders": {"runs": {"type": "String"}, "last": {"type": "String"}}},
  "allowBubbleTitle": "Allow the bubble",
  "allowBubbleMessage": "concapt needs \"Display over other apps\" to show its capture bubble over the game.",
  "openSettings": "Open settings",
  "shareScreenTitle": "Share your screen",
  "shareScreenMessage": "On the next screen, choose \"Entire screen\", or pick the game if Android asks for a single app.",
  "captureDeclined": "Screen capture was declined.",
  "overlayNotification": "Capture bubble is active",
  "exportCsv": "Export CSV",
  "startCapturing": "Start capturing",
  "stopCapturing": "Stop capturing",
  "runsHeading": "Runs ({count})",
  "@runsHeading": {"placeholders": {"count": {"type": "int"}}},
  "runTitle": "Run {seq}",
  "@runTitle": {"placeholders": {"seq": {"type": "int"}}},
  "edited": "edited",
  "deleteRunTitle": "Delete run {seq}?",
  "@deleteRunTitle": {"placeholders": {"seq": {"type": "int"}}},
  "deleteRunMessage": "Its scores leave the statistics.",
  "statN": "n",
  "statMean": "Mean",
  "statMedian": "Median",
  "statMin": "Min",
  "statMax": "Max",
  "statP25": "P25",
  "statP75": "P75",
  "seriesTitle": "Stage {stage} · {slot}",
  "@seriesTitle": {"placeholders": {"stage": {"type": "int"}, "slot": {"type": "String"}}},
  "noRunsYet": "No runs yet",
  "legendMean": "Mean {value}",
  "@legendMean": {"placeholders": {"value": {"type": "String"}}},
  "legendMedian": "Median {value}",
  "@legendMedian": {"placeholders": {"value": {"type": "String"}}}
}
```

- [ ] **Step 3: Write the Japanese strings**

Create `lib/l10n/app_ja.arb`. These are first-draft translations; ask the user to review them before Task 16.

```json
{
  "@@locale": "ja",
  "appTitle": "concapt",
  "cancel": "キャンセル",
  "save": "保存",
  "delete": "削除",
  "rename": "名前を変更",
  "create": "作成",
  "continueAction": "続ける",
  "listSeparator": "、",
  "stageLabel": "ステージ{stage}",
  "slotLeft": "左",
  "slotMiddle": "中央",
  "slotRight": "右",
  "fieldBonus": "ボーナス",
  "fieldTotal": "合計",
  "statusAddsUp": "一致",
  "statusMissing": "未入力あり",
  "statusOffBy": "{diff} ずれ",
  "saveAnywayTitle": "このまま保存しますか？",
  "saveAnywayMessage": "{stages}の合計が一致しません。",
  "saveAnywayAction": "保存する",
  "runSaved": "{seq}回目を保存しました",
  "runDuplicate": "{seq}回目と同じため、スキップしました",
  "noResultScreen": "リザルト画面が見つかりません",
  "incompleteScreen": "3ステージ分を読み取れませんでした。もう一度お試しください",
  "readFailed": "画面を読み取れませんでした。もう一度お試しください",
  "captureStopped": "キャプチャが停止しました。アプリから再開してください。",
  "checkHighlightedStage": "ハイライトされたステージを確認してください",
  "noSessionSelected": "セッションが選択されていません。アプリからキャプチャを開始してください。",
  "sessionsEmpty": "まだセッションがありません。リハーサルするチームごとに作成してください。",
  "newSession": "新規セッション",
  "newSessionHint": "例: コンテスト第3週・チームA",
  "renameSession": "セッション名を変更",
  "deleteSessionTitle": "「{name}」を削除しますか？",
  "deleteSessionMessage": "{count, plural, other{{count}回分の記録も削除されます。}}",
  "runCount": "{count, plural, other{{count}回}}",
  "sessionSubtitle": "{runs} · 最終 {last}",
  "allowBubbleTitle": "バブルの表示を許可",
  "allowBubbleMessage": "ゲームの上にキャプチャ用のバブルを表示するため、「他のアプリの上に重ねて表示」の許可が必要です。",
  "openSettings": "設定を開く",
  "shareScreenTitle": "画面の共有",
  "shareScreenMessage": "次の画面で「画面全体」を選んでください。アプリ単位の共有を求められた場合は、ゲームを選んでください。",
  "captureDeclined": "画面キャプチャが許可されませんでした。",
  "overlayNotification": "キャプチャ用バブルを表示中",
  "exportCsv": "CSVを書き出す",
  "startCapturing": "キャプチャ開始",
  "stopCapturing": "キャプチャ停止",
  "runsHeading": "記録（{count}回）",
  "runTitle": "{seq}回目",
  "edited": "修正済み",
  "deleteRunTitle": "{seq}回目を削除しますか？",
  "deleteRunMessage": "この回のスコアは統計から外れます。",
  "statN": "n",
  "statMean": "平均",
  "statMedian": "中央値",
  "statMin": "最小",
  "statMax": "最大",
  "statP25": "P25",
  "statP75": "P75",
  "seriesTitle": "ステージ{stage}・{slot}",
  "noRunsYet": "まだ記録がありません",
  "legendMean": "平均 {value}",
  "legendMedian": "中央値 {value}"
}
```

- [ ] **Step 4: Generate the localizations**

Run: `flutter gen-l10n`
Expected: `lib/l10n/app_localizations.dart`, `app_localizations_en.dart`, and `app_localizations_ja.dart` created, with no untranslated-message warnings.

- [ ] **Step 5: Write the failing theme and localization tests**

Create `test/helpers/app.dart`:

```dart
import 'package:concapt/l10n/app_localizations.dart';
import 'package:concapt/ui/theme.dart';
import 'package:flutter/material.dart';

/// A MaterialApp with the app's theme and localizations around [home].
Widget localizedApp(Widget home, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    );

AppLocalizations en() => lookupAppLocalizations(const Locale('en'));
```

Create `test/ui/theme_test.dart`:

```dart
import 'package:concapt/ui/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light and dark schemes come from the same fixed seed', () {
    final light = buildTheme(Brightness.light).colorScheme;
    final dark = buildTheme(Brightness.dark).colorScheme;
    expect(light.brightness, Brightness.light);
    expect(dark.brightness, Brightness.dark);
    expect(light.primary, ColorScheme.fromSeed(seedColor: Colors.indigo).primary);
    expect(
      dark.primary,
      ColorScheme.fromSeed(seedColor: Colors.indigo, brightness: Brightness.dark).primary,
    );
  });

  test('every text style uses tabular figures', () {
    for (final brightness in Brightness.values) {
      final t = buildTheme(brightness).textTheme;
      final styles = [
        t.displayLarge, t.displayMedium, t.displaySmall,
        t.headlineLarge, t.headlineMedium, t.headlineSmall,
        t.titleLarge, t.titleMedium, t.titleSmall,
        t.bodyLarge, t.bodyMedium, t.bodySmall,
        t.labelLarge, t.labelMedium, t.labelSmall,
      ];
      for (final style in styles) {
        expect(style!.fontFeatures, contains(const FontFeature.tabularFigures()));
      }
    }
  });
}
```

Create `test/ui/l10n_test.dart`:

```dart
import 'dart:convert';
import 'dart:io';

import 'package:concapt/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Set<String> _messageKeys(String locale) {
  final arb = jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map<String, dynamic>;
  return arb.keys.where((k) => !k.startsWith('@')).toSet();
}

void main() {
  test('Japanese has exactly the English messages', () {
    expect(_messageKeys('ja'), _messageKeys('en'));
  });

  test('both locales load and differ', () {
    final en = lookupAppLocalizations(const Locale('en'));
    final ja = lookupAppLocalizations(const Locale('ja'));
    expect(en.runSaved(7), 'Run 7 saved');
    expect(ja.runSaved(7), isNot(en.runSaved(7)));
    expect(en.runCount(1), '1 run');
    expect(en.runCount(3), '3 runs');
  });
}
```

- [ ] **Step 6: Run the tests to verify they fail**

Run: `flutter test test/ui/theme_test.dart test/ui/l10n_test.dart`
Expected: `theme_test.dart` fails to compile (`theme.dart` not found); `l10n_test.dart` passes.

- [ ] **Step 7: Write `lib/ui/theme.dart`**

```dart
import 'package:flutter/material.dart';

/// Placeholder seed until DESIGN.md sets the visual identity.
///
/// Fixed on purpose, with no Dynamic Color, so pass/fail colors, the
/// edited mark, and histogram markers look the same on every phone.
const _seed = Colors.indigo;

const _tabular = [FontFeature.tabularFigures()];

/// Tabular figures in every style, so score columns line up.
const _textTheme = TextTheme(
  displayLarge: TextStyle(fontFeatures: _tabular),
  displayMedium: TextStyle(fontFeatures: _tabular),
  displaySmall: TextStyle(fontFeatures: _tabular),
  headlineLarge: TextStyle(fontFeatures: _tabular),
  headlineMedium: TextStyle(fontFeatures: _tabular),
  headlineSmall: TextStyle(fontFeatures: _tabular),
  titleLarge: TextStyle(fontFeatures: _tabular),
  titleMedium: TextStyle(fontFeatures: _tabular),
  titleSmall: TextStyle(fontFeatures: _tabular),
  bodyLarge: TextStyle(fontFeatures: _tabular),
  bodyMedium: TextStyle(fontFeatures: _tabular),
  bodySmall: TextStyle(fontFeatures: _tabular),
  labelLarge: TextStyle(fontFeatures: _tabular),
  labelMedium: TextStyle(fontFeatures: _tabular),
  labelSmall: TextStyle(fontFeatures: _tabular),
);

/// The one theme both engines use, in light and dark.
ThemeData buildTheme(Brightness brightness) => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed, brightness: brightness),
      textTheme: _textTheme,
    );
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `flutter test test/ui/theme_test.dart test/ui/l10n_test.dart`
Expected: all tests PASS.

- [ ] **Step 9: Write the failing run form tests**

Create `test/ui/run_form_test.dart`:

```dart
import 'package:concapt/core/models.dart';
import 'package:concapt/ui/run_form.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app.dart';
import '../helpers/sample.dart';

Future<List<RunScores>> pumpForm(WidgetTester tester, RunDraft draft) async {
  tester.view.physicalSize = const Size(1200, 2800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final saved = <RunScores>[];
  await tester.pumpWidget(localizedApp(
    Scaffold(body: RunForm(initial: draft, onSave: saved.add, onCancel: () {})),
  ));
  return saved;
}

RunDraft draftWithStage3Total(int total) {
  final full = RunDraft.fromScores(referenceScores());
  final s3 = full.stages[2];
  return RunDraft([
    full.stages[0],
    full.stages[1],
    StageDraft(left: s3.left, middle: s3.middle, right: s3.right, bonus: s3.bonus, total: total),
  ]);
}

void main() {
  test('stageStatus', () {
    final l = en();
    expect(stageStatus(l, const StageDraft(left: 1, middle: 2, right: 3, bonus: 4, total: 10)), 'Adds up');
    expect(stageStatus(l, const StageDraft(left: 1, middle: 2, right: 3, bonus: 4, total: 9)), 'Off by +1');
    expect(stageStatus(l, const StageDraft(left: 1, middle: 2, right: 3, bonus: 4, total: 1010)), 'Off by −1,000');
    expect(stageStatus(l, const StageDraft(left: 1)), 'Missing values');
  });

  testWidgets('a valid draft saves directly', (tester) async {
    final saved = await pumpForm(tester, RunDraft.fromScores(referenceScores()));
    expect(find.text('Adds up'), findsNWidgets(3));
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(saved.single, referenceScores());
  });

  testWidgets('fixing a field updates the status live', (tester) async {
    await pumpForm(tester, draftWithStage3Total(181222));
    expect(find.text('Off by −1'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('field-2-4')), '181221');
    await tester.pump();
    expect(find.text('Adds up'), findsNWidgets(3));
  });

  testWidgets('a failing sum asks before saving', (tester) async {
    final saved = await pumpForm(tester, draftWithStage3Total(181222));
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text('Save anyway?'), findsOneWidget);
    expect(find.text("Stage 3 doesn't add up."), findsOneWidget);
    await tester.tap(find.text('Save anyway'));
    await tester.pumpAndSettle();
    expect(saved.single.stages[2].total, 181222);
  });

  testWidgets('a missing field disables save', (tester) async {
    await pumpForm(tester, RunDraft.fromScores(referenceScores()));
    await tester.enterText(find.byKey(const Key('field-1-0')), '');
    await tester.pump();
    final save = tester.widget<FilledButton>(find.byKey(const Key('save')));
    expect(save.onPressed, isNull);
    expect(find.text('Missing values'), findsOneWidget);
  });
}
```

- [ ] **Step 10: Run the tests to verify they fail**

Run: `flutter test test/ui/run_form_test.dart`
Expected: FAIL with compile errors (`run_form.dart` not found).

- [ ] **Step 11: Write `lib/ui/dialogs.dart`**

```dart
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
      ],
    ),
  );
  return result ?? false;
}

/// Returns the trimmed text, or null when cancelled or left empty.
Future<String?> promptText(
  BuildContext context, {
  required String title,
  String initial = '',
  String? hint,
  required String action,
}) async {
  final result = await showDialog<String>(
    context: context,
    builder: (context) => _PromptDialog(title: title, initial: initial, hint: hint, action: action),
  );
  final trimmed = result?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

class _PromptDialog extends StatefulWidget {
  const _PromptDialog({required this.title, required this.initial, this.hint, required this.action});

  final String title;
  final String initial;
  final String? hint;
  final String action;

  @override
  State<_PromptDialog> createState() => _PromptDialogState();
}

class _PromptDialogState extends State<_PromptDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(hintText: widget.hint),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(AppLocalizations.of(context).cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(widget.action),
        ),
      ],
    );
  }
}
```

- [ ] **Step 12: Write `lib/ui/run_form.dart`**

```dart
import 'package:flutter/material.dart';

import '../core/models.dart';
import '../l10n/app_localizations.dart';
import 'dialogs.dart';
import 'format.dart';

/// Labels in [StageDraft.fields] order.
List<String> fieldLabels(AppLocalizations l) =>
    [l.slotLeft, l.slotMiddle, l.slotRight, l.fieldBonus, l.fieldTotal];

String stageStatus(AppLocalizations l, StageDraft stage) {
  final scores = stage.toScores();
  if (scores == null) return l.statusMissing;
  if (scores.sumOk) return l.statusAddsUp;
  final diff = scores.sum - scores.total;
  return l.statusOffBy('${diff > 0 ? '+' : '−'}${formatInt(diff.abs())}');
}

/// Fifteen fields (3 stages × left, middle, right, bonus, total) with a live sum check.
class RunForm extends StatefulWidget {
  const RunForm({super.key, required this.initial, required this.onSave, required this.onCancel});

  final RunDraft initial;
  final ValueChanged<RunScores> onSave;
  final VoidCallback onCancel;

  @override
  State<RunForm> createState() => _RunFormState();
}

class _RunFormState extends State<RunForm> {
  late final List<List<TextEditingController>> _controllers = [
    for (final stage in widget.initial.stages)
      [
        for (final value in stage.fields)
          TextEditingController(text: value?.toString() ?? '')..addListener(_changed),
      ],
  ];

  void _changed() => setState(() {});

  @override
  void dispose() {
    for (final row in _controllers) {
      for (final c in row) {
        c.dispose();
      }
    }
    super.dispose();
  }

  RunDraft get _draft => RunDraft([
        for (final row in _controllers)
          StageDraft.fromFields([
            for (final c in row) int.tryParse(c.text.replaceAll(RegExp(r'[,\s]'), '')),
          ]),
      ]);

  Future<void> _save() async {
    final l = AppLocalizations.of(context);
    final draft = _draft;
    final scores = draft.toScores();
    if (scores == null) return;
    final invalid = draft.invalidStages;
    if (invalid.isNotEmpty) {
      final names = invalid.map((i) => l.stageLabel(i + 1)).join(l.listSeparator);
      final ok = await confirm(
        context,
        title: l.saveAnywayTitle,
        message: l.saveAnywayMessage(names),
        action: l.saveAnywayAction,
      );
      if (!ok) return;
    }
    widget.onSave(scores);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final draft = _draft;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (var i = 0; i < _controllers.length; i++)
                _StageSection(index: i, stage: draft.stages[i], controllers: _controllers[i]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: widget.onCancel, child: Text(l.cancel)),
              const SizedBox(width: 8),
              FilledButton(
                key: const Key('save'),
                onPressed: draft.toScores() == null ? null : _save,
                child: Text(l.save),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StageSection extends StatelessWidget {
  const _StageSection({required this.index, required this.stage, required this.controllers});

  final int index;
  final StageDraft stage;
  final List<TextEditingController> controllers;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final labels = fieldLabels(l);
    final scheme = Theme.of(context).colorScheme;
    final ok = stage.isValid;

    Widget field(int f) => TextField(
          key: Key('field-$index-$f'),
          controller: controllers[f],
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: labels[f],
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        );

    return Container(
      key: Key('stage-$index'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: ok ? scheme.outlineVariant : scheme.error, width: ok ? 1 : 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l.stageLabel(index + 1), style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Text(
                stageStatus(l, stage),
                key: Key('status-$index'),
                style: TextStyle(color: ok ? scheme.primary : scheme.error),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var f = 0; f < 3; f++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: f < 2 ? 8 : 0),
                    child: field(f),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: field(3)),
              const SizedBox(width: 8),
              Expanded(child: field(4)),
            ],
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 13: Run all host tests**

Run: `flutter test`
Expected: all tests PASS.

- [ ] **Step 14: Commit**

```bash
git add pubspec.yaml pubspec.lock l10n.yaml lib/l10n lib/ui test/helpers/app.dart test/ui
git commit -m "feat: add shared theme, English and Japanese strings, and run form" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 12: Overlay app

**Files:**
- Create: `lib/overlay/overlay_sizes.dart`, `lib/overlay/outcome_messages.dart`, `lib/overlay/overlay_app.dart`
- Modify: `lib/main.dart` (overlay entry point; delete the spike overlay)
- Test: `test/overlay/outcome_messages_test.dart`

**Interfaces:**
- Consumes: `CaptureController`, `CaptureOutcome` subclasses, `CaptureTarget`, `ScreenCaptureSource`, `MlKitTextReader` (Tasks 9–10), `AppDatabase.open()`, `Repository` (Task 7), `RunForm`, `buildTheme`, `AppLocalizations` (Task 11), `ScreenCapture` (Task 8), results of `docs/notes/overlay-spike.md` (Task 1)
- Produces: `OverlayApp` widget; `outcomeMessage(AppLocalizations, CaptureOutcome) → String`; `OverlaySizes.bubbleDp`, `panelWidthDp`, `panelHeightDp`, `toWindowUnits(double dp, double devicePixelRatio) → int`

- [ ] **Step 1: Write the failing message test**

Create `test/overlay/outcome_messages_test.dart`:

```dart
import 'package:concapt/capture/capture_controller.dart';
import 'package:concapt/l10n/app_localizations.dart';
import 'package:concapt/overlay/outcome_messages.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final ja = lookupAppLocalizations(const Locale('ja'));
  const toasts = <CaptureOutcome>[
    CaptureSaved(7),
    CaptureDuplicate(6),
    CaptureNoResult(),
    CaptureIncomplete(),
    CaptureReadFailed(),
    CaptureStopped(),
  ];

  test('English messages match the spec copy', () {
    expect(toasts.map((o) => outcomeMessage(en, o)), [
      'Run 7 saved',
      'Same as run 6, skipped',
      'No result screen detected',
      "Couldn't read all three stages, try again",
      "Couldn't read screen, try again",
      'Capture stopped. Start again from the app.',
    ]);
  });

  test('every toast has a Japanese message', () {
    for (final o in toasts) {
      expect(outcomeMessage(ja, o), isNot(outcomeMessage(en, o)));
    }
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/overlay/outcome_messages_test.dart`
Expected: FAIL with compile errors (`outcome_messages.dart` not found).

- [ ] **Step 3: Write `lib/overlay/outcome_messages.dart`**

```dart
import '../capture/capture_controller.dart';
import '../l10n/app_localizations.dart';

String outcomeMessage(AppLocalizations l, CaptureOutcome outcome) => switch (outcome) {
      CaptureSaved(:final seq) => l.runSaved(seq),
      CaptureDuplicate(:final seq) => l.runDuplicate(seq),
      CaptureNoResult() => l.noResultScreen,
      CaptureIncomplete() => l.incompleteScreen,
      CaptureReadFailed() => l.readFailed,
      CaptureStopped() => l.captureStopped,
      CaptureNeedsReview() => l.checkHighlightedStage,
    };
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/overlay/outcome_messages_test.dart`
Expected: PASS.

- [ ] **Step 5: Write `lib/overlay/overlay_sizes.dart`**

Set `sizesArePixels` from check 3 in `docs/notes/overlay-spike.md`: `false` when the panel reported about 340 × 400 logical, `true` when it reported about 340/dpr × 400/dpr.

```dart
/// Overlay window sizes for flutter_overlay_window.
abstract final class OverlaySizes {
  /// From docs/notes/overlay-spike.md, check 3.
  static const sizesArePixels = false;

  static const bubbleDp = 56.0;
  static const panelWidthDp = 340.0;
  static const panelHeightDp = 560.0;

  static int toWindowUnits(double dp, double devicePixelRatio) =>
      sizesArePixels ? (dp * devicePixelRatio).round() : dp.round();
}
```

- [ ] **Step 6: Write `lib/overlay/overlay_app.dart`**

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:screen_capture/screen_capture.dart';

import '../capture/capture_controller.dart';
import '../capture/capture_target.dart';
import '../capture/mlkit_text_reader.dart';
import '../capture/screen_capture_source.dart';
import '../core/models.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../l10n/app_localizations.dart';
import '../ui/run_form.dart';
import '../ui/theme.dart';
import 'outcome_messages.dart';
import 'overlay_sizes.dart';

class OverlayApp extends StatelessWidget {
  const OverlayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const OverlayHome(),
    );
  }
}

enum _Mode { starting, bubble, hidden, busy, panel }

class OverlayHome extends StatefulWidget {
  const OverlayHome({super.key});

  @override
  State<OverlayHome> createState() => _OverlayHomeState();
}

class _OverlayHomeState extends State<OverlayHome> {
  _Mode _mode = _Mode.starting;
  CaptureController? _controller;
  AppDatabase? _db;
  MlKitTextReader? _reader;
  RunDraft? _draft;
  StreamSubscription<String>? _stopped;

  @override
  void initState() {
    super.initState();
    // Localizations are readable once the first frame is built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  Future<void> _start() async {
    final l = AppLocalizations.of(context);
    final sessionId = await CaptureTarget.read();
    if (sessionId == null) {
      await ScreenCapture.toast(l.noSessionSelected);
      await FlutterOverlayWindow.closeOverlay();
      return;
    }
    final db = AppDatabase.open();
    final reader = MlKitTextReader();
    _db = db;
    _reader = reader;
    _controller = CaptureController(
      source: ScreenCaptureSource(),
      reader: reader,
      repository: Repository(db),
      sessionId: sessionId,
      hideBubble: _hideBubble,
      showBubble: _showBusy,
    );
    _stopped = ScreenCapture.events.listen((event) {
      if (event == 'stopped') FlutterOverlayWindow.closeOverlay();
    });
    if (mounted) setState(() => _mode = _Mode.bubble);
  }

  @override
  void dispose() {
    _stopped?.cancel();
    _reader?.close();
    _db?.close();
    super.dispose();
  }

  /// Clears the bubble from the screen before the frame is taken.
  Future<void> _hideBubble() async {
    setState(() => _mode = _Mode.hidden);
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 150));
  }

  Future<void> _showBusy() async {
    if (mounted) setState(() => _mode = _Mode.busy);
  }

  Future<void> _onTap() async {
    final controller = _controller;
    if (controller == null) return;
    final l = AppLocalizations.of(context);
    final outcome = await controller.trigger();
    if (outcome == null || !mounted) return;
    switch (outcome) {
      case CaptureNeedsReview(:final draft):
        await _openPanel(draft);
      case CaptureStopped():
        await ScreenCapture.toast(outcomeMessage(l, outcome));
        await FlutterOverlayWindow.closeOverlay();
      default:
        setState(() => _mode = _Mode.bubble);
        await ScreenCapture.toast(outcomeMessage(l, outcome));
    }
  }

  int _units(double dp) =>
      OverlaySizes.toWindowUnits(dp, MediaQuery.devicePixelRatioOf(context));

  Future<void> _openPanel(RunDraft draft) async {
    await FlutterOverlayWindow.resizeOverlay(
      _units(OverlaySizes.panelWidthDp),
      _units(OverlaySizes.panelHeightDp),
      true,
    );
    await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
    if (!mounted) return;
    setState(() {
      _draft = draft;
      _mode = _Mode.panel;
    });
  }

  Future<void> _closePanel() async {
    final bubble = _units(OverlaySizes.bubbleDp);
    await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
    await FlutterOverlayWindow.resizeOverlay(bubble, bubble, true);
    if (!mounted) return;
    setState(() {
      _draft = null;
      _mode = _Mode.bubble;
    });
  }

  Future<void> _save(RunScores scores) async {
    final l = AppLocalizations.of(context);
    final seq = await _controller!.saveReviewed(scores);
    await ScreenCapture.toast(l.runSaved(seq));
    await _closePanel();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: switch (_mode) {
        _Mode.starting || _Mode.hidden => const SizedBox.shrink(),
        _Mode.bubble => _Bubble(onTap: _onTap),
        _Mode.busy => const _Bubble(busy: true),
        _Mode.panel => Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: RunForm(initial: _draft!, onSave: _save, onCancel: _closePanel),
          ),
      },
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({this.onTap, this.busy = false});

  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: busy ? null : onTap,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: scheme.primary.withValues(alpha: 0.85),
        ),
        alignment: Alignment.center,
        child: busy
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: scheme.onPrimary),
              )
            : Icon(Icons.camera_alt, color: scheme.onPrimary),
      ),
    );
  }
}
```

- [ ] **Step 7: Point the overlay entry at the new app**

In `lib/main.dart`:

1. Add `import 'overlay/overlay_app.dart';` to the imports.
2. Replace the `overlayMain` function with:

```dart
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}
```

3. Delete the `SpikeOverlay` and `_SpikeOverlayState` classes.

- [ ] **Step 8: Analyze and build**

Run: `flutter analyze && flutter test && flutter build apk --debug`
Expected: `No issues found!`, all tests PASS, and a built APK. On-device checks for the overlay come in Task 16, once the main app can start a session.

- [ ] **Step 9: Commit**

```bash
git add lib/overlay lib/main.dart test/overlay
git commit -m "feat: add capture overlay with bubble and edit panel" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 13: Sessions screen, capture start/stop, and app shell

**Files:**
- Create: `lib/ui/start_capture.dart`, `lib/ui/sessions_screen.dart`
- Create (stub, completed in Task 14): `lib/ui/session_detail_screen.dart`
- Replace: `lib/main.dart`

**Interfaces:**
- Consumes: `Repository`, `SessionSummary` (Task 7), `CaptureTarget` (Task 10), `ScreenCapture` (Task 8), `OverlaySizes` (Task 12), `confirm`, `promptText`, `buildTheme`, `AppLocalizations` (Task 11), `formatTime` (Task 4)
- Produces:
  - `startCapture(BuildContext, int sessionId) → Future<bool>`
  - `stopCapture() → Future<void>`
  - `isCapturingInto(int sessionId) → Future<bool>`
  - `SessionsScreen({required Repository repository})`
  - `SessionDetailScreen({required Repository repository, required int sessionId})` (stub here)
  - `ConcaptApp({required Repository repository})`

- [ ] **Step 1: Write `lib/ui/start_capture.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:screen_capture/screen_capture.dart';

import '../capture/capture_target.dart';
import '../l10n/app_localizations.dart';
import '../overlay/overlay_sizes.dart';
import 'dialogs.dart';

/// Overlay permission → capture consent → bubble bound to [sessionId].
Future<bool> startCapture(BuildContext context, int sessionId) async {
  final l = AppLocalizations.of(context);
  final devicePixelRatio = MediaQuery.devicePixelRatioOf(context);

  if (!await FlutterOverlayWindow.isPermissionGranted()) {
    if (!context.mounted) return false;
    final go = await confirm(
      context,
      title: l.allowBubbleTitle,
      message: l.allowBubbleMessage,
      action: l.openSettings,
    );
    if (!go) return false;
    await FlutterOverlayWindow.requestPermission();
    if (!await FlutterOverlayWindow.isPermissionGranted()) return false;
  }

  if (!context.mounted) return false;
  final ok = await confirm(
    context,
    title: l.shareScreenTitle,
    message: l.shareScreenMessage,
    action: l.continueAction,
  );
  if (!ok) return false;

  if (!await ScreenCapture.requestConsent()) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.captureDeclined)));
    }
    return false;
  }

  await CaptureTarget.write(sessionId);
  if (await FlutterOverlayWindow.isActive()) await FlutterOverlayWindow.closeOverlay();
  final bubble = OverlaySizes.toWindowUnits(OverlaySizes.bubbleDp, devicePixelRatio);
  await FlutterOverlayWindow.showOverlay(
    width: bubble,
    height: bubble,
    enableDrag: true,
    alignment: OverlayAlignment.centerRight,
    overlayTitle: l.appTitle,
    overlayContent: l.overlayNotification,
  );
  return true;
}

Future<void> stopCapture() async {
  await ScreenCapture.stop();
  if (await FlutterOverlayWindow.isActive()) await FlutterOverlayWindow.closeOverlay();
}

Future<bool> isCapturingInto(int sessionId) async =>
    await ScreenCapture.isRunning() &&
    await FlutterOverlayWindow.isActive() &&
    await CaptureTarget.read() == sessionId;
```

- [ ] **Step 2: Write the session detail stub**

`lib/ui/session_detail_screen.dart` (Task 14 replaces this file):

```dart
import 'package:flutter/material.dart';

import '../data/repository.dart';

class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.repository, required this.sessionId});

  final Repository repository;
  final int sessionId;

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}
```

- [ ] **Step 3: Write `lib/ui/sessions_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../l10n/app_localizations.dart';
import 'dialogs.dart';
import 'format.dart';
import 'session_detail_screen.dart';
import 'start_capture.dart';

class SessionsScreen extends StatefulWidget {
  const SessionsScreen({super.key, required this.repository});

  final Repository repository;

  @override
  State<SessionsScreen> createState() => _SessionsScreenState();
}

class _SessionsScreenState extends State<SessionsScreen> with WidgetsBindingObserver {
  List<SessionSummary>? _sessions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final sessions = await widget.repository.listSessions();
    if (mounted) setState(() => _sessions = sessions);
  }

  Future<void> _create() async {
    final l = AppLocalizations.of(context);
    final name = await promptText(
      context,
      title: l.newSession,
      hint: l.newSessionHint,
      action: l.create,
    );
    if (name == null) return;
    final id = await widget.repository.createSession(name);
    if (!mounted) return;
    await _open(id);
  }

  Future<void> _open(int id) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SessionDetailScreen(repository: widget.repository, sessionId: id),
    ));
    await _reload();
  }

  Future<void> _rename(SessionSummary s) async {
    final l = AppLocalizations.of(context);
    final name = await promptText(context, title: l.renameSession, initial: s.name, action: l.rename);
    if (name == null) return;
    await widget.repository.renameSession(s.id, name);
    await _reload();
  }

  Future<void> _delete(SessionSummary s) async {
    final l = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l.deleteSessionTitle(s.name),
      message: l.deleteSessionMessage(s.runCount),
      action: l.delete,
    );
    if (!ok) return;
    if (await isCapturingInto(s.id)) await stopCapture();
    await widget.repository.deleteSession(s.id);
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sessions = _sessions;
    return Scaffold(
      appBar: AppBar(title: Text(l.appTitle)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: Text(l.newSession),
      ),
      body: switch (sessions) {
        null => const Center(child: CircularProgressIndicator()),
        [] => Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Text(l.sessionsEmpty, textAlign: TextAlign.center),
            ),
          ),
        final list? => ListView(
            children: [
              for (final s in list)
                ListTile(
                  title: Text(s.name),
                  subtitle: Text(l.sessionSubtitle(
                    l.runCount(s.runCount),
                    s.lastCapturedAt == null ? '—' : formatTime(s.lastCapturedAt!),
                  )),
                  onTap: () => _open(s.id),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => v == 'rename' ? _rename(s) : _delete(s),
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'rename', child: Text(l.rename)),
                      PopupMenuItem(value: 'delete', child: Text(l.delete)),
                    ],
                  ),
                ),
            ],
          ),
      },
    );
  }
}
```

- [ ] **Step 4: Replace `lib/main.dart`**

```dart
import 'package:flutter/material.dart';

import 'data/database.dart';
import 'data/repository.dart';
import 'l10n/app_localizations.dart';
import 'overlay/overlay_app.dart';
import 'ui/sessions_screen.dart';
import 'ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(ConcaptApp(repository: Repository(AppDatabase.open())));
}

/// Entry point for the overlay engine started by flutter_overlay_window.
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const OverlayApp());
}

class ConcaptApp extends StatelessWidget {
  const ConcaptApp({super.key, required this.repository});

  final Repository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: SessionsScreen(repository: repository),
    );
  }
}
```

- [ ] **Step 5: Analyze and run the host tests**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` and all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/main.dart lib/ui/start_capture.dart lib/ui/sessions_screen.dart lib/ui/session_detail_screen.dart
git commit -m "feat: add sessions screen and capture start flow" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 14: Session detail, stats cards, run editor, and CSV export

**Files:**
- Create: `lib/ui/stats_card.dart`, `lib/ui/run_editor_screen.dart`
- Create (stub, completed in Task 15): `lib/ui/series_detail_screen.dart`
- Replace: `lib/ui/session_detail_screen.dart`
- Test: `test/ui/stats_card_test.dart`

**Interfaces:**
- Consumes: `Repository` (Task 7), `summarize`, `seriesValues` (Task 4), `buildCsv` (Task 6), `RunForm`, `confirm`, `AppLocalizations` (Task 11), `startCapture`, `stopCapture`, `isCapturingInto` (Task 13), `formatInt`, `formatTime` (Task 4)
- Produces:
  - `slotName(AppLocalizations, int slot) → String`
  - `summaryRows(AppLocalizations, Summary) → List<(String, num?)>`
  - `StatsCard({required int stage, required List<Summary> summaries, required ValueChanged<int> onSlotTap})`; slot header keys `slot-<stage>-<slot>`
  - `RunEditorScreen({required String title, required RunDraft initial})` pops with `RunScores?`
  - `SeriesDetailScreen({required String title, required List<int> values})` (stub here)

- [ ] **Step 1: Add the dependency**

Run: `flutter pub add share_plus`

- [ ] **Step 2: Write the failing test**

Create `test/ui/stats_card_test.dart`:

```dart
import 'package:concapt/core/stats.dart';
import 'package:concapt/ui/stats_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app.dart';

void main() {
  testWidgets('shows each slot column and reports taps', (tester) async {
    final tapped = <int>[];
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: StatsCard(
          stage: 0,
          summaries: [
            summarize(const [100000, 120000]),
            summarize(const [40000]),
            summarize(const []),
          ],
          onSlotTap: tapped.add,
        ),
      ),
    ));

    expect(find.text('Stage 1'), findsOneWidget);
    expect(find.text('110,000'), findsWidgets); // mean and median of left
    expect(find.text('40,000'), findsWidgets);
    expect(find.text('—'), findsNWidgets(6)); // right slot, every stat but n
    await tester.tap(find.byKey(const Key('slot-0-1')));
    expect(tapped, [1]);
  });

  test('summaryRows lists the seven stats in order', () {
    final rows = summaryRows(en(), summarize(const [1, 2, 3]));
    expect(rows.map((r) => r.$1), ['n', 'Mean', 'Median', 'Min', 'Max', 'P25', 'P75']);
    expect(rows.first.$2, 3);
  });
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `flutter test test/ui/stats_card_test.dart`
Expected: FAIL with compile errors.

- [ ] **Step 4: Write `lib/ui/stats_card.dart`**

```dart
import 'package:flutter/material.dart';

import '../core/stats.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';

/// 0 left, 1 middle, 2 right.
String slotName(AppLocalizations l, int slot) => [l.slotLeft, l.slotMiddle, l.slotRight][slot];

List<(String, num?)> summaryRows(AppLocalizations l, Summary s) => [
      (l.statN, s.n),
      (l.statMean, s.mean),
      (l.statMedian, s.median),
      (l.statMin, s.min),
      (l.statMax, s.max),
      (l.statP25, s.p25),
      (l.statP75, s.p75),
    ];

/// One stage's statistics: rows are stats, columns are the three slots.
class StatsCard extends StatelessWidget {
  const StatsCard({
    super.key,
    required this.stage,
    required this.summaries,
    required this.onSlotTap,
  });

  final int stage;
  final List<Summary> summaries;
  final ValueChanged<int> onSlotTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rows = [for (final s in summaries) summaryRows(l, s)];
    final labels = rows.first.map((r) => r.$1).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.stageLabel(stage + 1), style: Theme.of(context).textTheme.titleMedium),
            Table(
              columnWidths: const {0: IntrinsicColumnWidth()},
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(children: [
                  const SizedBox.shrink(),
                  for (var slot = 0; slot < summaries.length; slot++)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        key: Key('slot-$stage-$slot'),
                        onPressed: () => onSlotTap(slot),
                        child: Text(slotName(l, slot)),
                      ),
                    ),
                ]),
                for (var r = 0; r < labels.length; r++)
                  TableRow(children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12, top: 2, bottom: 2),
                      child: Text(labels[r]),
                    ),
                    for (final slotRows in rows)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Text(formatInt(slotRows[r].$2), textAlign: TextAlign.end),
                      ),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `flutter test test/ui/stats_card_test.dart`
Expected: PASS.

- [ ] **Step 6: Write the run editor and the series detail stub**

`lib/ui/run_editor_screen.dart`:

```dart
import 'package:flutter/material.dart';

import '../core/models.dart';
import 'run_form.dart';

/// Edits a saved run; pops with the new [RunScores], or null when cancelled.
class RunEditorScreen extends StatelessWidget {
  const RunEditorScreen({super.key, required this.title, required this.initial});

  final String title;
  final RunDraft initial;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: RunForm(
        initial: initial,
        onSave: (scores) => Navigator.pop(context, scores),
        onCancel: () => Navigator.pop(context),
      ),
    );
  }
}
```

`lib/ui/series_detail_screen.dart` (Task 15 replaces this file):

```dart
import 'package:flutter/material.dart';

class SeriesDetailScreen extends StatelessWidget {
  const SeriesDetailScreen({super.key, required this.title, required this.values});

  final String title;
  final List<int> values;

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(title)));
}
```

- [ ] **Step 7: Replace `lib/ui/session_detail_screen.dart`**

```dart
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/csv.dart';
import '../core/models.dart';
import '../core/stats.dart';
import '../data/database.dart';
import '../data/repository.dart';
import '../l10n/app_localizations.dart';
import 'dialogs.dart';
import 'format.dart';
import 'run_editor_screen.dart';
import 'series_detail_screen.dart';
import 'start_capture.dart';
import 'stats_card.dart';

class SessionDetailScreen extends StatefulWidget {
  const SessionDetailScreen({super.key, required this.repository, required this.sessionId});

  final Repository repository;
  final int sessionId;

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> with WidgetsBindingObserver {
  /// Capture button, three stats cards, and the runs heading.
  static const _headerCount = 5;

  Session? _session;
  List<RunRecord>? _runs;
  bool _capturing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reload();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// The overlay engine saves runs while this app is in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _reload();
  }

  Future<void> _reload() async {
    final session = await widget.repository.session(widget.sessionId);
    final runs = await widget.repository.runs(widget.sessionId);
    final capturing = await isCapturingInto(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _session = session;
      _runs = runs;
      _capturing = capturing;
    });
  }

  Future<void> _toggleCapture() async {
    if (_capturing) {
      await stopCapture();
    } else {
      await startCapture(context, widget.sessionId);
    }
    await _reload();
  }

  void _openSeries(int stage, int slot) {
    final l = AppLocalizations.of(context);
    final values = seriesValues(_runs!, stage, slot);
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => SeriesDetailScreen(
        title: l.seriesTitle(stage + 1, slotName(l, slot)),
        values: values,
      ),
    ));
  }

  Future<void> _edit(RunRecord run) async {
    final l = AppLocalizations.of(context);
    final scores = await Navigator.of(context).push<RunScores>(MaterialPageRoute(
      builder: (_) =>
          RunEditorScreen(title: l.runTitle(run.seq), initial: RunDraft.fromScores(run.scores)),
    ));
    if (scores == null) return;
    await widget.repository.updateRun(run.id, scores);
    await _reload();
  }

  Future<void> _delete(RunRecord run) async {
    final l = AppLocalizations.of(context);
    final ok = await confirm(
      context,
      title: l.deleteRunTitle(run.seq),
      message: l.deleteRunMessage,
      action: l.delete,
    );
    if (!ok) return;
    await widget.repository.deleteRun(run.id);
    await _reload();
  }

  Future<void> _export() async {
    final session = _session!;
    final dir = await getTemporaryDirectory();
    final safeName = session.name.replaceAll(RegExp(r'[^\w\- ]'), '_');
    final file = File('${dir.path}/$safeName.csv');
    await file.writeAsString(buildCsv(_runs!));
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'text/csv')],
      subject: session.name,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final session = _session;
    final runs = _runs;
    if (session == null || runs == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(session.name),
        actions: [
          IconButton(
            tooltip: l.exportCsv,
            icon: const Icon(Icons.ios_share),
            onPressed: runs.isEmpty ? null : _export,
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 24),
        itemCount: _headerCount + runs.length,
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: _toggleCapture,
                icon: Icon(_capturing ? Icons.stop : Icons.camera_alt),
                label: Text(_capturing ? l.stopCapturing : l.startCapturing),
              ),
            );
          }
          if (i <= 3) {
            final stage = i - 1;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: StatsCard(
                stage: stage,
                summaries: [
                  for (var slot = 0; slot < 3; slot++) summarize(seriesValues(runs, stage, slot)),
                ],
                onSlotTap: (slot) => _openSeries(stage, slot),
              ),
            );
          }
          if (i == 4) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(l.runsHeading(runs.length), style: Theme.of(context).textTheme.titleMedium),
            );
          }
          final run = runs[i - _headerCount];
          return ListTile(
            title: Text('${l.runTitle(run.seq)}${run.edited ? ' · ${l.edited}' : ''}'),
            subtitle: Text([
              for (final s in run.scores.stages) s.members.map(formatInt).join(' / '),
            ].join('\n')),
            isThreeLine: true,
            trailing: Text(formatTime(run.capturedAt)),
            onTap: () => _edit(run),
            onLongPress: () => _delete(run),
          );
        },
      ),
    );
  }
}
```

- [ ] **Step 8: Analyze and run the host tests**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` and all tests PASS. If `share_plus` reports that `SharePlus`/`ShareParams` don't exist, check the installed version's README for the current share call and adapt `_export` only.

- [ ] **Step 9: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/ui test/ui/stats_card_test.dart
git commit -m "feat: add session detail with stats, run editing, and CSV export" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 15: Series detail and histogram chart

**Files:**
- Create: `lib/ui/histogram_chart.dart`
- Replace: `lib/ui/series_detail_screen.dart`
- Test: `test/ui/histogram_chart_test.dart`

**Interfaces:**
- Consumes: `Histogram`, `buildHistogram` (Task 5), `summarize` (Task 4), `summaryRows` (Task 14), `AppLocalizations` (Task 11), `formatInt`, `formatCompact` (Task 4)
- Produces: `HistogramChart({required Histogram histogram, double? mean, double? median})`, `HistogramPainter`, final `SeriesDetailScreen`

- [ ] **Step 1: Write the failing test**

Create `test/ui/histogram_chart_test.dart`:

```dart
import 'package:concapt/core/histogram.dart';
import 'package:concapt/ui/histogram_chart.dart';
import 'package:concapt/ui/series_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app.dart';

Finder get painter =>
    find.byWidgetPredicate((w) => w is CustomPaint && w.painter is HistogramPainter);

void main() {
  testWidgets('empty series shows a message instead of a chart', (tester) async {
    await tester.pumpWidget(localizedApp(
      const Scaffold(body: HistogramChart(histogram: Histogram.empty)),
    ));
    expect(find.text('No runs yet'), findsOneWidget);
    expect(painter, findsNothing);
  });

  testWidgets('a series draws bars and labels its markers', (tester) async {
    final values = [for (var i = 0; i < 300; i++) 113000 + (i * 7919) % 15000];
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: SingleChildScrollView(
          child: HistogramChart(histogram: buildHistogram(values), mean: 120000, median: 119500),
        ),
      ),
    ));
    expect(painter, findsOneWidget);
    expect(find.text('Mean 120,000'), findsOneWidget);
    expect(find.text('Median 119,500'), findsOneWidget);
  });

  testWidgets('series detail shows the chart and all seven stats', (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(localizedApp(
      const SeriesDetailScreen(title: 'Stage 1 · Left', values: [100, 200, 300]),
    ));
    expect(find.text('Stage 1 · Left'), findsOneWidget);
    expect(painter, findsOneWidget);
    for (final label in ['n', 'Mean', 'Median', 'Min', 'Max', 'P25', 'P75']) {
      expect(find.text(label), findsOneWidget);
    }
  });

  testWidgets('empty series detail does not crash', (tester) async {
    await tester.pumpWidget(localizedApp(
      const SeriesDetailScreen(title: 'Stage 1 · Left', values: []),
    ));
    expect(find.text('No runs yet'), findsOneWidget);
  });

  testWidgets('dark theme renders the chart', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(localizedApp(
      const SeriesDetailScreen(title: 'Stage 1 · Left', values: [100, 200, 300]),
    ));
    expect(painter, findsOneWidget);
    final context = tester.element(painter);
    expect(Theme.of(context).brightness, Brightness.dark);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/ui/histogram_chart_test.dart`
Expected: FAIL with compile errors (`histogram_chart.dart` not found).

- [ ] **Step 3: Write `lib/ui/histogram_chart.dart`**

```dart
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/histogram.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';

class HistogramChart extends StatelessWidget {
  const HistogramChart({super.key, required this.histogram, this.mean, this.median});

  final Histogram histogram;
  final double? mean;
  final double? median;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (histogram.counts.isEmpty) {
      return SizedBox(height: 200, child: Center(child: Text(l.noRunsYet)));
    }
    final scheme = Theme.of(context).colorScheme;
    final labelStyle =
        Theme.of(context).textTheme.labelSmall!.copyWith(color: scheme.onSurfaceVariant);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 1.4,
          child: CustomPaint(
            painter: HistogramPainter(
              histogram: histogram,
              mean: mean,
              median: median,
              barColor: scheme.primaryContainer,
              meanColor: scheme.primary,
              medianColor: scheme.tertiary,
              axisColor: scheme.outline,
              labelStyle: labelStyle,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          children: [
            _LegendItem(color: scheme.primary, label: l.legendMean(formatInt(mean))),
            _LegendItem(color: scheme.tertiary, label: l.legendMedian(formatInt(median))),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}

class HistogramPainter extends CustomPainter {
  HistogramPainter({
    required this.histogram,
    required this.mean,
    required this.median,
    required this.barColor,
    required this.meanColor,
    required this.medianColor,
    required this.axisColor,
    required this.labelStyle,
  });

  final Histogram histogram;
  final double? mean;
  final double? median;
  final Color barColor;
  final Color meanColor;
  final Color medianColor;
  final Color axisColor;
  final TextStyle labelStyle;

  static const _labelHeight = 20.0;
  static const _maxLabels = 5;

  @override
  void paint(Canvas canvas, Size size) {
    final chartHeight = size.height - _labelHeight;
    final lo = histogram.start.toDouble();
    final hi = histogram.end.toDouble();
    double xOf(num value) => (value - lo) / (hi - lo) * size.width;

    final maxCount = histogram.counts.reduce(math.max);
    final bar = Paint()..color = barColor;
    for (var i = 0; i < histogram.counts.length; i++) {
      final height = histogram.counts[i] / maxCount * chartHeight;
      final left = xOf(histogram.lowerEdge(i)) + 1;
      final right = math.max(left, xOf(histogram.lowerEdge(i + 1)) - 1);
      canvas.drawRect(Rect.fromLTRB(left, chartHeight - height, right, chartHeight), bar);
    }

    canvas.drawLine(
      Offset(0, chartHeight),
      Offset(size.width, chartHeight),
      Paint()
        ..color = axisColor
        ..strokeWidth = 1,
    );

    final every = (histogram.counts.length / (_maxLabels - 1)).ceil();
    for (var i = 0; i <= histogram.counts.length; i += every) {
      final label = TextPainter(
        text: TextSpan(text: formatCompact(histogram.lowerEdge(i)), style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = math.max(
        0.0,
        math.min(xOf(histogram.lowerEdge(i)) - label.width / 2, size.width - label.width),
      );
      label.paint(canvas, Offset(x, chartHeight + 4));
    }

    void marker(double? value, Color color) {
      if (value == null) return;
      final x = xOf(value);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, chartHeight),
        Paint()
          ..color = color
          ..strokeWidth = 2,
      );
    }

    marker(mean, meanColor);
    marker(median, medianColor);
  }

  @override
  bool shouldRepaint(HistogramPainter old) =>
      old.histogram != histogram ||
      old.mean != mean ||
      old.median != median ||
      old.barColor != barColor;
}
```

- [ ] **Step 4: Replace `lib/ui/series_detail_screen.dart`**

```dart
import 'package:flutter/material.dart';

import '../core/histogram.dart';
import '../core/stats.dart';
import '../l10n/app_localizations.dart';
import 'format.dart';
import 'histogram_chart.dart';
import 'stats_card.dart';

/// One member's score distribution within a session.
class SeriesDetailScreen extends StatelessWidget {
  const SeriesDetailScreen({super.key, required this.title, required this.values});

  final String title;
  final List<int> values;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final summary = summarize(values);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          HistogramChart(
            histogram: buildHistogram(values),
            mean: summary.mean,
            median: summary.median,
          ),
          const SizedBox(height: 16),
          for (final (label, value) in summaryRows(l, summary))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [Text(label), const Spacer(), Text(formatInt(value))]),
            ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/ui/histogram_chart_test.dart`
Expected: all tests PASS.

- [ ] **Step 6: Analyze and run everything**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` and all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add lib/ui/histogram_chart.dart lib/ui/series_detail_screen.dart test/ui/histogram_chart_test.dart
git commit -m "feat: add per-series histogram screen" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 16: End-to-end check on the phone [device]

**Files:**
- Create: `docs/manual-test-checklist.md`

**Interfaces:**
- Consumes: the whole app.

- [ ] **Step 1: Write the checklist**

Create `docs/manual-test-checklist.md`:

```markdown
# Manual test checklist

Run on the user's phone (never the emulator) after any change to capture, overlay, or screens.

| # | Area | Steps | Expected |
|---|---|---|---|
| 1 | Session | New session "Test" | Opens the session; stats show "—"; Export is disabled |
| 2 | Overlay permission | Start capturing on a fresh install | Explanation dialog, then Android's "Display over other apps" settings |
| 3 | Consent | Continue, choose Entire screen, Start | Bubble appears; button reads "Stop capturing" |
| 4 | Declined consent | Stop, Start again, Cancel on Android's dialog | Snackbar "Screen capture was declined."; no bubble |
| 5 | Auto-save | In the game, open a rehearsal result, tap the bubble | Spinner, then toast "Run 1 saved"; the bubble is not in any captured frame |
| 6 | Duplicate | Tap the bubble again on the same result | Toast "Same as run 1, skipped" |
| 7 | Not a result | Tap the bubble on the game's home screen | Toast "No result screen detected" |
| 8 | Double tap | Tap the bubble twice quickly on a new result | One run saved, one toast |
| 9 | Edit panel | Use any capture that opens the panel. If none did in rows 5–8, tap the bubble while the result screen is still appearing | Panel opens; failing stage outlined; keyboard works; Save anyway asks to confirm; toast "Run N saved" |
| 10 | Panel cancel | Open the panel, Cancel | Back to the bubble; nothing saved |
| 11 | Background save | Return to the app | New runs listed; stats updated without restarting |
| 12 | Series | Tap a slot column | Histogram with mean and median lines and seven stats |
| 13 | Edit run | Tap a run, change a number, Save | "edited" mark; stats change |
| 14 | Delete run | Long-press a run, Delete | Run gone; next capture still gets a new number |
| 15 | CSV | Export CSV, share to a file app | Header plus one row per run, oldest first |
| 16 | Screen lock | While capturing, lock and unlock, tap the bubble | Toast "Capture stopped. Start again from the app."; bubble closes |
| 17 | App killed | Start capturing, swipe the app from Recents, capture a result | Toast "Run N saved"; reopening the app shows the run |
| 18 | Delete active session | While capturing into a session, delete it from the sessions list | Bubble closes; session removed |
| 19 | Japanese | Set the phone language to 日本語, then repeat rows 1, 5, 7, and 12 | Every screen, dialog, toast, and the capture notification is in Japanese; no English left over |
| 20 | Dark theme | Turn on system dark mode, then open the session detail, a series, and the edit panel | Both engines switch to dark; pass/fail, "edited", and markers stay readable; score columns line up |
```

- [ ] **Step 2: Install on the phone [device]**

Ask the user to connect their phone if it isn't already, and confirm with `adb devices`.

Run: `flutter run --release -d <device-id>`

- [ ] **Step 3: Walk through the checklist with the user [device]**

Go through rows 1–20 with the user. Before row 19, ask the user to review the Japanese strings in `lib/l10n/app_ja.arb` and `res/values-ja`. For each row, record pass or fail and what they saw. Capture at least 10 real results in row 5–8 so the phone-resolution OCR path is exercised (spec §10, "OCR accuracy on phone captures").

- [ ] **Step 4: Fix failures**

For each failing row, use superpowers:systematic-debugging before changing code. Add a host test where the failure is in Dart logic. Rerun the affected rows.

- [ ] **Step 5: Final verification**

Run: `flutter analyze && flutter test`
Expected: `No issues found!` and all tests PASS.

- [ ] **Step 6: Commit**

```bash
git add docs/manual-test-checklist.md
git commit -m "docs: add manual device checklist" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
