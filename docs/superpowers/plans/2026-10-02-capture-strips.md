# Capture Strips Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The edit panel shows each failing stage's numbers as a strip cropped from the captured frame, and folds stages that add up.

**Architecture:** The parser reports each stage's pixel bounds. The capture outcome carries the frame path and those bounds to the overlay, which decodes the frame once and hands the shared run form one strip widget per stage. The form gains optional previews and folding; the main app's run editor uses neither.

**Tech Stack:** Flutter 3.41.4 / Dart 3.11.1, `dart:ui` image decoding, `flutter_test`.

**Spec:** `docs/superpowers/specs/2026-10-02-capture-strips-design.md`

## Global Constraints

- `lib/core/` is pure Dart: no Flutter imports.
- UI copy lives in `lib/l10n/app_en.arb` and `app_ja.arb`, never in Dart. Run `flutter gen-l10n` after editing them.
- Use theme colors (`colorScheme.*`, `textTheme.*`); no hard-coded colors or font sizes.
- `flutter analyze` and `flutter test` pass before every commit.
- Commit messages end with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Device checks use the user's phone, never the emulator. Install with `flutter build apk --release` then `adb install -r build/app/outputs/flutter-apk/app-release.apk` (not `flutter run`, which can wipe data).

## Review Focus

- A stage whose bonus wasn't read still gets bounds covering its total and members (Task 1 test).
- Bounds that reach past the frame's edges are clamped, not painted out of range (Task 4 test).
- A frame file that is missing or undecodable leaves the panel working with no strips (Task 4 test on `decodeFrame`).
- Folding a stage whose field has focus drops the quick fix and shows the status again, without errors (Task 3 test).
- Save still checks folded stages, so a folded failing stage still triggers "Save anyway?" (Task 3 test).

---

### Task 1: Stage bounds from the parser

**Files:**
- Create: `lib/core/pixel_rect.dart`
- Modify: `lib/core/result_parser.dart` (`ParsedRun`, `parse`, new `_bounds`)
- Modify: `docs/superpowers/specs/2026-10-02-capture-strips-design.md` (bounds are never null)
- Test: `test/core/pixel_rect_test.dart` (create), `test/core/result_parser_test.dart`, `test/core/fixture_test.dart`

**Interfaces:**
- Produces: `class PixelRect { const PixelRect(double left, double top, double right, double bottom); double get width; double get height; PixelRect clamp(double width, double height); }` with value equality.
- Produces: `ParsedRun(RunDraft draft, List<PixelRect> stageBounds)`, one rect per stage, top to bottom.

- [ ] **Step 1: Write the failing PixelRect test**

Create `test/core/pixel_rect_test.dart`:

```dart
import 'package:concapt/core/pixel_rect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('width and height', () {
    const r = PixelRect(10, 20, 110, 70);
    expect(r.width, 100);
    expect(r.height, 50);
  });

  test('clamp keeps a rect inside the image', () {
    expect(
      const PixelRect(-8, -8, 1230, 900).clamp(1220, 2712),
      const PixelRect(0, 0, 1220, 900),
    );
  });
}
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/core/pixel_rect_test.dart`
Expected: FAIL, `pixel_rect.dart` doesn't exist.

- [ ] **Step 3: Write PixelRect**

Create `lib/core/pixel_rect.dart`:

```dart
/// A rectangle in image pixels.
class PixelRect {
  const PixelRect(this.left, this.top, this.right, this.bottom);

  final double left;
  final double top;
  final double right;
  final double bottom;

  double get width => right - left;
  double get height => bottom - top;

  /// This rect, cut to an image of [width] × [height].
  PixelRect clamp(double width, double height) => PixelRect(
        left.clamp(0, width).toDouble(),
        top.clamp(0, height).toDouble(),
        right.clamp(0, width).toDouble(),
        bottom.clamp(0, height).toDouble(),
      );

  @override
  bool operator ==(Object other) =>
      other is PixelRect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'PixelRect($left, $top, $right, $bottom)';
}
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/core/pixel_rect_test.dart`
Expected: PASS.

- [ ] **Step 5: Write the failing bounds tests**

The synthetic screen in `test/helpers/screen.dart` places, for a stage at `y`: the total at x 170–300, y to y+30; members at x 120, 200, 280 (each 60 wide), y+38 to y+54; the bonus at x 120–190, y+58 to y+74; placement badges from y+110. Append to `test/core/result_parser_test.dart` inside `main()`:

```dart
  group('stage bounds', () {
    test('cover the total, members, and bonus of each stage', () {
      final result = ResultParser.parse(screenPieces(referenceScores())) as ParsedRun;
      expect(result.stageBounds, hasLength(3));
      for (var i = 0; i < 3; i++) {
        final y = stageTops[i];
        final b = result.stageBounds[i];
        expect(b.top, lessThanOrEqualTo(y));
        expect(b.left, lessThanOrEqualTo(120));
        expect(b.right, greaterThanOrEqualTo(340));
        expect(b.bottom, greaterThanOrEqualTo(y + 74));
        expect(b.bottom, lessThan(y + 110));
      }
    });

    test('without a bonus, the members set the bottom', () {
      final y = stageTops[0];
      final pieces = screenPieces(referenceScores())
          .where((p) => !(p.text.startsWith('+') && p.top == y + 58))
          .toList();
      final b = (ResultParser.parse(pieces) as ParsedRun).stageBounds[0];
      expect(b.bottom, greaterThanOrEqualTo(y + 54));
      expect(b.bottom, lessThan(y + 110));
    });
  });
```

Append to `test/core/fixture_test.dart` inside `main()`:

```dart
  test('stage bounds stack top to bottom without overlapping', () {
    for (final f in files) {
      final json = _load(f);
      if (json['passed'] != true) continue;
      final bounds = (ResultParser.parse(_pieces(json)) as ParsedRun).stageBounds;
      final name = f.uri.pathSegments.last;
      for (var i = 0; i < bounds.length; i++) {
        expect(bounds[i].width, greaterThan(0), reason: name);
        expect(bounds[i].height, greaterThan(0), reason: name);
        if (i + 1 < bounds.length) {
          expect(bounds[i].bottom, lessThanOrEqualTo(bounds[i + 1].top), reason: name);
        }
      }
    }
  });
```

- [ ] **Step 6: Run them to verify they fail**

Run: `flutter test test/core/result_parser_test.dart test/core/fixture_test.dart`
Expected: FAIL, `stageBounds` isn't defined for `ParsedRun`.

- [ ] **Step 7: Report bounds from the parser**

In `lib/core/result_parser.dart`, add the import:

```dart
import 'pixel_rect.dart';
```

Replace `ParsedRun`:

```dart
class ParsedRun extends ParseResult {
  const ParsedRun(this.draft, this.stageBounds);

  final RunDraft draft;

  /// Each stage's total, members, and bonus in frame pixels, top to bottom.
  final List<PixelRect> stageBounds;
}
```

Replace the `return ParsedRun(...)` at the end of `parse`:

```dart
    final anchors = _slotAnchors(memberRows);
    return ParsedRun(
      RunDraft([
        for (var i = 0; i < totals.length; i++)
          _stage(memberRows[i], anchors, bonuses[i]?.value, totals[i].value),
      ]),
      [
        for (var i = 0; i < totals.length; i++)
          _bounds(totals[i], [...memberRows[i], ?bonuses[i]], tolerance),
      ],
    );
  }

  /// From the total's top down through [below], widened by [margin].
  static PixelRect _bounds(_Token total, List<_Token> below, double margin) {
    final pieces = [total.piece, for (final t in below) t.piece];
    return PixelRect(
      pieces.map((p) => p.left).reduce(math.min) - margin,
      total.piece.top - margin,
      pieces.map((p) => p.right).reduce(math.max) + margin,
      pieces.map((p) => p.bottom).reduce(math.max) + margin,
    );
  }
```

(`?bonuses[i]` is Dart 3.8+ null-aware element syntax: it adds the bonus only when it isn't null.)

- [ ] **Step 8: Run them to verify they pass**

Run: `flutter test test/core`
Expected: PASS, including the existing parser and fixture tests.

- [ ] **Step 9: Align the spec**

In `docs/superpowers/specs/2026-10-02-capture-strips-design.md`:
- In the Interfaces table, change both `List<PixelRect?> stageBounds` to `List<PixelRect> stageBounds`.
- In Failure handling, delete the row `| A stage has null bounds | That stage has no strip |`.

- [ ] **Step 10: Analyze, test, commit**

```bash
flutter analyze && flutter test
git add lib/core test/core docs/superpowers/specs/2026-10-02-capture-strips-design.md
git commit -m "feat: report each stage's bounds from the parser" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: Carry the frame to the review outcome

**Files:**
- Modify: `lib/capture/capture_controller.dart` (`CaptureNeedsReview`, `trigger`)
- Test: `test/capture/capture_controller_test.dart`

**Interfaces:**
- Consumes: `ParsedRun.stageBounds` (Task 1).
- Produces: `CaptureNeedsReview(RunDraft draft, {required String framePath, required List<PixelRect> stageBounds})`.

- [ ] **Step 1: Write the failing test**

In `test/capture/capture_controller_test.dart`, in the test `'a failed sum asks for review and saves nothing'`, replace:

```dart
    expect((outcome as CaptureNeedsReview).draft.invalidStages, {2});
```

with:

```dart
    final review = outcome as CaptureNeedsReview;
    expect(review.draft.invalidStages, {2});
    expect(review.framePath, '/tmp/capture.png');
    expect(review.stageBounds, hasLength(3));
```

- [ ] **Step 2: Run it to verify it fails**

Run: `flutter test test/capture/capture_controller_test.dart`
Expected: FAIL, `framePath` isn't defined.

- [ ] **Step 3: Carry the frame**

In `lib/capture/capture_controller.dart`, add `import '../core/pixel_rect.dart';` and replace `CaptureNeedsReview`:

```dart
class CaptureNeedsReview extends CaptureOutcome {
  const CaptureNeedsReview(this.draft, {required this.framePath, required this.stageBounds});

  final RunDraft draft;

  /// The captured frame, and where each stage sits in it.
  final String framePath;
  final List<PixelRect> stageBounds;
}
```

In `trigger`, replace the `ParsedRun` case's first two lines:

```dart
        case ParsedRun(:final draft, :final stageBounds):
          final scores = draft.toScores();
          if (scores == null || !scores.allSumsOk) {
            return CaptureNeedsReview(draft, framePath: path, stageBounds: stageBounds);
          }
```

- [ ] **Step 4: Run it to verify it passes**

Run: `flutter test test/capture`
Expected: PASS.

- [ ] **Step 5: Analyze, test, commit**

```bash
flutter analyze && flutter test
git add lib/capture test/capture
git commit -m "feat: carry the frame and stage bounds to review" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: Folding and preview slots in the run form

**Files:**
- Modify: `lib/ui/run_form.dart` (`RunForm`, `_RunFormState`, `_StageSection`)
- Test: `test/ui/run_form_test.dart`

**Interfaces:**
- Produces: `RunForm({..., List<Widget?>? stagePreviews, bool foldPassing = false})`. With `foldPassing`, stages that add up start folded, and tapping a band (key `band-<stage>`) toggles it. Each stage's preview shows above its fields while unfolded.

- [ ] **Step 1: Write the failing tests**

In `test/ui/run_form_test.dart`, add this helper below `pumpForm`:

```dart
Future<void> pumpReview(WidgetTester tester, RunDraft draft) async {
  tester.view.physicalSize = const Size(1200, 2800);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(localizedApp(
    Scaffold(
      body: RunForm(
        initial: draft,
        onSave: (_) {},
        onCancel: () {},
        foldPassing: true,
        stagePreviews: [for (var i = 0; i < 3; i++) SizedBox(key: Key('preview-$i'), height: 40)],
      ),
    ),
  ));
}
```

Add these tests inside `main()`:

```dart
  testWidgets('review folds passing stages and opens failing ones', (tester) async {
    await pumpReview(tester, draftWithStage3Total(181222));
    expect(find.byKey(const Key('field-0-0')), findsNothing);
    expect(find.byKey(const Key('preview-0')), findsNothing);
    expect(find.byKey(const Key('field-2-0')), findsOneWidget);
    expect(find.byKey(const Key('preview-2')), findsOneWidget);
    expect(find.byIcon(Icons.expand_more), findsNWidgets(2));
    expect(find.byIcon(Icons.expand_less), findsOneWidget);

    await tester.tap(find.byKey(const Key('band-0')));
    await tester.pump();
    expect(find.byKey(const Key('field-0-0')), findsOneWidget);
    expect(find.byKey(const Key('preview-0')), findsOneWidget);
  });

  testWidgets('folding a focused failing stage shows its status again', (tester) async {
    await pumpReview(tester, draftWithStage3Total(181222));
    await tester.tap(find.byKey(const Key('field-2-4')));
    await tester.pump();
    expect(find.byKey(const Key('fix-2')), findsOneWidget);

    await tester.tap(find.byKey(const Key('band-2')));
    await tester.pump();
    expect(find.byKey(const Key('field-2-4')), findsNothing);
    expect(find.byKey(const Key('fix-2')), findsNothing);
    expect(find.text('Off by −1'), findsOneWidget);
  });

  testWidgets('save still checks folded stages', (tester) async {
    await pumpReview(tester, draftWithStage3Total(181222));
    await tester.tap(find.byKey(const Key('band-2')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('save')));
    await tester.pumpAndSettle();
    expect(find.text("Stage 3 doesn't add up."), findsOneWidget);
  });

  testWidgets('the plain form has no fold bands', (tester) async {
    await pumpForm(tester, draftWithStage3Total(181222));
    expect(find.byKey(const Key('band-0')), findsNothing);
    expect(find.byKey(const Key('field-0-0')), findsOneWidget);
  });
```

- [ ] **Step 2: Run them to verify they fail**

Run: `flutter test test/ui/run_form_test.dart`
Expected: FAIL, no named parameter `foldPassing`.

- [ ] **Step 3: Add the inputs to RunForm**

In `lib/ui/run_form.dart`, replace the `RunForm` constructor and fields:

```dart
class RunForm extends StatefulWidget {
  const RunForm({
    super.key,
    required this.initial,
    required this.onSave,
    required this.onCancel,
    this.stagePreviews,
    this.foldPassing = false,
  });

  final RunDraft initial;
  final ValueChanged<RunScores> onSave;
  final VoidCallback onCancel;

  /// Shown above each stage's fields, such as a crop of the captured frame.
  final List<Widget?>? stagePreviews;

  /// Starts stages that add up folded, and lets every band fold its stage.
  final bool foldPassing;
```

In `_RunFormState`, add below `_focus`:

```dart
  late final List<bool> _folded = [
    for (final stage in widget.initial.stages) widget.foldPassing && stage.isValid,
  ];
```

In `build`, replace the `_StageSection(...)` call with:

```dart
                _StageSection(
                  index: i,
                  stage: draft.stages[i],
                  controllers: _controllers[i],
                  focusNodes: _focus[i],
                  onFix: (field, value) => _fill(i, field, value),
                  preview: widget.stagePreviews?[i],
                  folded: _folded[i],
                  onToggleFold:
                      widget.foldPassing ? () => setState(() => _folded[i] = !_folded[i]) : null,
                ),
```

- [ ] **Step 4: Fold and show previews in _StageSection**

Replace the `_StageSection` doc comment, constructor, and fields:

```dart
/// One stage as a ruled module: a header band with the red numbered tab
/// and the sum status, then an optional preview and the five score fields.
/// While a field of a failing stage has focus, the status gives way to a
/// quick fix for it. With [onToggleFold], the band folds the stage.
class _StageSection extends StatelessWidget {
  const _StageSection({
    required this.index,
    required this.stage,
    required this.controllers,
    required this.focusNodes,
    required this.onFix,
    required this.preview,
    required this.folded,
    required this.onToggleFold,
  });

  final int index;
  final StageDraft stage;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final void Function(int field, int value) onFix;
  final Widget? preview;
  final bool folded;
  final VoidCallback? onToggleFold;
```

In `build`, replace the `return Column(...)` with:

```dart
    final band = ModuleBand(
      color: ok ? null : scheme.errorContainer,
      tab: ExcludeSemantics(child: ModuleTab(twoDigits(index + 1))),
      child: Row(
        children: [
          Semantics(
            header: true,
            child: Text(l.stageLabel(index + 1), style: text.titleSmall),
          ),
          const Spacer(),
          if (fix != null)
            // Inside the fields' tap region, so tapping it keeps their focus.
            TextFieldTapRegion(
              child: OutlinedButton(
                key: Key('fix-$index'),
                onPressed: () => onFix(focused, fix),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.onErrorContainer,
                  side: BorderSide(color: scheme.onErrorContainer),
                  textStyle: bold(text.labelLarge),
                  // As short as the status it replaces, so the band keeps its height.
                  minimumSize: Size.zero,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(l.quickFix(labels[focused], formatInt(fix))),
              ),
            )
          else
            Text(
              stageStatus(l, stage),
              key: Key('status-$index'),
              style: ok
                  ? text.labelLarge?.copyWith(color: scheme.onSurface)
                  : bold(text.labelLarge)?.copyWith(color: scheme.onErrorContainer),
            ),
          if (onToggleFold != null) ...[
            const SizedBox(width: 4),
            Icon(
              folded ? Icons.expand_more : Icons.expand_less,
              size: 20,
              color: ok ? scheme.onSurfaceVariant : scheme.onErrorContainer,
            ),
          ],
        ],
      ),
    );

    return Column(
      key: Key('stage-$index'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onToggleFold != null)
          InkWell(key: Key('band-$index'), onTap: onToggleFold, child: band)
        else
          band,
        if (!folded) ...[
          if (preview != null)
            Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 0), child: preview),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
            child: Column(
              children: [
                Row(children: [field(0), gap, field(1), gap, field(2)]),
                const SizedBox(height: 12),
                Row(children: [field(3), gap, field(4)]),
              ],
            ),
          ),
        ],
      ],
    );
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `flutter test test/ui/run_form_test.dart`
Expected: PASS, including the earlier quick fix and save tests.

- [ ] **Step 6: Analyze, test, commit**

```bash
flutter analyze && flutter test
git add lib/ui/run_form.dart test/ui/run_form_test.dart
git commit -m "feat: fold passing stages and show previews in the run form" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: The capture strip widget

**Files:**
- Create: `lib/overlay/capture_strip.dart`
- Modify: `lib/l10n/app_en.arb`, `lib/l10n/app_ja.arb`
- Test: `test/overlay/capture_strip_test.dart` (create)

**Interfaces:**
- Consumes: `PixelRect` and `PixelRect.clamp` (Task 1).
- Produces: `Future<ui.Image?> decodeFrame(String path)` (null on any failure) and `CaptureStrip({Key? key, required ui.Image image, required PixelRect rect, bool collapsed = false})`. The expanded strip has key `strip`; tapping it collapses to a "Show capture" row, and tapping that row restores it.

- [ ] **Step 1: Add the strings**

In `lib/l10n/app_en.arb`, insert before the line starting `  "saveAnywayAction"`:

```json
  "showCapture": "Show capture",
  "hideCapture": "Hide capture",
```

In `lib/l10n/app_ja.arb`, insert before the line starting `  "saveAnywayAction"`:

```json
  "showCapture": "キャプチャを表示",
  "hideCapture": "キャプチャを隠す",
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing tests**

Create `test/overlay/capture_strip_test.dart`:

```dart
import 'package:concapt/core/pixel_rect.dart';
import 'package:concapt/overlay/capture_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/app.dart';

void main() {
  testWidgets('a strip spans the width at its crop ratio and collapses on tap', (tester) async {
    final image = (await tester.runAsync(() => createTestImage(width: 1000, height: 2000)))!;
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: CaptureStrip(image: image, rect: const PixelRect(100, 200, 600, 300)),
          ),
        ),
      ),
    ));

    final size = tester.getSize(find.byKey(const Key('strip')));
    expect(size.width, 400);
    expect(size.height, closeTo(80, 0.5)); // a 500 × 100 crop at 400 wide

    await tester.tap(find.byKey(const Key('strip')));
    await tester.pump();
    expect(find.byKey(const Key('strip')), findsNothing);
    expect(find.text('Show capture'), findsOneWidget);

    await tester.tap(find.text('Show capture'));
    await tester.pump();
    expect(find.byKey(const Key('strip')), findsOneWidget);
  });

  testWidgets('a strip past the frame edge is clamped to it', (tester) async {
    final image = (await tester.runAsync(() => createTestImage(width: 1000, height: 2000)))!;
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: Center(
          child: SizedBox(
            width: 400,
            child: CaptureStrip(image: image, rect: const PixelRect(-50, 1900, 1100, 2100)),
          ),
        ),
      ),
    ));
    // Clamped to 1000 × 100, so 40 tall at 400 wide.
    expect(tester.getSize(find.byKey(const Key('strip'))).height, closeTo(40, 0.5));
  });

  testWidgets('a collapsed strip starts as the show row', (tester) async {
    final image = (await tester.runAsync(() => createTestImage(width: 10, height: 10)))!;
    await tester.pumpWidget(localizedApp(
      Scaffold(
        body: CaptureStrip(image: image, rect: const PixelRect(0, 0, 10, 10), collapsed: true),
      ),
    ));
    expect(find.byKey(const Key('strip')), findsNothing);
    expect(find.text('Show capture'), findsOneWidget);
  });

  test('decodeFrame returns null when the file is missing', () async {
    expect(await decodeFrame('/no/such/capture.png'), isNull);
  });
}
```

- [ ] **Step 3: Run them to verify they fail**

Run: `flutter test test/overlay/capture_strip_test.dart`
Expected: FAIL, `capture_strip.dart` doesn't exist.

- [ ] **Step 4: Write the strip**

Create `lib/overlay/capture_strip.dart`:

```dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../core/pixel_rect.dart';
import '../l10n/app_localizations.dart';

/// Decodes the captured frame, or returns null if it can't be read.
Future<ui.Image?> decodeFrame(String path) async {
  try {
    final codec = await ui.instantiateImageCodec(await File(path).readAsBytes());
    return (await codec.getNextFrame()).image;
  } catch (_) {
    return null;
  }
}

/// One stage cropped from the captured frame, at full width. Tapping it
/// folds it to a one-line row that brings it back.
class CaptureStrip extends StatefulWidget {
  const CaptureStrip({super.key, required this.image, required this.rect, this.collapsed = false});

  final ui.Image image;
  final PixelRect rect;
  final bool collapsed;

  @override
  State<CaptureStrip> createState() => _CaptureStripState();
}

class _CaptureStripState extends State<CaptureStrip> {
  late bool _collapsed = widget.collapsed;

  void _toggle() => setState(() => _collapsed = !_collapsed);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (_collapsed) {
      return InkWell(
        onTap: _toggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              Icon(Icons.image_outlined, size: 18, color: scheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(l.showCapture, style: text.labelLarge?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    final src = widget.rect.clamp(widget.image.width.toDouble(), widget.image.height.toDouble());
    return Semantics(
      button: true,
      label: l.hideCapture,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('strip'),
        onTap: _toggle,
        child: AspectRatio(
          aspectRatio: src.width / src.height,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(border: Border.all(color: scheme.outlineVariant)),
            child: CustomPaint(painter: _StripPainter(widget.image, src)),
          ),
        ),
      ),
    );
  }
}

class _StripPainter extends CustomPainter {
  _StripPainter(this.image, this.src);

  final ui.Image image;
  final PixelRect src;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawImageRect(
      image,
      Rect.fromLTRB(src.left, src.top, src.right, src.bottom),
      Offset.zero & size,
      Paint()..filterQuality = FilterQuality.medium,
    );
  }

  @override
  bool shouldRepaint(_StripPainter old) => old.image != image || old.src != src;
}
```

- [ ] **Step 5: Run them to verify they pass**

Run: `flutter test test/overlay/capture_strip_test.dart`
Expected: PASS.

- [ ] **Step 6: Analyze, test, commit**

```bash
flutter analyze && flutter test
git add lib/overlay/capture_strip.dart lib/l10n test/overlay/capture_strip_test.dart
git commit -m "feat: add the capture strip widget" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: Wire strips into the edit panel

**Files:**
- Modify: `lib/overlay/overlay_app.dart` (`_OverlayHomeState`: `_onTap`, `_openPanel`, `_closePanel`, `_start`, `dispose`, `build`)
- Modify: `docs/manual-test-checklist.md`

**Interfaces:**
- Consumes: `CaptureNeedsReview.framePath` and `.stageBounds` (Task 2); `RunForm.stagePreviews` and `.foldPassing` (Task 3); `decodeFrame` and `CaptureStrip` (Task 4).

The overlay has no host tests (it needs the overlay plugin's window); this task is verified on the phone.

- [ ] **Step 1: Hold the frame in the overlay state**

In `lib/overlay/overlay_app.dart`, add the imports:

```dart
import 'dart:ui' as ui;

import '../core/pixel_rect.dart';
import 'capture_strip.dart';
```

In `_OverlayHomeState`, add below `CaptureController? _draftController;`:

```dart
  // The reviewed capture, held while the panel is open.
  ui.Image? _frame;
  List<PixelRect> _stageBounds = const [];

  void _dropFrame() {
    _frame?.dispose();
    _frame = null;
    _stageBounds = const [];
  }
```

- [ ] **Step 2: Decode on open, drop on close**

In `_onTap`, replace:

```dart
      case CaptureNeedsReview(:final draft):
        await _openPanel(draft, controller);
```

with:

```dart
      case CaptureNeedsReview review:
        await _openPanel(review, controller);
```

Replace `_openPanel`:

```dart
  Future<void> _openPanel(CaptureNeedsReview review, CaptureController controller) async {
    // Decoded while the busy bubble still shows; null leaves the panel without strips.
    final frame = await decodeFrame(review.framePath);
    if (!mounted) {
      frame?.dispose();
      return;
    }
    await _blank();
    await FlutterOverlayWindow.resizeOverlay(
      OverlaySizes.resizeUnits(OverlaySizes.panelWidthDp),
      OverlaySizes.resizeUnits(OverlaySizes.panelHeightDp),
      true,
    );
    await FlutterOverlayWindow.updateFlag(OverlayFlag.focusPointer);
    if (!mounted) {
      frame?.dispose();
      return;
    }
    setState(() {
      _draft = review.draft;
      _draftController = controller;
      _frame = frame;
      _stageBounds = review.stageBounds;
      _mode = _Mode.panel;
    });
  }
```

Replace `_closePanel`:

```dart
  Future<void> _closePanel() async {
    if (mounted) await _blank();
    await _resetWindow();
    if (!mounted) return;
    setState(() {
      _draft = null;
      _draftController = null;
      _mode = _Mode.bubble;
    });
    _dropFrame();
  }
```

In `_start`, replace the `setState` that clears the draft:

```dart
      setState(() {
        _draft = null;
        _draftController = null;
        _mode = _Mode.starting;
      });
      _dropFrame();
```

In `dispose`, add `_dropFrame();` before `super.dispose();`.

- [ ] **Step 3: Hand the strips to the form**

In `build`, replace the panel's `child: RunForm(...)` with:

```dart
            child: RunForm(
              initial: _draft!,
              onSave: _save,
              onCancel: _closePanel,
              foldPassing: true,
              stagePreviews: _frame == null
                  ? null
                  : [
                      for (var i = 0; i < _stageBounds.length; i++)
                        CaptureStrip(
                          image: _frame!,
                          rect: _stageBounds[i],
                          collapsed: _draft!.stages[i].isValid,
                        ),
                    ],
            ),
```

- [ ] **Step 4: Analyze and test**

Run: `flutter analyze && flutter test`
Expected: no issues; all tests pass.

- [ ] **Step 5: Add checklist rows**

Append to `docs/manual-test-checklist.md`:

```markdown
| 29 | Capture strip | Open the edit panel from `concapt-row9.png` | Stage 1 opens with a strip of its own numbers from the capture above its fields; stages 2 and 3 are folded to their bands |
| 30 | Strip toggle | Tap stage 1's strip, then "Show capture" | The strip folds to a one-line row and comes back |
| 31 | Stage fold | Tap stage 2's band, then tap it again | Stage 2 unfolds with its fields and a folded "Show capture" row, then folds again |
```

- [ ] **Step 6: Install and check on the phone**

Ask the user to connect the phone and confirm with `adb devices`. Then:

```bash
flutter build apk --release
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Ask the user to start capturing, open `/sdcard/Pictures/concapt-row9.png` full-screen in Gallery, and tap the bubble. With the panel open, take a screenshot into the session's scratchpad directory (`adb exec-out screencap -p > panel.png` run there) and check rows 29–31, then have the user retest checklist rows 9, 10, 20, and 26.

- [ ] **Step 7: Commit**

```bash
git add lib/overlay/overlay_app.dart docs/manual-test-checklist.md
git commit -m "feat: show capture strips in the edit panel" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
