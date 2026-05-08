// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'spike_db.dart';

// ignore_for_file: type=lint
class $SpikePendingOpsTable extends SpikePendingOps
    with TableInfo<$SpikePendingOpsTable, SpikePendingOp> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SpikePendingOpsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _venueIdMeta = const VerificationMeta(
    'venueId',
  );
  @override
  late final GeneratedColumn<String> venueId = GeneratedColumn<String>(
    'venue_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _opTypeMeta = const VerificationMeta('opType');
  @override
  late final GeneratedColumn<String> opType = GeneratedColumn<String>(
    'op_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
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
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    venueId,
    opType,
    payload,
    createdAt,
    attempts,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'spike_pending_ops';
  @override
  VerificationContext validateIntegrity(
    Insertable<SpikePendingOp> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('venue_id')) {
      context.handle(
        _venueIdMeta,
        venueId.isAcceptableOrUnknown(data['venue_id']!, _venueIdMeta),
      );
    } else if (isInserting) {
      context.missing(_venueIdMeta);
    }
    if (data.containsKey('op_type')) {
      context.handle(
        _opTypeMeta,
        opType.isAcceptableOrUnknown(data['op_type']!, _opTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_opTypeMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SpikePendingOp map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SpikePendingOp(
      id:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}id'],
          )!,
      venueId:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}venue_id'],
          )!,
      opType:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}op_type'],
          )!,
      payload:
          attachedDatabase.typeMapping.read(
            DriftSqlType.string,
            data['${effectivePrefix}payload'],
          )!,
      createdAt:
          attachedDatabase.typeMapping.read(
            DriftSqlType.dateTime,
            data['${effectivePrefix}created_at'],
          )!,
      attempts:
          attachedDatabase.typeMapping.read(
            DriftSqlType.int,
            data['${effectivePrefix}attempts'],
          )!,
    );
  }

  @override
  $SpikePendingOpsTable createAlias(String alias) {
    return $SpikePendingOpsTable(attachedDatabase, alias);
  }
}

class SpikePendingOp extends DataClass implements Insertable<SpikePendingOp> {
  final int id;
  final String venueId;
  final String opType;
  final String payload;
  final DateTime createdAt;
  final int attempts;
  const SpikePendingOp({
    required this.id,
    required this.venueId,
    required this.opType,
    required this.payload,
    required this.createdAt,
    required this.attempts,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['venue_id'] = Variable<String>(venueId);
    map['op_type'] = Variable<String>(opType);
    map['payload'] = Variable<String>(payload);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['attempts'] = Variable<int>(attempts);
    return map;
  }

  SpikePendingOpsCompanion toCompanion(bool nullToAbsent) {
    return SpikePendingOpsCompanion(
      id: Value(id),
      venueId: Value(venueId),
      opType: Value(opType),
      payload: Value(payload),
      createdAt: Value(createdAt),
      attempts: Value(attempts),
    );
  }

  factory SpikePendingOp.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SpikePendingOp(
      id: serializer.fromJson<int>(json['id']),
      venueId: serializer.fromJson<String>(json['venueId']),
      opType: serializer.fromJson<String>(json['opType']),
      payload: serializer.fromJson<String>(json['payload']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      attempts: serializer.fromJson<int>(json['attempts']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'venueId': serializer.toJson<String>(venueId),
      'opType': serializer.toJson<String>(opType),
      'payload': serializer.toJson<String>(payload),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'attempts': serializer.toJson<int>(attempts),
    };
  }

  SpikePendingOp copyWith({
    int? id,
    String? venueId,
    String? opType,
    String? payload,
    DateTime? createdAt,
    int? attempts,
  }) => SpikePendingOp(
    id: id ?? this.id,
    venueId: venueId ?? this.venueId,
    opType: opType ?? this.opType,
    payload: payload ?? this.payload,
    createdAt: createdAt ?? this.createdAt,
    attempts: attempts ?? this.attempts,
  );
  SpikePendingOp copyWithCompanion(SpikePendingOpsCompanion data) {
    return SpikePendingOp(
      id: data.id.present ? data.id.value : this.id,
      venueId: data.venueId.present ? data.venueId.value : this.venueId,
      opType: data.opType.present ? data.opType.value : this.opType,
      payload: data.payload.present ? data.payload.value : this.payload,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SpikePendingOp(')
          ..write('id: $id, ')
          ..write('venueId: $venueId, ')
          ..write('opType: $opType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, venueId, opType, payload, createdAt, attempts);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SpikePendingOp &&
          other.id == this.id &&
          other.venueId == this.venueId &&
          other.opType == this.opType &&
          other.payload == this.payload &&
          other.createdAt == this.createdAt &&
          other.attempts == this.attempts);
}

class SpikePendingOpsCompanion extends UpdateCompanion<SpikePendingOp> {
  final Value<int> id;
  final Value<String> venueId;
  final Value<String> opType;
  final Value<String> payload;
  final Value<DateTime> createdAt;
  final Value<int> attempts;
  const SpikePendingOpsCompanion({
    this.id = const Value.absent(),
    this.venueId = const Value.absent(),
    this.opType = const Value.absent(),
    this.payload = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
  });
  SpikePendingOpsCompanion.insert({
    this.id = const Value.absent(),
    required String venueId,
    required String opType,
    required String payload,
    this.createdAt = const Value.absent(),
    this.attempts = const Value.absent(),
  }) : venueId = Value(venueId),
       opType = Value(opType),
       payload = Value(payload);
  static Insertable<SpikePendingOp> custom({
    Expression<int>? id,
    Expression<String>? venueId,
    Expression<String>? opType,
    Expression<String>? payload,
    Expression<DateTime>? createdAt,
    Expression<int>? attempts,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (venueId != null) 'venue_id': venueId,
      if (opType != null) 'op_type': opType,
      if (payload != null) 'payload': payload,
      if (createdAt != null) 'created_at': createdAt,
      if (attempts != null) 'attempts': attempts,
    });
  }

  SpikePendingOpsCompanion copyWith({
    Value<int>? id,
    Value<String>? venueId,
    Value<String>? opType,
    Value<String>? payload,
    Value<DateTime>? createdAt,
    Value<int>? attempts,
  }) {
    return SpikePendingOpsCompanion(
      id: id ?? this.id,
      venueId: venueId ?? this.venueId,
      opType: opType ?? this.opType,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      attempts: attempts ?? this.attempts,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (venueId.present) {
      map['venue_id'] = Variable<String>(venueId.value);
    }
    if (opType.present) {
      map['op_type'] = Variable<String>(opType.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SpikePendingOpsCompanion(')
          ..write('id: $id, ')
          ..write('venueId: $venueId, ')
          ..write('opType: $opType, ')
          ..write('payload: $payload, ')
          ..write('createdAt: $createdAt, ')
          ..write('attempts: $attempts')
          ..write(')'))
        .toString();
  }
}

abstract class _$SpikeDatabase extends GeneratedDatabase {
  _$SpikeDatabase(QueryExecutor e) : super(e);
  $SpikeDatabaseManager get managers => $SpikeDatabaseManager(this);
  late final $SpikePendingOpsTable spikePendingOps = $SpikePendingOpsTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [spikePendingOps];
}

typedef $$SpikePendingOpsTableCreateCompanionBuilder =
    SpikePendingOpsCompanion Function({
      Value<int> id,
      required String venueId,
      required String opType,
      required String payload,
      Value<DateTime> createdAt,
      Value<int> attempts,
    });
typedef $$SpikePendingOpsTableUpdateCompanionBuilder =
    SpikePendingOpsCompanion Function({
      Value<int> id,
      Value<String> venueId,
      Value<String> opType,
      Value<String> payload,
      Value<DateTime> createdAt,
      Value<int> attempts,
    });

class $$SpikePendingOpsTableFilterComposer
    extends Composer<_$SpikeDatabase, $SpikePendingOpsTable> {
  $$SpikePendingOpsTableFilterComposer({
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

  ColumnFilters<String> get venueId => $composableBuilder(
    column: $table.venueId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get opType => $composableBuilder(
    column: $table.opType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SpikePendingOpsTableOrderingComposer
    extends Composer<_$SpikeDatabase, $SpikePendingOpsTable> {
  $$SpikePendingOpsTableOrderingComposer({
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

  ColumnOrderings<String> get venueId => $composableBuilder(
    column: $table.venueId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get opType => $composableBuilder(
    column: $table.opType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SpikePendingOpsTableAnnotationComposer
    extends Composer<_$SpikeDatabase, $SpikePendingOpsTable> {
  $$SpikePendingOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get venueId =>
      $composableBuilder(column: $table.venueId, builder: (column) => column);

  GeneratedColumn<String> get opType =>
      $composableBuilder(column: $table.opType, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);
}

class $$SpikePendingOpsTableTableManager
    extends
        RootTableManager<
          _$SpikeDatabase,
          $SpikePendingOpsTable,
          SpikePendingOp,
          $$SpikePendingOpsTableFilterComposer,
          $$SpikePendingOpsTableOrderingComposer,
          $$SpikePendingOpsTableAnnotationComposer,
          $$SpikePendingOpsTableCreateCompanionBuilder,
          $$SpikePendingOpsTableUpdateCompanionBuilder,
          (
            SpikePendingOp,
            BaseReferences<
              _$SpikeDatabase,
              $SpikePendingOpsTable,
              SpikePendingOp
            >,
          ),
          SpikePendingOp,
          PrefetchHooks Function()
        > {
  $$SpikePendingOpsTableTableManager(
    _$SpikeDatabase db,
    $SpikePendingOpsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer:
              () =>
                  $$SpikePendingOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer:
              () => $$SpikePendingOpsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer:
              () => $$SpikePendingOpsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> venueId = const Value.absent(),
                Value<String> opType = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => SpikePendingOpsCompanion(
                id: id,
                venueId: venueId,
                opType: opType,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String venueId,
                required String opType,
                required String payload,
                Value<DateTime> createdAt = const Value.absent(),
                Value<int> attempts = const Value.absent(),
              }) => SpikePendingOpsCompanion.insert(
                id: id,
                venueId: venueId,
                opType: opType,
                payload: payload,
                createdAt: createdAt,
                attempts: attempts,
              ),
          withReferenceMapper:
              (p0) =>
                  p0
                      .map(
                        (e) => (
                          e.readTable(table),
                          BaseReferences(db, table, e),
                        ),
                      )
                      .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SpikePendingOpsTableProcessedTableManager =
    ProcessedTableManager<
      _$SpikeDatabase,
      $SpikePendingOpsTable,
      SpikePendingOp,
      $$SpikePendingOpsTableFilterComposer,
      $$SpikePendingOpsTableOrderingComposer,
      $$SpikePendingOpsTableAnnotationComposer,
      $$SpikePendingOpsTableCreateCompanionBuilder,
      $$SpikePendingOpsTableUpdateCompanionBuilder,
      (
        SpikePendingOp,
        BaseReferences<_$SpikeDatabase, $SpikePendingOpsTable, SpikePendingOp>,
      ),
      SpikePendingOp,
      PrefetchHooks Function()
    >;

class $SpikeDatabaseManager {
  final _$SpikeDatabase _db;
  $SpikeDatabaseManager(this._db);
  $$SpikePendingOpsTableTableManager get spikePendingOps =>
      $$SpikePendingOpsTableTableManager(_db, _db.spikePendingOps);
}
