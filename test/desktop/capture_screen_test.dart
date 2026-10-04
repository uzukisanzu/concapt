import 'dart:async';
import 'dart:io';

import 'package:concapt/capture/window_target.dart';
import 'package:concapt/core/text_piece.dart';
import 'package:concapt/data/database.dart';
import 'package:concapt/data/repository.dart';
import 'package:concapt/desktop/capture_screen.dart';
import 'package:concapt/ui/run_form.dart';
import 'package:concapt/ui/session_detail_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../helpers/app.dart';
import '../helpers/sample.dart';
import '../helpers/screen.dart';

const _methods = MethodChannel('concapt/window_capture');
const _hotkey = EventChannel('concapt/window_capture/hotkey');

/// Stands in for the native plugin and records what the screen asks of it.
class FakePlugin {
  final calls = <String>[];

  /// The windows sent to `setHotkeyWindow`, in order.
  final hotkeyWindows = <int?>[];
  bool ocr = true;
  bool registers = true;
  String? captureError;
  Completer<void>? captureGate;
  List<TextPiece> pieces = screenPieces(referenceScores());
  MockStreamHandlerEventSink? presses;

  TestDefaultBinaryMessenger get _messenger =>
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  void install() {
    _messenger.setMockMethodCallHandler(_methods, (call) async {
      calls.add(call.method);
      switch (call.method) {
        case 'ocrAvailable':
          return ocr;
        case 'listWindows':
          return [
            {'handle': 7, 'title': 'gakumas', 'process': 'gakumas.exe', 'minimized': false},
          ];
        case 'registerHotkey':
          return registers;
        case 'setHotkeyWindow':
          hotkeyWindows.add((call.arguments as Map)['handle'] as int?);
        case 'captureWindow':
          await captureGate?.future;
          if (captureError != null) throw PlatformException(code: captureError!);
          return null;
        case 'recognize':
          // Region reads are the total re-read; none confirms here.
          if ((call.arguments as Map).containsKey('region')) return const [];
          return [for (final p in pieces) p.toJson()];
      }
      return null;
    });
    _messenger.setMockStreamHandler(
      _hotkey,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          presses = sink;
        },
      ),
    );
  }

  void uninstall() {
    _messenger.setMockMethodCallHandler(_methods, null);
    _messenger.setMockStreamHandler(_hotkey, null);
  }

  int count(String method) => calls.where((c) => c == method).length;
}

/// Lets real I/O (drift, files) finish, then rebuilds.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

/// Settles until [finder] matches; a failing capture runs the total re-read
/// first, which takes more turns than [settle] gives.
Future<void> settleUntil(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
    await settle(tester);
  }
}

void main() {
  late FakePlugin plugin;
  late AppDatabase db;
  late Repository repo;
  late int sessionId;

  setUp(() {
    SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty();
    plugin = FakePlugin()..install();
  });

  tearDown(() => plugin.uninstall());

  Future<void> openDatabase(WidgetTester tester) async {
    tester.view.physicalSize = const Size(840, 1720);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    db = AppDatabase(NativeDatabase.memory());
    addTearDown(() => tester.runAsync(db.close));
    repo = Repository(db);
    await tester.runAsync(() async => sessionId = await repo.createSession('Week 3'));
  }

  Future<void> open(WidgetTester tester, {bool remember = true}) async {
    await openDatabase(tester);
    if (remember) {
      await tester.runAsync(() => const RememberedWindow('gakumas.exe', 'gakumas').save());
    }
    await tester.pumpWidget(
      localizedApp(
        CaptureScreen(
          repository: repo,
          sessionId: sessionId,
          cacheDirectory: () async => Directory.systemTemp,
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> press(WidgetTester tester) async {
    plugin.presses!.success(null);
    await settle(tester);
  }

  Future<int> runCount(WidgetTester tester) async =>
      (await tester.runAsync(() => repo.runs(sessionId)))!.length;

  testWidgets('preselects the remembered window and binds F9', (tester) async {
    await open(tester);

    expect(find.text('gakumas — gakumas.exe'), findsOneWidget);
    expect(plugin.count('registerHotkey'), 1);
    expect(find.text('Press F9 on a result screen to capture.'), findsOneWidget);
  });

  testWidgets('a press on a passing screen saves the run without flashing', (tester) async {
    await open(tester);
    await press(tester);

    expect(await runCount(tester), 1);
    expect(find.textContaining('Run 1 saved'), findsOneWidget);
    expect(find.text('Runs (1)'), findsOneWidget);
    expect(plugin.count('flashWindow'), 0);
  });

  testWidgets('a failed sum opens the form, flashes, and blocks the next press', (tester) async {
    plugin.pieces = [
      for (final p in screenPieces(referenceScores()))
        p.text == '181,221Pt' ? TextPiece('181,222Pt', p.left, p.top, p.right, p.bottom) : p,
    ];
    await open(tester);
    await press(tester);
    await settleUntil(tester, find.byType(RunForm));

    expect(find.byType(RunForm), findsOneWidget);
    expect(plugin.count('flashWindow'), 1);
    expect(await runCount(tester), 0);

    await press(tester);
    expect(plugin.count('captureWindow'), 1);
    expect(find.text('Save or cancel the open run first.'), findsOneWidget);
  });

  testWidgets('Enter in the open form saves the run', (tester) async {
    plugin.pieces = [
      for (final p in screenPieces(referenceScores()))
        p.text == '181,221Pt' ? TextPiece('181,222Pt', p.left, p.top, p.right, p.bottom) : p,
    ];
    await open(tester);
    await press(tester);
    await settleUntil(tester, find.byType(RunForm));

    await tester.enterText(find.byKey(const Key('field-2-3')), '181221');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settle(tester);

    expect(await runCount(tester), 1);
    expect(find.byType(RunForm), findsNothing);
  });

  testWidgets('with no runs the runs band says so', (tester) async {
    await open(tester);
    expect(find.text('No runs yet'), findsOneWidget);
  });

  testWidgets('the last run shows its number', (tester) async {
    await open(tester);
    await tester.runAsync(() => repo.addRun(sessionId, scoresWithLeft(1), edited: false));
    await press(tester);
    expect(find.text('Run 2'), findsOneWidget);
    expect(find.text('Run 1'), findsNothing);
    expect(find.text('No runs yet'), findsNothing);
  });

  testWidgets('a failure reads in the error color', (tester) async {
    plugin.captureError = 'closed';
    await open(tester);
    await press(tester);

    final message = tester.widget<Text>(find.text('The captured window is gone. Pick a window.'));
    final context = tester.element(find.byType(CaptureScreen));
    expect(message.style?.color, Theme.of(context).colorScheme.error);
  });

  testWidgets('on a wide window the content keeps to a column', (tester) async {
    await open(tester);
    tester.view.physicalSize = const Size(2400, 1600);
    await tester.pump();
    expect(tester.getSize(find.byType(ListView)).width, lessThanOrEqualTo(560));
  });

  testWidgets('a closed window clears the selection', (tester) async {
    plugin.captureError = 'closed';
    await open(tester);
    await press(tester);

    expect(find.text('The captured window is gone. Pick a window.'), findsOneWidget);
    expect(find.text('gakumas — gakumas.exe'), findsNothing);
  });

  testWidgets('without a window a press asks for one', (tester) async {
    await open(tester, remember: false);
    await press(tester);

    expect(plugin.count('captureWindow'), 0);
    expect(find.text('Pick a window to capture.'), findsWidgets);
  });

  testWidgets('the hotkey follows the picked window', (tester) async {
    await open(tester);
    expect(plugin.hotkeyWindows.last, 7);

    plugin.captureError = 'closed';
    await press(tester);
    expect(plugin.hotkeyWindows.last, isNull);
  });

  testWidgets('a side-button click binds the side button', (tester) async {
    await openDatabase(tester);
    // Pushed over another route, so a stray pop would leave the screen.
    await tester.pumpWidget(localizedApp(const SizedBox()));
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator))
          .push(
            MaterialPageRoute<void>(
              builder: (_) => CaptureScreen(
                repository: repo,
                sessionId: sessionId,
                cacheDirectory: () async => Directory.systemTemp,
              ),
            ),
          ),
    );
    await tester.pumpAndSettle();
    await settle(tester);
    await tester.tap(find.text('Change'));
    await tester.pumpAndSettle();

    final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      buttons: kBackMouseButton,
    );
    // Outside the dialog box, on the barrier.
    await gesture.down(const Offset(4, 4));
    await gesture.up();
    await tester.pumpAndSettle();
    await settle(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(find.text('Press Mouse 4 on a result screen to capture.'), findsOneWidget);
  });

  testWidgets('a taken hotkey says so', (tester) async {
    plugin.registers = false;
    await open(tester);

    expect(find.text('F9 is in use by another app. Choose another key.'), findsOneWidget);
  });

  testWidgets('without OCR it explains and binds no hotkey', (tester) async {
    plugin.ocr = false;
    await open(tester);

    expect(find.textContaining('Windows has no English text recognition'), findsOneWidget);
    expect(plugin.count('registerHotkey'), 0);
  });

  testWidgets('rapid presses capture once', (tester) async {
    plugin.captureGate = Completer<void>();
    await open(tester);
    plugin.presses!.success(null);
    plugin.presses!.success(null);
    await settle(tester);
    plugin.captureGate!.complete();
    await settle(tester);

    expect(plugin.count('captureWindow'), 1);
    expect(await runCount(tester), 1);
  });

  testWidgets('leaving mid-capture releases the hotkey and still saves', (tester) async {
    plugin.captureGate = Completer<void>();
    await open(tester);
    plugin.presses!.success(null);
    await settle(tester);

    await tester.pumpWidget(const SizedBox());
    plugin.captureGate!.complete();
    await settle(tester);

    expect(plugin.count('unregisterHotkey'), 1);
    expect(await runCount(tester), 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Start capturing on Windows opens the capture screen', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    await openDatabase(tester);

    await tester.pumpWidget(
      localizedApp(
        SessionDetailScreen(
          repository: repo,
          sessionId: sessionId,
          capturingSession: () async => null,
        ),
      ),
    );
    await settle(tester);
    // Let the FAB finish scaling in before tapping it.
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.text('Start capturing'));
    await settle(tester);

    expect(find.byType(CaptureScreen), findsOneWidget);
    debugDefaultTargetPlatformOverride = null;
  });
}
