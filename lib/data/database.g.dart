// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $SessionsTable extends Sessions with TableInfo<$SessionsTable, Session> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<Session> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Session map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Session(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $SessionsTable createAlias(String alias) {
    return $SessionsTable(attachedDatabase, alias);
  }
}

class Session extends DataClass implements Insertable<Session> {
  final int id;
  final String name;
  final DateTime createdAt;
  const Session({
    required this.id,
    required this.name,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SessionsCompanion toCompanion(bool nullToAbsent) {
    return SessionsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory Session.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Session(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Session copyWith({int? id, String? name, DateTime? createdAt}) => Session(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
  );
  Session copyWithCompanion(SessionsCompanion data) {
    return Session(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Session(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Session &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class SessionsCompanion extends UpdateCompanion<Session> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const SessionsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SessionsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
  }) : name = Value(name),
       createdAt = Value(createdAt);
  static Insertable<Session> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<DateTime>? createdAt,
  }) {
    return SessionsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RunsTable extends Runs with TableInfo<$RunsTable, Run> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _sessionIdMeta = const VerificationMeta(
    'sessionId',
  );
  @override
  late final GeneratedColumn<int> sessionId = GeneratedColumn<int>(
    'session_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES sessions (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _seqMeta = const VerificationMeta('seq');
  @override
  late final GeneratedColumn<int> seq = GeneratedColumn<int>(
    'seq',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<DateTime> capturedAt = GeneratedColumn<DateTime>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _editedMeta = const VerificationMeta('edited');
  @override
  late final GeneratedColumn<bool> edited = GeneratedColumn<bool>(
    'edited',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("edited" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sessionId,
    seq,
    capturedAt,
    edited,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<Run> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('session_id')) {
      context.handle(
        _sessionIdMeta,
        sessionId.isAcceptableOrUnknown(data['session_id']!, _sessionIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sessionIdMeta);
    }
    if (data.containsKey('seq')) {
      context.handle(
        _seqMeta,
        seq.isAcceptableOrUnknown(data['seq']!, _seqMeta),
      );
    } else if (isInserting) {
      context.missing(_seqMeta);
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('edited')) {
      context.handle(
        _editedMeta,
        edited.isAcceptableOrUnknown(data['edited']!, _editedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Run map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Run(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      sessionId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}session_id'],
      )!,
      seq: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}seq'],
      )!,
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}captured_at'],
      )!,
      edited: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}edited'],
      )!,
    );
  }

  @override
  $RunsTable createAlias(String alias) {
    return $RunsTable(attachedDatabase, alias);
  }
}

class Run extends DataClass implements Insertable<Run> {
  final int id;
  final int sessionId;

  /// Run number within the session, assigned on insert.
  final int seq;
  final DateTime capturedAt;
  final bool edited;
  const Run({
    required this.id,
    required this.sessionId,
    required this.seq,
    required this.capturedAt,
    required this.edited,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['session_id'] = Variable<int>(sessionId);
    map['seq'] = Variable<int>(seq);
    map['captured_at'] = Variable<DateTime>(capturedAt);
    map['edited'] = Variable<bool>(edited);
    return map;
  }

  RunsCompanion toCompanion(bool nullToAbsent) {
    return RunsCompanion(
      id: Value(id),
      sessionId: Value(sessionId),
      seq: Value(seq),
      capturedAt: Value(capturedAt),
      edited: Value(edited),
    );
  }

  factory Run.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Run(
      id: serializer.fromJson<int>(json['id']),
      sessionId: serializer.fromJson<int>(json['sessionId']),
      seq: serializer.fromJson<int>(json['seq']),
      capturedAt: serializer.fromJson<DateTime>(json['capturedAt']),
      edited: serializer.fromJson<bool>(json['edited']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'sessionId': serializer.toJson<int>(sessionId),
      'seq': serializer.toJson<int>(seq),
      'capturedAt': serializer.toJson<DateTime>(capturedAt),
      'edited': serializer.toJson<bool>(edited),
    };
  }

  Run copyWith({
    int? id,
    int? sessionId,
    int? seq,
    DateTime? capturedAt,
    bool? edited,
  }) => Run(
    id: id ?? this.id,
    sessionId: sessionId ?? this.sessionId,
    seq: seq ?? this.seq,
    capturedAt: capturedAt ?? this.capturedAt,
    edited: edited ?? this.edited,
  );
  Run copyWithCompanion(RunsCompanion data) {
    return Run(
      id: data.id.present ? data.id.value : this.id,
      sessionId: data.sessionId.present ? data.sessionId.value : this.sessionId,
      seq: data.seq.present ? data.seq.value : this.seq,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      edited: data.edited.present ? data.edited.value : this.edited,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Run(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('seq: $seq, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('edited: $edited')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sessionId, seq, capturedAt, edited);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Run &&
          other.id == this.id &&
          other.sessionId == this.sessionId &&
          other.seq == this.seq &&
          other.capturedAt == this.capturedAt &&
          other.edited == this.edited);
}

class RunsCompanion extends UpdateCompanion<Run> {
  final Value<int> id;
  final Value<int> sessionId;
  final Value<int> seq;
  final Value<DateTime> capturedAt;
  final Value<bool> edited;
  const RunsCompanion({
    this.id = const Value.absent(),
    this.sessionId = const Value.absent(),
    this.seq = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.edited = const Value.absent(),
  });
  RunsCompanion.insert({
    this.id = const Value.absent(),
    required int sessionId,
    required int seq,
    required DateTime capturedAt,
    this.edited = const Value.absent(),
  }) : sessionId = Value(sessionId),
       seq = Value(seq),
       capturedAt = Value(capturedAt);
  static Insertable<Run> custom({
    Expression<int>? id,
    Expression<int>? sessionId,
    Expression<int>? seq,
    Expression<DateTime>? capturedAt,
    Expression<bool>? edited,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sessionId != null) 'session_id': sessionId,
      if (seq != null) 'seq': seq,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (edited != null) 'edited': edited,
    });
  }

  RunsCompanion copyWith({
    Value<int>? id,
    Value<int>? sessionId,
    Value<int>? seq,
    Value<DateTime>? capturedAt,
    Value<bool>? edited,
  }) {
    return RunsCompanion(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      seq: seq ?? this.seq,
      capturedAt: capturedAt ?? this.capturedAt,
      edited: edited ?? this.edited,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (sessionId.present) {
      map['session_id'] = Variable<int>(sessionId.value);
    }
    if (seq.present) {
      map['seq'] = Variable<int>(seq.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<DateTime>(capturedAt.value);
    }
    if (edited.present) {
      map['edited'] = Variable<bool>(edited.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RunsCompanion(')
          ..write('id: $id, ')
          ..write('sessionId: $sessionId, ')
          ..write('seq: $seq, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('edited: $edited')
          ..write(')'))
        .toString();
  }
}

class $StageResultsTable extends StageResults
    with TableInfo<$StageResultsTable, StageResult> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StageResultsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _runIdMeta = const VerificationMeta('runId');
  @override
  late final GeneratedColumn<int> runId = GeneratedColumn<int>(
    'run_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<int> stage = GeneratedColumn<int>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _leftScoreMeta = const VerificationMeta(
    'leftScore',
  );
  @override
  late final GeneratedColumn<int> leftScore = GeneratedColumn<int>(
    'left_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _middleScoreMeta = const VerificationMeta(
    'middleScore',
  );
  @override
  late final GeneratedColumn<int> middleScore = GeneratedColumn<int>(
    'middle_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rightScoreMeta = const VerificationMeta(
    'rightScore',
  );
  @override
  late final GeneratedColumn<int> rightScore = GeneratedColumn<int>(
    'right_score',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bonusMeta = const VerificationMeta('bonus');
  @override
  late final GeneratedColumn<int> bonus = GeneratedColumn<int>(
    'bonus',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalMeta = const VerificationMeta('total');
  @override
  late final GeneratedColumn<int> total = GeneratedColumn<int>(
    'total',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    runId,
    stage,
    leftScore,
    middleScore,
    rightScore,
    bonus,
    total,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stage_results';
  @override
  VerificationContext validateIntegrity(
    Insertable<StageResult> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('run_id')) {
      context.handle(
        _runIdMeta,
        runId.isAcceptableOrUnknown(data['run_id']!, _runIdMeta),
      );
    } else if (isInserting) {
      context.missing(_runIdMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('left_score')) {
      context.handle(
        _leftScoreMeta,
        leftScore.isAcceptableOrUnknown(data['left_score']!, _leftScoreMeta),
      );
    } else if (isInserting) {
      context.missing(_leftScoreMeta);
    }
    if (data.containsKey('middle_score')) {
      context.handle(
        _middleScoreMeta,
        middleScore.isAcceptableOrUnknown(
          data['middle_score']!,
          _middleScoreMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_middleScoreMeta);
    }
    if (data.containsKey('right_score')) {
      context.handle(
        _rightScoreMeta,
        rightScore.isAcceptableOrUnknown(data['right_score']!, _rightScoreMeta),
      );
    } else if (isInserting) {
      context.missing(_rightScoreMeta);
    }
    if (data.containsKey('bonus')) {
      context.handle(
        _bonusMeta,
        bonus.isAcceptableOrUnknown(data['bonus']!, _bonusMeta),
      );
    } else if (isInserting) {
      context.missing(_bonusMeta);
    }
    if (data.containsKey('total')) {
      context.handle(
        _totalMeta,
        total.isAcceptableOrUnknown(data['total']!, _totalMeta),
      );
    } else if (isInserting) {
      context.missing(_totalMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {runId, stage};
  @override
  StageResult map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StageResult(
      runId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}run_id'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stage'],
      )!,
      leftScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}left_score'],
      )!,
      middleScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}middle_score'],
      )!,
      rightScore: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}right_score'],
      )!,
      bonus: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bonus'],
      )!,
      total: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total'],
      )!,
    );
  }

  @override
  $StageResultsTable createAlias(String alias) {
    return $StageResultsTable(attachedDatabase, alias);
  }
}

class StageResult extends DataClass implements Insertable<StageResult> {
  final int runId;

  /// 1–3.
  final int stage;
  final int leftScore;
  final int middleScore;
  final int rightScore;
  final int bonus;
  final int total;
  const StageResult({
    required this.runId,
    required this.stage,
    required this.leftScore,
    required this.middleScore,
    required this.rightScore,
    required this.bonus,
    required this.total,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['run_id'] = Variable<int>(runId);
    map['stage'] = Variable<int>(stage);
    map['left_score'] = Variable<int>(leftScore);
    map['middle_score'] = Variable<int>(middleScore);
    map['right_score'] = Variable<int>(rightScore);
    map['bonus'] = Variable<int>(bonus);
    map['total'] = Variable<int>(total);
    return map;
  }

  StageResultsCompanion toCompanion(bool nullToAbsent) {
    return StageResultsCompanion(
      runId: Value(runId),
      stage: Value(stage),
      leftScore: Value(leftScore),
      middleScore: Value(middleScore),
      rightScore: Value(rightScore),
      bonus: Value(bonus),
      total: Value(total),
    );
  }

  factory StageResult.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StageResult(
      runId: serializer.fromJson<int>(json['runId']),
      stage: serializer.fromJson<int>(json['stage']),
      leftScore: serializer.fromJson<int>(json['leftScore']),
      middleScore: serializer.fromJson<int>(json['middleScore']),
      rightScore: serializer.fromJson<int>(json['rightScore']),
      bonus: serializer.fromJson<int>(json['bonus']),
      total: serializer.fromJson<int>(json['total']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'runId': serializer.toJson<int>(runId),
      'stage': serializer.toJson<int>(stage),
      'leftScore': serializer.toJson<int>(leftScore),
      'middleScore': serializer.toJson<int>(middleScore),
      'rightScore': serializer.toJson<int>(rightScore),
      'bonus': serializer.toJson<int>(bonus),
      'total': serializer.toJson<int>(total),
    };
  }

  StageResult copyWith({
    int? runId,
    int? stage,
    int? leftScore,
    int? middleScore,
    int? rightScore,
    int? bonus,
    int? total,
  }) => StageResult(
    runId: runId ?? this.runId,
    stage: stage ?? this.stage,
    leftScore: leftScore ?? this.leftScore,
    middleScore: middleScore ?? this.middleScore,
    rightScore: rightScore ?? this.rightScore,
    bonus: bonus ?? this.bonus,
    total: total ?? this.total,
  );
  StageResult copyWithCompanion(StageResultsCompanion data) {
    return StageResult(
      runId: data.runId.present ? data.runId.value : this.runId,
      stage: data.stage.present ? data.stage.value : this.stage,
      leftScore: data.leftScore.present ? data.leftScore.value : this.leftScore,
      middleScore: data.middleScore.present
          ? data.middleScore.value
          : this.middleScore,
      rightScore: data.rightScore.present
          ? data.rightScore.value
          : this.rightScore,
      bonus: data.bonus.present ? data.bonus.value : this.bonus,
      total: data.total.present ? data.total.value : this.total,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StageResult(')
          ..write('runId: $runId, ')
          ..write('stage: $stage, ')
          ..write('leftScore: $leftScore, ')
          ..write('middleScore: $middleScore, ')
          ..write('rightScore: $rightScore, ')
          ..write('bonus: $bonus, ')
          ..write('total: $total')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    runId,
    stage,
    leftScore,
    middleScore,
    rightScore,
    bonus,
    total,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StageResult &&
          other.runId == this.runId &&
          other.stage == this.stage &&
          other.leftScore == this.leftScore &&
          other.middleScore == this.middleScore &&
          other.rightScore == this.rightScore &&
          other.bonus == this.bonus &&
          other.total == this.total);
}

class StageResultsCompanion extends UpdateCompanion<StageResult> {
  final Value<int> runId;
  final Value<int> stage;
  final Value<int> leftScore;
  final Value<int> middleScore;
  final Value<int> rightScore;
  final Value<int> bonus;
  final Value<int> total;
  final Value<int> rowid;
  const StageResultsCompanion({
    this.runId = const Value.absent(),
    this.stage = const Value.absent(),
    this.leftScore = const Value.absent(),
    this.middleScore = const Value.absent(),
    this.rightScore = const Value.absent(),
    this.bonus = const Value.absent(),
    this.total = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StageResultsCompanion.insert({
    required int runId,
    required int stage,
    required int leftScore,
    required int middleScore,
    required int rightScore,
    required int bonus,
    required int total,
    this.rowid = const Value.absent(),
  }) : runId = Value(runId),
       stage = Value(stage),
       leftScore = Value(leftScore),
       middleScore = Value(middleScore),
       rightScore = Value(rightScore),
       bonus = Value(bonus),
       total = Value(total);
  static Insertable<StageResult> custom({
    Expression<int>? runId,
    Expression<int>? stage,
    Expression<int>? leftScore,
    Expression<int>? middleScore,
    Expression<int>? rightScore,
    Expression<int>? bonus,
    Expression<int>? total,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (runId != null) 'run_id': runId,
      if (stage != null) 'stage': stage,
      if (leftScore != null) 'left_score': leftScore,
      if (middleScore != null) 'middle_score': middleScore,
      if (rightScore != null) 'right_score': rightScore,
      if (bonus != null) 'bonus': bonus,
      if (total != null) 'total': total,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StageResultsCompanion copyWith({
    Value<int>? runId,
    Value<int>? stage,
    Value<int>? leftScore,
    Value<int>? middleScore,
    Value<int>? rightScore,
    Value<int>? bonus,
    Value<int>? total,
    Value<int>? rowid,
  }) {
    return StageResultsCompanion(
      runId: runId ?? this.runId,
      stage: stage ?? this.stage,
      leftScore: leftScore ?? this.leftScore,
      middleScore: middleScore ?? this.middleScore,
      rightScore: rightScore ?? this.rightScore,
      bonus: bonus ?? this.bonus,
      total: total ?? this.total,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (runId.present) {
      map['run_id'] = Variable<int>(runId.value);
    }
    if (stage.present) {
      map['stage'] = Variable<int>(stage.value);
    }
    if (leftScore.present) {
      map['left_score'] = Variable<int>(leftScore.value);
    }
    if (middleScore.present) {
      map['middle_score'] = Variable<int>(middleScore.value);
    }
    if (rightScore.present) {
      map['right_score'] = Variable<int>(rightScore.value);
    }
    if (bonus.present) {
      map['bonus'] = Variable<int>(bonus.value);
    }
    if (total.present) {
      map['total'] = Variable<int>(total.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StageResultsCompanion(')
          ..write('runId: $runId, ')
          ..write('stage: $stage, ')
          ..write('leftScore: $leftScore, ')
          ..write('middleScore: $middleScore, ')
          ..write('rightScore: $rightScore, ')
          ..write('bonus: $bonus, ')
          ..write('total: $total, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $SessionsTable sessions = $SessionsTable(this);
  late final $RunsTable runs = $RunsTable(this);
  late final $StageResultsTable stageResults = $StageResultsTable(this);
  late final Index runsSessionSeq = Index(
    'runs_session_seq',
    'CREATE UNIQUE INDEX runs_session_seq ON runs (session_id, seq)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    sessions,
    runs,
    stageResults,
    runsSessionSeq,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'sessions',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('runs', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('stage_results', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$SessionsTableCreateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      required String name,
      required DateTime createdAt,
    });
typedef $$SessionsTableUpdateCompanionBuilder =
    SessionsCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<DateTime> createdAt,
    });

final class $$SessionsTableReferences
    extends BaseReferences<_$AppDatabase, $SessionsTable, Session> {
  $$SessionsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RunsTable, List<Run>> _runsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.runs,
    aliasName: 'sessions__id__runs__session_id',
  );

  $$RunsTableProcessedTableManager get runsRefs {
    final manager = $$RunsTableTableManager(
      $_db,
      $_db.runs,
    ).filter((f) => f.sessionId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_runsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> runsRefs(
    Expression<bool> Function($$RunsTableFilterComposer f) f,
  ) {
    final $$RunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableFilterComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionsTable> {
  $$SessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> runsRefs<T extends Object>(
    Expression<T> Function($$RunsTableAnnotationComposer a) f,
  ) {
    final $$RunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.sessionId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableAnnotationComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionsTable,
          Session,
          $$SessionsTableFilterComposer,
          $$SessionsTableOrderingComposer,
          $$SessionsTableAnnotationComposer,
          $$SessionsTableCreateCompanionBuilder,
          $$SessionsTableUpdateCompanionBuilder,
          (Session, $$SessionsTableReferences),
          Session,
          PrefetchHooks Function({bool runsRefs})
        > {
  $$SessionsTableTableManager(_$AppDatabase db, $SessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => SessionsCompanion(id: id, name: name, createdAt: createdAt),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required DateTime createdAt,
              }) => SessionsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$SessionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (runsRefs) db.runs],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (runsRefs)
                    await $_getPrefetchedData<Session, $SessionsTable, Run>(
                      currentTable: table,
                      referencedTable: $$SessionsTableReferences._runsRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$SessionsTableReferences(db, table, p0).runsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.sessionId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionsTable,
      Session,
      $$SessionsTableFilterComposer,
      $$SessionsTableOrderingComposer,
      $$SessionsTableAnnotationComposer,
      $$SessionsTableCreateCompanionBuilder,
      $$SessionsTableUpdateCompanionBuilder,
      (Session, $$SessionsTableReferences),
      Session,
      PrefetchHooks Function({bool runsRefs})
    >;
typedef $$RunsTableCreateCompanionBuilder =
    RunsCompanion Function({
      Value<int> id,
      required int sessionId,
      required int seq,
      required DateTime capturedAt,
      Value<bool> edited,
    });
typedef $$RunsTableUpdateCompanionBuilder =
    RunsCompanion Function({
      Value<int> id,
      Value<int> sessionId,
      Value<int> seq,
      Value<DateTime> capturedAt,
      Value<bool> edited,
    });

final class $$RunsTableReferences
    extends BaseReferences<_$AppDatabase, $RunsTable, Run> {
  $$RunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $SessionsTable _sessionIdTable(_$AppDatabase db) =>
      db.sessions.createAlias('runs__session_id__sessions__id');

  $$SessionsTableProcessedTableManager get sessionId {
    final $_column = $_itemColumn<int>('session_id')!;

    final manager = $$SessionsTableTableManager(
      $_db,
      $_db.sessions,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_sessionIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$StageResultsTable, List<StageResult>>
  _stageResultsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.stageResults,
    aliasName: 'runs__id__stage_results__run_id',
  );

  $$StageResultsTableProcessedTableManager get stageResultsRefs {
    final manager = $$StageResultsTableTableManager(
      $_db,
      $_db.stageResults,
    ).filter((f) => f.runId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_stageResultsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RunsTableFilterComposer extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionsTableFilterComposer get sessionId {
    final $$SessionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableFilterComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> stageResultsRefs(
    Expression<bool> Function($$StageResultsTableFilterComposer f) f,
  ) {
    final $$StageResultsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stageResults,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StageResultsTableFilterComposer(
            $db: $db,
            $table: $db.stageResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RunsTableOrderingComposer extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seq => $composableBuilder(
    column: $table.seq,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get edited => $composableBuilder(
    column: $table.edited,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionsTableOrderingComposer get sessionId {
    final $$SessionsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableOrderingComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RunsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RunsTable> {
  $$RunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get seq =>
      $composableBuilder(column: $table.seq, builder: (column) => column);

  GeneratedColumn<DateTime> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get edited =>
      $composableBuilder(column: $table.edited, builder: (column) => column);

  $$SessionsTableAnnotationComposer get sessionId {
    final $$SessionsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.sessionId,
      referencedTable: $db.sessions,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionsTableAnnotationComposer(
            $db: $db,
            $table: $db.sessions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> stageResultsRefs<T extends Object>(
    Expression<T> Function($$StageResultsTableAnnotationComposer a) f,
  ) {
    final $$StageResultsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.stageResults,
      getReferencedColumn: (t) => t.runId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StageResultsTableAnnotationComposer(
            $db: $db,
            $table: $db.stageResults,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RunsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RunsTable,
          Run,
          $$RunsTableFilterComposer,
          $$RunsTableOrderingComposer,
          $$RunsTableAnnotationComposer,
          $$RunsTableCreateCompanionBuilder,
          $$RunsTableUpdateCompanionBuilder,
          (Run, $$RunsTableReferences),
          Run,
          PrefetchHooks Function({bool sessionId, bool stageResultsRefs})
        > {
  $$RunsTableTableManager(_$AppDatabase db, $RunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> sessionId = const Value.absent(),
                Value<int> seq = const Value.absent(),
                Value<DateTime> capturedAt = const Value.absent(),
                Value<bool> edited = const Value.absent(),
              }) => RunsCompanion(
                id: id,
                sessionId: sessionId,
                seq: seq,
                capturedAt: capturedAt,
                edited: edited,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int sessionId,
                required int seq,
                required DateTime capturedAt,
                Value<bool> edited = const Value.absent(),
              }) => RunsCompanion.insert(
                id: id,
                sessionId: sessionId,
                seq: seq,
                capturedAt: capturedAt,
                edited: edited,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$RunsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({sessionId = false, stageResultsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (stageResultsRefs) db.stageResults,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (sessionId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.sessionId,
                                    referencedTable: $$RunsTableReferences
                                        ._sessionIdTable(db),
                                    referencedColumn: $$RunsTableReferences
                                        ._sessionIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (stageResultsRefs)
                        await $_getPrefetchedData<Run, $RunsTable, StageResult>(
                          currentTable: table,
                          referencedTable: $$RunsTableReferences
                              ._stageResultsRefsTable(db),
                          managerFromTypedResult: (p0) => $$RunsTableReferences(
                            db,
                            table,
                            p0,
                          ).stageResultsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.runId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RunsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RunsTable,
      Run,
      $$RunsTableFilterComposer,
      $$RunsTableOrderingComposer,
      $$RunsTableAnnotationComposer,
      $$RunsTableCreateCompanionBuilder,
      $$RunsTableUpdateCompanionBuilder,
      (Run, $$RunsTableReferences),
      Run,
      PrefetchHooks Function({bool sessionId, bool stageResultsRefs})
    >;
typedef $$StageResultsTableCreateCompanionBuilder =
    StageResultsCompanion Function({
      required int runId,
      required int stage,
      required int leftScore,
      required int middleScore,
      required int rightScore,
      required int bonus,
      required int total,
      Value<int> rowid,
    });
typedef $$StageResultsTableUpdateCompanionBuilder =
    StageResultsCompanion Function({
      Value<int> runId,
      Value<int> stage,
      Value<int> leftScore,
      Value<int> middleScore,
      Value<int> rightScore,
      Value<int> bonus,
      Value<int> total,
      Value<int> rowid,
    });

final class $$StageResultsTableReferences
    extends BaseReferences<_$AppDatabase, $StageResultsTable, StageResult> {
  $$StageResultsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RunsTable _runIdTable(_$AppDatabase db) =>
      db.runs.createAlias('stage_results__run_id__runs__id');

  $$RunsTableProcessedTableManager get runId {
    final $_column = $_itemColumn<int>('run_id')!;

    final manager = $$RunsTableTableManager(
      $_db,
      $_db.runs,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_runIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$StageResultsTableFilterComposer
    extends Composer<_$AppDatabase, $StageResultsTable> {
  $$StageResultsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get leftScore => $composableBuilder(
    column: $table.leftScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get middleScore => $composableBuilder(
    column: $table.middleScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rightScore => $composableBuilder(
    column: $table.rightScore,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bonus => $composableBuilder(
    column: $table.bonus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnFilters(column),
  );

  $$RunsTableFilterComposer get runId {
    final $$RunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableFilterComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StageResultsTableOrderingComposer
    extends Composer<_$AppDatabase, $StageResultsTable> {
  $$StageResultsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get leftScore => $composableBuilder(
    column: $table.leftScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get middleScore => $composableBuilder(
    column: $table.middleScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rightScore => $composableBuilder(
    column: $table.rightScore,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bonus => $composableBuilder(
    column: $table.bonus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get total => $composableBuilder(
    column: $table.total,
    builder: (column) => ColumnOrderings(column),
  );

  $$RunsTableOrderingComposer get runId {
    final $$RunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableOrderingComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StageResultsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StageResultsTable> {
  $$StageResultsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<int> get leftScore =>
      $composableBuilder(column: $table.leftScore, builder: (column) => column);

  GeneratedColumn<int> get middleScore => $composableBuilder(
    column: $table.middleScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rightScore => $composableBuilder(
    column: $table.rightScore,
    builder: (column) => column,
  );

  GeneratedColumn<int> get bonus =>
      $composableBuilder(column: $table.bonus, builder: (column) => column);

  GeneratedColumn<int> get total =>
      $composableBuilder(column: $table.total, builder: (column) => column);

  $$RunsTableAnnotationComposer get runId {
    final $$RunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.runId,
      referencedTable: $db.runs,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RunsTableAnnotationComposer(
            $db: $db,
            $table: $db.runs,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$StageResultsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StageResultsTable,
          StageResult,
          $$StageResultsTableFilterComposer,
          $$StageResultsTableOrderingComposer,
          $$StageResultsTableAnnotationComposer,
          $$StageResultsTableCreateCompanionBuilder,
          $$StageResultsTableUpdateCompanionBuilder,
          (StageResult, $$StageResultsTableReferences),
          StageResult,
          PrefetchHooks Function({bool runId})
        > {
  $$StageResultsTableTableManager(_$AppDatabase db, $StageResultsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StageResultsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StageResultsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StageResultsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> runId = const Value.absent(),
                Value<int> stage = const Value.absent(),
                Value<int> leftScore = const Value.absent(),
                Value<int> middleScore = const Value.absent(),
                Value<int> rightScore = const Value.absent(),
                Value<int> bonus = const Value.absent(),
                Value<int> total = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StageResultsCompanion(
                runId: runId,
                stage: stage,
                leftScore: leftScore,
                middleScore: middleScore,
                rightScore: rightScore,
                bonus: bonus,
                total: total,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required int runId,
                required int stage,
                required int leftScore,
                required int middleScore,
                required int rightScore,
                required int bonus,
                required int total,
                Value<int> rowid = const Value.absent(),
              }) => StageResultsCompanion.insert(
                runId: runId,
                stage: stage,
                leftScore: leftScore,
                middleScore: middleScore,
                rightScore: rightScore,
                bonus: bonus,
                total: total,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$StageResultsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({runId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (runId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.runId,
                                referencedTable: $$StageResultsTableReferences
                                    ._runIdTable(db),
                                referencedColumn: $$StageResultsTableReferences
                                    ._runIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$StageResultsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StageResultsTable,
      StageResult,
      $$StageResultsTableFilterComposer,
      $$StageResultsTableOrderingComposer,
      $$StageResultsTableAnnotationComposer,
      $$StageResultsTableCreateCompanionBuilder,
      $$StageResultsTableUpdateCompanionBuilder,
      (StageResult, $$StageResultsTableReferences),
      StageResult,
      PrefetchHooks Function({bool runId})
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$SessionsTableTableManager get sessions =>
      $$SessionsTableTableManager(_db, _db.sessions);
  $$RunsTableTableManager get runs => $$RunsTableTableManager(_db, _db.runs);
  $$StageResultsTableTableManager get stageResults =>
      $$StageResultsTableTableManager(_db, _db.stageResults);
}
