// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database_native.dart';

// ignore_for_file: type=lint
class $ToneSamplesTable extends ToneSamples
    with TableInfo<$ToneSamplesTable, ToneSample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ToneSamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sampleTextMeta = const VerificationMeta(
    'sampleText',
  );
  @override
  late final GeneratedColumn<String> sampleText = GeneratedColumn<String>(
    'sample_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMsMeta = const VerificationMeta(
    'createdAtMs',
  );
  @override
  late final GeneratedColumn<int> createdAtMs = GeneratedColumn<int>(
    'created_at_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sampleText,
    createdAtMs,
    sortOrder,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tone_samples';
  @override
  VerificationContext validateIntegrity(
    Insertable<ToneSample> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('sample_text')) {
      context.handle(
        _sampleTextMeta,
        sampleText.isAcceptableOrUnknown(data['sample_text']!, _sampleTextMeta),
      );
    } else if (isInserting) {
      context.missing(_sampleTextMeta);
    }
    if (data.containsKey('created_at_ms')) {
      context.handle(
        _createdAtMsMeta,
        createdAtMs.isAcceptableOrUnknown(
          data['created_at_ms']!,
          _createdAtMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtMsMeta);
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    } else if (isInserting) {
      context.missing(_sortOrderMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ToneSample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ToneSample(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sampleText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sample_text'],
      )!,
      createdAtMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_ms'],
      )!,
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
    );
  }

  @override
  $ToneSamplesTable createAlias(String alias) {
    return $ToneSamplesTable(attachedDatabase, alias);
  }
}

class ToneSample extends DataClass implements Insertable<ToneSample> {
  final String id;
  final String sampleText;
  final int createdAtMs;
  final int sortOrder;
  const ToneSample({
    required this.id,
    required this.sampleText,
    required this.createdAtMs,
    required this.sortOrder,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['sample_text'] = Variable<String>(sampleText);
    map['created_at_ms'] = Variable<int>(createdAtMs);
    map['sort_order'] = Variable<int>(sortOrder);
    return map;
  }

  ToneSamplesCompanion toCompanion(bool nullToAbsent) {
    return ToneSamplesCompanion(
      id: Value(id),
      sampleText: Value(sampleText),
      createdAtMs: Value(createdAtMs),
      sortOrder: Value(sortOrder),
    );
  }

  factory ToneSample.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ToneSample(
      id: serializer.fromJson<String>(json['id']),
      sampleText: serializer.fromJson<String>(json['sampleText']),
      createdAtMs: serializer.fromJson<int>(json['createdAtMs']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sampleText': serializer.toJson<String>(sampleText),
      'createdAtMs': serializer.toJson<int>(createdAtMs),
      'sortOrder': serializer.toJson<int>(sortOrder),
    };
  }

  ToneSample copyWith({
    String? id,
    String? sampleText,
    int? createdAtMs,
    int? sortOrder,
  }) => ToneSample(
    id: id ?? this.id,
    sampleText: sampleText ?? this.sampleText,
    createdAtMs: createdAtMs ?? this.createdAtMs,
    sortOrder: sortOrder ?? this.sortOrder,
  );
  ToneSample copyWithCompanion(ToneSamplesCompanion data) {
    return ToneSample(
      id: data.id.present ? data.id.value : this.id,
      sampleText: data.sampleText.present
          ? data.sampleText.value
          : this.sampleText,
      createdAtMs: data.createdAtMs.present
          ? data.createdAtMs.value
          : this.createdAtMs,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ToneSample(')
          ..write('id: $id, ')
          ..write('sampleText: $sampleText, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('sortOrder: $sortOrder')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, sampleText, createdAtMs, sortOrder);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ToneSample &&
          other.id == this.id &&
          other.sampleText == this.sampleText &&
          other.createdAtMs == this.createdAtMs &&
          other.sortOrder == this.sortOrder);
}

class ToneSamplesCompanion extends UpdateCompanion<ToneSample> {
  final Value<String> id;
  final Value<String> sampleText;
  final Value<int> createdAtMs;
  final Value<int> sortOrder;
  final Value<int> rowid;
  const ToneSamplesCompanion({
    this.id = const Value.absent(),
    this.sampleText = const Value.absent(),
    this.createdAtMs = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ToneSamplesCompanion.insert({
    required String id,
    required String sampleText,
    required int createdAtMs,
    required int sortOrder,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sampleText = Value(sampleText),
       createdAtMs = Value(createdAtMs),
       sortOrder = Value(sortOrder);
  static Insertable<ToneSample> custom({
    Expression<String>? id,
    Expression<String>? sampleText,
    Expression<int>? createdAtMs,
    Expression<int>? sortOrder,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sampleText != null) 'sample_text': sampleText,
      if (createdAtMs != null) 'created_at_ms': createdAtMs,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ToneSamplesCompanion copyWith({
    Value<String>? id,
    Value<String>? sampleText,
    Value<int>? createdAtMs,
    Value<int>? sortOrder,
    Value<int>? rowid,
  }) {
    return ToneSamplesCompanion(
      id: id ?? this.id,
      sampleText: sampleText ?? this.sampleText,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      sortOrder: sortOrder ?? this.sortOrder,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sampleText.present) {
      map['sample_text'] = Variable<String>(sampleText.value);
    }
    if (createdAtMs.present) {
      map['created_at_ms'] = Variable<int>(createdAtMs.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ToneSamplesCompanion(')
          ..write('id: $id, ')
          ..write('sampleText: $sampleText, ')
          ..write('createdAtMs: $createdAtMs, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalKvTable extends LocalKv with TableInfo<$LocalKvTable, LocalKvData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalKvTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_kv';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalKvData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  LocalKvData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalKvData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $LocalKvTable createAlias(String alias) {
    return $LocalKvTable(attachedDatabase, alias);
  }
}

class LocalKvData extends DataClass implements Insertable<LocalKvData> {
  final String key;
  final String value;
  const LocalKvData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  LocalKvCompanion toCompanion(bool nullToAbsent) {
    return LocalKvCompanion(key: Value(key), value: Value(value));
  }

  factory LocalKvData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalKvData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  LocalKvData copyWith({String? key, String? value}) =>
      LocalKvData(key: key ?? this.key, value: value ?? this.value);
  LocalKvData copyWithCompanion(LocalKvCompanion data) {
    return LocalKvData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalKvData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalKvData &&
          other.key == this.key &&
          other.value == this.value);
}

class LocalKvCompanion extends UpdateCompanion<LocalKvData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const LocalKvCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalKvCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<LocalKvData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalKvCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return LocalKvCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalKvCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ConversationSnoozesTable extends ConversationSnoozes
    with TableInfo<$ConversationSnoozesTable, ConversationSnooze> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConversationSnoozesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snoozedUntilMsMeta = const VerificationMeta(
    'snoozedUntilMs',
  );
  @override
  late final GeneratedColumn<int> snoozedUntilMs = GeneratedColumn<int>(
    'snoozed_until_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [conversationId, snoozedUntilMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'conversation_snoozes';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConversationSnooze> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('snoozed_until_ms')) {
      context.handle(
        _snoozedUntilMsMeta,
        snoozedUntilMs.isAcceptableOrUnknown(
          data['snoozed_until_ms']!,
          _snoozedUntilMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snoozedUntilMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {conversationId};
  @override
  ConversationSnooze map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConversationSnooze(
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      snoozedUntilMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snoozed_until_ms'],
      )!,
    );
  }

  @override
  $ConversationSnoozesTable createAlias(String alias) {
    return $ConversationSnoozesTable(attachedDatabase, alias);
  }
}

class ConversationSnooze extends DataClass
    implements Insertable<ConversationSnooze> {
  /// `Conversation.id`를 문자열로 저장 (drift 기본 타입 일관성을 위해 다른 테이블과
  /// 마찬가지로 text 기본키를 사용).
  final String conversationId;
  final int snoozedUntilMs;
  const ConversationSnooze({
    required this.conversationId,
    required this.snoozedUntilMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['conversation_id'] = Variable<String>(conversationId);
    map['snoozed_until_ms'] = Variable<int>(snoozedUntilMs);
    return map;
  }

  ConversationSnoozesCompanion toCompanion(bool nullToAbsent) {
    return ConversationSnoozesCompanion(
      conversationId: Value(conversationId),
      snoozedUntilMs: Value(snoozedUntilMs),
    );
  }

  factory ConversationSnooze.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConversationSnooze(
      conversationId: serializer.fromJson<String>(json['conversationId']),
      snoozedUntilMs: serializer.fromJson<int>(json['snoozedUntilMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'conversationId': serializer.toJson<String>(conversationId),
      'snoozedUntilMs': serializer.toJson<int>(snoozedUntilMs),
    };
  }

  ConversationSnooze copyWith({String? conversationId, int? snoozedUntilMs}) =>
      ConversationSnooze(
        conversationId: conversationId ?? this.conversationId,
        snoozedUntilMs: snoozedUntilMs ?? this.snoozedUntilMs,
      );
  ConversationSnooze copyWithCompanion(ConversationSnoozesCompanion data) {
    return ConversationSnooze(
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      snoozedUntilMs: data.snoozedUntilMs.present
          ? data.snoozedUntilMs.value
          : this.snoozedUntilMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConversationSnooze(')
          ..write('conversationId: $conversationId, ')
          ..write('snoozedUntilMs: $snoozedUntilMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(conversationId, snoozedUntilMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConversationSnooze &&
          other.conversationId == this.conversationId &&
          other.snoozedUntilMs == this.snoozedUntilMs);
}

class ConversationSnoozesCompanion extends UpdateCompanion<ConversationSnooze> {
  final Value<String> conversationId;
  final Value<int> snoozedUntilMs;
  final Value<int> rowid;
  const ConversationSnoozesCompanion({
    this.conversationId = const Value.absent(),
    this.snoozedUntilMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ConversationSnoozesCompanion.insert({
    required String conversationId,
    required int snoozedUntilMs,
    this.rowid = const Value.absent(),
  }) : conversationId = Value(conversationId),
       snoozedUntilMs = Value(snoozedUntilMs);
  static Insertable<ConversationSnooze> custom({
    Expression<String>? conversationId,
    Expression<int>? snoozedUntilMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (conversationId != null) 'conversation_id': conversationId,
      if (snoozedUntilMs != null) 'snoozed_until_ms': snoozedUntilMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ConversationSnoozesCompanion copyWith({
    Value<String>? conversationId,
    Value<int>? snoozedUntilMs,
    Value<int>? rowid,
  }) {
    return ConversationSnoozesCompanion(
      conversationId: conversationId ?? this.conversationId,
      snoozedUntilMs: snoozedUntilMs ?? this.snoozedUntilMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (snoozedUntilMs.present) {
      map['snoozed_until_ms'] = Variable<int>(snoozedUntilMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConversationSnoozesCompanion(')
          ..write('conversationId: $conversationId, ')
          ..write('snoozedUntilMs: $snoozedUntilMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ToneSamplesTable toneSamples = $ToneSamplesTable(this);
  late final $LocalKvTable localKv = $LocalKvTable(this);
  late final $ConversationSnoozesTable conversationSnoozes =
      $ConversationSnoozesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    toneSamples,
    localKv,
    conversationSnoozes,
  ];
}

typedef $$ToneSamplesTableCreateCompanionBuilder =
    ToneSamplesCompanion Function({
      required String id,
      required String sampleText,
      required int createdAtMs,
      required int sortOrder,
      Value<int> rowid,
    });
typedef $$ToneSamplesTableUpdateCompanionBuilder =
    ToneSamplesCompanion Function({
      Value<String> id,
      Value<String> sampleText,
      Value<int> createdAtMs,
      Value<int> sortOrder,
      Value<int> rowid,
    });

class $$ToneSamplesTableFilterComposer
    extends Composer<_$AppDatabase, $ToneSamplesTable> {
  $$ToneSamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sampleText => $composableBuilder(
    column: $table.sampleText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ToneSamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $ToneSamplesTable> {
  $$ToneSamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sampleText => $composableBuilder(
    column: $table.sampleText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ToneSamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ToneSamplesTable> {
  $$ToneSamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sampleText => $composableBuilder(
    column: $table.sampleText,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtMs => $composableBuilder(
    column: $table.createdAtMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);
}

class $$ToneSamplesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ToneSamplesTable,
          ToneSample,
          $$ToneSamplesTableFilterComposer,
          $$ToneSamplesTableOrderingComposer,
          $$ToneSamplesTableAnnotationComposer,
          $$ToneSamplesTableCreateCompanionBuilder,
          $$ToneSamplesTableUpdateCompanionBuilder,
          (
            ToneSample,
            BaseReferences<_$AppDatabase, $ToneSamplesTable, ToneSample>,
          ),
          ToneSample,
          PrefetchHooks Function()
        > {
  $$ToneSamplesTableTableManager(_$AppDatabase db, $ToneSamplesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ToneSamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ToneSamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ToneSamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sampleText = const Value.absent(),
                Value<int> createdAtMs = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ToneSamplesCompanion(
                id: id,
                sampleText: sampleText,
                createdAtMs: createdAtMs,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sampleText,
                required int createdAtMs,
                required int sortOrder,
                Value<int> rowid = const Value.absent(),
              }) => ToneSamplesCompanion.insert(
                id: id,
                sampleText: sampleText,
                createdAtMs: createdAtMs,
                sortOrder: sortOrder,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ToneSamplesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ToneSamplesTable,
      ToneSample,
      $$ToneSamplesTableFilterComposer,
      $$ToneSamplesTableOrderingComposer,
      $$ToneSamplesTableAnnotationComposer,
      $$ToneSamplesTableCreateCompanionBuilder,
      $$ToneSamplesTableUpdateCompanionBuilder,
      (
        ToneSample,
        BaseReferences<_$AppDatabase, $ToneSamplesTable, ToneSample>,
      ),
      ToneSample,
      PrefetchHooks Function()
    >;
typedef $$LocalKvTableCreateCompanionBuilder =
    LocalKvCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$LocalKvTableUpdateCompanionBuilder =
    LocalKvCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$LocalKvTableFilterComposer
    extends Composer<_$AppDatabase, $LocalKvTable> {
  $$LocalKvTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalKvTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalKvTable> {
  $$LocalKvTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalKvTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalKvTable> {
  $$LocalKvTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$LocalKvTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalKvTable,
          LocalKvData,
          $$LocalKvTableFilterComposer,
          $$LocalKvTableOrderingComposer,
          $$LocalKvTableAnnotationComposer,
          $$LocalKvTableCreateCompanionBuilder,
          $$LocalKvTableUpdateCompanionBuilder,
          (
            LocalKvData,
            BaseReferences<_$AppDatabase, $LocalKvTable, LocalKvData>,
          ),
          LocalKvData,
          PrefetchHooks Function()
        > {
  $$LocalKvTableTableManager(_$AppDatabase db, $LocalKvTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalKvTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalKvTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalKvTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalKvCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) =>
                  LocalKvCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalKvTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalKvTable,
      LocalKvData,
      $$LocalKvTableFilterComposer,
      $$LocalKvTableOrderingComposer,
      $$LocalKvTableAnnotationComposer,
      $$LocalKvTableCreateCompanionBuilder,
      $$LocalKvTableUpdateCompanionBuilder,
      (LocalKvData, BaseReferences<_$AppDatabase, $LocalKvTable, LocalKvData>),
      LocalKvData,
      PrefetchHooks Function()
    >;
typedef $$ConversationSnoozesTableCreateCompanionBuilder =
    ConversationSnoozesCompanion Function({
      required String conversationId,
      required int snoozedUntilMs,
      Value<int> rowid,
    });
typedef $$ConversationSnoozesTableUpdateCompanionBuilder =
    ConversationSnoozesCompanion Function({
      Value<String> conversationId,
      Value<int> snoozedUntilMs,
      Value<int> rowid,
    });

class $$ConversationSnoozesTableFilterComposer
    extends Composer<_$AppDatabase, $ConversationSnoozesTable> {
  $$ConversationSnoozesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozedUntilMs => $composableBuilder(
    column: $table.snoozedUntilMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConversationSnoozesTableOrderingComposer
    extends Composer<_$AppDatabase, $ConversationSnoozesTable> {
  $$ConversationSnoozesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozedUntilMs => $composableBuilder(
    column: $table.snoozedUntilMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConversationSnoozesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConversationSnoozesTable> {
  $$ConversationSnoozesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozedUntilMs => $composableBuilder(
    column: $table.snoozedUntilMs,
    builder: (column) => column,
  );
}

class $$ConversationSnoozesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConversationSnoozesTable,
          ConversationSnooze,
          $$ConversationSnoozesTableFilterComposer,
          $$ConversationSnoozesTableOrderingComposer,
          $$ConversationSnoozesTableAnnotationComposer,
          $$ConversationSnoozesTableCreateCompanionBuilder,
          $$ConversationSnoozesTableUpdateCompanionBuilder,
          (
            ConversationSnooze,
            BaseReferences<
              _$AppDatabase,
              $ConversationSnoozesTable,
              ConversationSnooze
            >,
          ),
          ConversationSnooze,
          PrefetchHooks Function()
        > {
  $$ConversationSnoozesTableTableManager(
    _$AppDatabase db,
    $ConversationSnoozesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConversationSnoozesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConversationSnoozesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConversationSnoozesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> conversationId = const Value.absent(),
                Value<int> snoozedUntilMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ConversationSnoozesCompanion(
                conversationId: conversationId,
                snoozedUntilMs: snoozedUntilMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String conversationId,
                required int snoozedUntilMs,
                Value<int> rowid = const Value.absent(),
              }) => ConversationSnoozesCompanion.insert(
                conversationId: conversationId,
                snoozedUntilMs: snoozedUntilMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConversationSnoozesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConversationSnoozesTable,
      ConversationSnooze,
      $$ConversationSnoozesTableFilterComposer,
      $$ConversationSnoozesTableOrderingComposer,
      $$ConversationSnoozesTableAnnotationComposer,
      $$ConversationSnoozesTableCreateCompanionBuilder,
      $$ConversationSnoozesTableUpdateCompanionBuilder,
      (
        ConversationSnooze,
        BaseReferences<
          _$AppDatabase,
          $ConversationSnoozesTable,
          ConversationSnooze
        >,
      ),
      ConversationSnooze,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ToneSamplesTableTableManager get toneSamples =>
      $$ToneSamplesTableTableManager(_db, _db.toneSamples);
  $$LocalKvTableTableManager get localKv =>
      $$LocalKvTableTableManager(_db, _db.localKv);
  $$ConversationSnoozesTableTableManager get conversationSnoozes =>
      $$ConversationSnoozesTableTableManager(_db, _db.conversationSnoozes);
}
