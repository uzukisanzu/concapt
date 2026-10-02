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
  void Function()? onRead;

  @override
  Future<List<TextPiece>> read(String imagePath) async {
    onRead?.call();
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
    reader.onRead = () => events.add('read');
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
    expect(events, ['hide', 'show', 'read']);
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
    final review = outcome as CaptureNeedsReview;
    expect(review.draft.invalidStages, {2});
    expect(review.framePath, '/tmp/capture.png');
    expect(review.stageBounds, hasLength(3));
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
