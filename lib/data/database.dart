import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';

part 'database.g.dart';

class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
}

@TableIndex(name: 'runs_session_seq', columns: {#sessionId, #seq}, unique: true)
class Runs extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId => integer().references(Sessions, #id, onDelete: KeyAction.cascade)();

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
  factory AppDatabase.open() => AppDatabase(
    driftDatabase(
      name: 'concapt',
      native: const DriftNativeOptions(databaseDirectory: getApplicationSupportDirectory),
    ),
  );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) async {
      if (from < 2) await m.createIndex(runsSessionSeq);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA busy_timeout = 5000');
      await customStatement('PRAGMA journal_mode = WAL');
    },
  );
}
