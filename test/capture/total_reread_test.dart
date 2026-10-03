import 'package:concapt/capture/text_reader.dart';
import 'package:concapt/capture/total_reread.dart';
import 'package:concapt/core/pixel_rect.dart';
import 'package:concapt/core/result_parser.dart';
import 'package:concapt/core/text_piece.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/sample.dart';
import '../helpers/screen.dart';

class FakeRegionReader implements RegionReader {
  FakeRegionReader(this.answer, {this.delay = Duration.zero});

  /// What OCR reads in [region] at [scale]; throws to fail the read.
  final String Function(PixelRect region, double scale) answer;
  final Duration delay;
  final regions = <PixelRect>[];

  @override
  Future<List<TextPiece>> readRegion(String imagePath, PixelRect region, double scale) async {
    regions.add(region);
    await Future<void>.delayed(delay);
    final text = answer(region, scale);
    return text.isEmpty
        ? const []
        : [TextPiece(text, region.left, region.top, region.right, region.bottom)];
  }
}

ParsedRun parse(Iterable<TextPiece> pieces) => ResultParser.parse(pieces.toList()) as ParsedRun;

ParsedRun withoutStage3Total() =>
    parse(screenPieces(referenceScores()).where((p) => p.text != '181,221Pt'));

void main() {
  test('fills a dropped total that reads once Pt is cut off', () async {
    final run = withoutStage3Total();
    final line = run.totalLines[2];
    // Like Windows OCR on 204,444Pt: nothing while Pt is in the crop.
    final reader = FakeRegionReader(
      (region, scale) => region.right < line.right - 30 && scale == 2 ? '181,221' : '',
    );

    final draft = await rereadTotals(reader, 'frame.png', run);

    expect(draft.invalidStages, isEmpty);
    expect(draft.stages[2].total, 181221);
    expect(reader.regions.every((r) => r.top == line.top && r.bottom == line.bottom), isTrue);
  });

  test('replaces a misread total the crop reads correctly', () async {
    final run = parse([
      for (final p in screenPieces(referenceScores()))
        p.text == '181,221Pt' ? TextPiece('386Pt', p.left, p.top, p.right, p.bottom) : p,
    ]);
    final reader = FakeRegionReader((region, scale) => '181,221Pt');

    final draft = await rereadTotals(reader, 'frame.png', run);

    expect(draft.stages[2].total, 181221);
  });

  test('keeps a total no crop confirms', () async {
    final run = withoutStage3Total();
    final reader = FakeRegionReader((region, scale) => '181,222');

    final draft = await rereadTotals(reader, 'frame.png', run);

    expect(draft.stages[2].total, isNull);
    expect(draft.invalidStages, {2});
  });

  test('skips stages missing a member and stages that add up', () async {
    final y = stageTops[2];
    final run = parse(
      screenPieces(referenceScores()).where((p) => !(p.left == 280 && p.top == y + 38)),
    );
    final reader = FakeRegionReader((region, scale) => '181,221');

    await rereadTotals(reader, 'frame.png', run);

    expect(reader.regions, isEmpty);
  });

  test('stops at the deadline and keeps the totals it confirmed', () async {
    // Stage 2 misread, stage 3 dropped.
    final run = parse([
      for (final p in screenPieces(referenceScores()))
        if (p.text == '206,163Pt')
          TextPiece('206,168Pt', p.left, p.top, p.right, p.bottom)
        else if (p.text != '181,221Pt')
          p,
    ]);
    final stage2 = run.totalLines[1];
    final reader = FakeRegionReader(
      (region, scale) => region.top == stage2.top ? '206,163' : '',
      delay: const Duration(milliseconds: 40),
    );

    final draft = await rereadTotals(
      reader,
      'frame.png',
      run,
      deadline: DateTime.now().add(const Duration(milliseconds: 150)),
    );

    expect(draft.stages[1].total, 206163);
    expect(draft.stages[2].total, isNull);
    expect(reader.regions.length, lessThan(6));
  });

  test('a failed read counts as no reading', () async {
    final run = withoutStage3Total();
    var reads = 0;
    final reader = FakeRegionReader((region, scale) {
      if (reads++ == 0) throw Exception('locked');
      return '181,221';
    });

    final draft = await rereadTotals(reader, 'frame.png', run);

    expect(draft.stages[2].total, 181221);
  });
}
