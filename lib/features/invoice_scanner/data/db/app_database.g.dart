// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $InvoiceRowsTable extends InvoiceRows
    with TableInfo<$InvoiceRowsTable, InvoiceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InvoiceRowsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _imageNamesMeta = const VerificationMeta(
    'imageNames',
  );
  @override
  late final GeneratedColumn<String> imageNames = GeneratedColumn<String>(
    'image_names',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _attemptCountMeta = const VerificationMeta(
    'attemptCount',
  );
  @override
  late final GeneratedColumn<int> attemptCount = GeneratedColumn<int>(
    'attempt_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _invoiceJsonMeta = const VerificationMeta(
    'invoiceJson',
  );
  @override
  late final GeneratedColumn<String> invoiceJson = GeneratedColumn<String>(
    'invoice_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _extractedJsonMeta = const VerificationMeta(
    'extractedJson',
  );
  @override
  late final GeneratedColumn<String> extractedJson = GeneratedColumn<String>(
    'extracted_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _failureKindMeta = const VerificationMeta(
    'failureKind',
  );
  @override
  late final GeneratedColumn<String> failureKind = GeneratedColumn<String>(
    'failure_kind',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _savedAtMeta = const VerificationMeta(
    'savedAt',
  );
  @override
  late final GeneratedColumn<int> savedAt = GeneratedColumn<int>(
    'saved_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _remoteSyncedAtMeta = const VerificationMeta(
    'remoteSyncedAt',
  );
  @override
  late final GeneratedColumn<int> remoteSyncedAt = GeneratedColumn<int>(
    'remote_synced_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<int> deletedAt = GeneratedColumn<int>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    status,
    imageNames,
    attemptCount,
    createdAt,
    updatedAt,
    invoiceJson,
    extractedJson,
    failureKind,
    savedAt,
    remoteSyncedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'invoices';
  @override
  VerificationContext validateIntegrity(
    Insertable<InvoiceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('image_names')) {
      context.handle(
        _imageNamesMeta,
        imageNames.isAcceptableOrUnknown(data['image_names']!, _imageNamesMeta),
      );
    } else if (isInserting) {
      context.missing(_imageNamesMeta);
    }
    if (data.containsKey('attempt_count')) {
      context.handle(
        _attemptCountMeta,
        attemptCount.isAcceptableOrUnknown(
          data['attempt_count']!,
          _attemptCountMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_attemptCountMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('invoice_json')) {
      context.handle(
        _invoiceJsonMeta,
        invoiceJson.isAcceptableOrUnknown(
          data['invoice_json']!,
          _invoiceJsonMeta,
        ),
      );
    }
    if (data.containsKey('extracted_json')) {
      context.handle(
        _extractedJsonMeta,
        extractedJson.isAcceptableOrUnknown(
          data['extracted_json']!,
          _extractedJsonMeta,
        ),
      );
    }
    if (data.containsKey('failure_kind')) {
      context.handle(
        _failureKindMeta,
        failureKind.isAcceptableOrUnknown(
          data['failure_kind']!,
          _failureKindMeta,
        ),
      );
    }
    if (data.containsKey('saved_at')) {
      context.handle(
        _savedAtMeta,
        savedAt.isAcceptableOrUnknown(data['saved_at']!, _savedAtMeta),
      );
    }
    if (data.containsKey('remote_synced_at')) {
      context.handle(
        _remoteSyncedAtMeta,
        remoteSyncedAt.isAcceptableOrUnknown(
          data['remote_synced_at']!,
          _remoteSyncedAtMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InvoiceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InvoiceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      imageNames: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}image_names'],
      )!,
      attemptCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempt_count'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
      invoiceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}invoice_json'],
      ),
      extractedJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}extracted_json'],
      ),
      failureKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}failure_kind'],
      ),
      savedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}saved_at'],
      ),
      remoteSyncedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}remote_synced_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $InvoiceRowsTable createAlias(String alias) {
    return $InvoiceRowsTable(attachedDatabase, alias);
  }
}

class InvoiceRow extends DataClass implements Insertable<InvoiceRow> {
  final String id;
  final String status;
  final String imageNames;
  final int attemptCount;
  final int createdAt;
  final int updatedAt;
  final String? invoiceJson;
  final String? extractedJson;
  final String? failureKind;
  final int? savedAt;
  final int? remoteSyncedAt;
  final int? deletedAt;
  const InvoiceRow({
    required this.id,
    required this.status,
    required this.imageNames,
    required this.attemptCount,
    required this.createdAt,
    required this.updatedAt,
    this.invoiceJson,
    this.extractedJson,
    this.failureKind,
    this.savedAt,
    this.remoteSyncedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['status'] = Variable<String>(status);
    map['image_names'] = Variable<String>(imageNames);
    map['attempt_count'] = Variable<int>(attemptCount);
    map['created_at'] = Variable<int>(createdAt);
    map['updated_at'] = Variable<int>(updatedAt);
    if (!nullToAbsent || invoiceJson != null) {
      map['invoice_json'] = Variable<String>(invoiceJson);
    }
    if (!nullToAbsent || extractedJson != null) {
      map['extracted_json'] = Variable<String>(extractedJson);
    }
    if (!nullToAbsent || failureKind != null) {
      map['failure_kind'] = Variable<String>(failureKind);
    }
    if (!nullToAbsent || savedAt != null) {
      map['saved_at'] = Variable<int>(savedAt);
    }
    if (!nullToAbsent || remoteSyncedAt != null) {
      map['remote_synced_at'] = Variable<int>(remoteSyncedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<int>(deletedAt);
    }
    return map;
  }

  InvoiceRowsCompanion toCompanion(bool nullToAbsent) {
    return InvoiceRowsCompanion(
      id: Value(id),
      status: Value(status),
      imageNames: Value(imageNames),
      attemptCount: Value(attemptCount),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      invoiceJson: invoiceJson == null && nullToAbsent
          ? const Value.absent()
          : Value(invoiceJson),
      extractedJson: extractedJson == null && nullToAbsent
          ? const Value.absent()
          : Value(extractedJson),
      failureKind: failureKind == null && nullToAbsent
          ? const Value.absent()
          : Value(failureKind),
      savedAt: savedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(savedAt),
      remoteSyncedAt: remoteSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteSyncedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory InvoiceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InvoiceRow(
      id: serializer.fromJson<String>(json['id']),
      status: serializer.fromJson<String>(json['status']),
      imageNames: serializer.fromJson<String>(json['imageNames']),
      attemptCount: serializer.fromJson<int>(json['attemptCount']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
      invoiceJson: serializer.fromJson<String?>(json['invoiceJson']),
      extractedJson: serializer.fromJson<String?>(json['extractedJson']),
      failureKind: serializer.fromJson<String?>(json['failureKind']),
      savedAt: serializer.fromJson<int?>(json['savedAt']),
      remoteSyncedAt: serializer.fromJson<int?>(json['remoteSyncedAt']),
      deletedAt: serializer.fromJson<int?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'status': serializer.toJson<String>(status),
      'imageNames': serializer.toJson<String>(imageNames),
      'attemptCount': serializer.toJson<int>(attemptCount),
      'createdAt': serializer.toJson<int>(createdAt),
      'updatedAt': serializer.toJson<int>(updatedAt),
      'invoiceJson': serializer.toJson<String?>(invoiceJson),
      'extractedJson': serializer.toJson<String?>(extractedJson),
      'failureKind': serializer.toJson<String?>(failureKind),
      'savedAt': serializer.toJson<int?>(savedAt),
      'remoteSyncedAt': serializer.toJson<int?>(remoteSyncedAt),
      'deletedAt': serializer.toJson<int?>(deletedAt),
    };
  }

  InvoiceRow copyWith({
    String? id,
    String? status,
    String? imageNames,
    int? attemptCount,
    int? createdAt,
    int? updatedAt,
    Value<String?> invoiceJson = const Value.absent(),
    Value<String?> extractedJson = const Value.absent(),
    Value<String?> failureKind = const Value.absent(),
    Value<int?> savedAt = const Value.absent(),
    Value<int?> remoteSyncedAt = const Value.absent(),
    Value<int?> deletedAt = const Value.absent(),
  }) => InvoiceRow(
    id: id ?? this.id,
    status: status ?? this.status,
    imageNames: imageNames ?? this.imageNames,
    attemptCount: attemptCount ?? this.attemptCount,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    invoiceJson: invoiceJson.present ? invoiceJson.value : this.invoiceJson,
    extractedJson: extractedJson.present
        ? extractedJson.value
        : this.extractedJson,
    failureKind: failureKind.present ? failureKind.value : this.failureKind,
    savedAt: savedAt.present ? savedAt.value : this.savedAt,
    remoteSyncedAt: remoteSyncedAt.present
        ? remoteSyncedAt.value
        : this.remoteSyncedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  InvoiceRow copyWithCompanion(InvoiceRowsCompanion data) {
    return InvoiceRow(
      id: data.id.present ? data.id.value : this.id,
      status: data.status.present ? data.status.value : this.status,
      imageNames: data.imageNames.present
          ? data.imageNames.value
          : this.imageNames,
      attemptCount: data.attemptCount.present
          ? data.attemptCount.value
          : this.attemptCount,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      invoiceJson: data.invoiceJson.present
          ? data.invoiceJson.value
          : this.invoiceJson,
      extractedJson: data.extractedJson.present
          ? data.extractedJson.value
          : this.extractedJson,
      failureKind: data.failureKind.present
          ? data.failureKind.value
          : this.failureKind,
      savedAt: data.savedAt.present ? data.savedAt.value : this.savedAt,
      remoteSyncedAt: data.remoteSyncedAt.present
          ? data.remoteSyncedAt.value
          : this.remoteSyncedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceRow(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('imageNames: $imageNames, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('invoiceJson: $invoiceJson, ')
          ..write('extractedJson: $extractedJson, ')
          ..write('failureKind: $failureKind, ')
          ..write('savedAt: $savedAt, ')
          ..write('remoteSyncedAt: $remoteSyncedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    status,
    imageNames,
    attemptCount,
    createdAt,
    updatedAt,
    invoiceJson,
    extractedJson,
    failureKind,
    savedAt,
    remoteSyncedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InvoiceRow &&
          other.id == this.id &&
          other.status == this.status &&
          other.imageNames == this.imageNames &&
          other.attemptCount == this.attemptCount &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.invoiceJson == this.invoiceJson &&
          other.extractedJson == this.extractedJson &&
          other.failureKind == this.failureKind &&
          other.savedAt == this.savedAt &&
          other.remoteSyncedAt == this.remoteSyncedAt &&
          other.deletedAt == this.deletedAt);
}

class InvoiceRowsCompanion extends UpdateCompanion<InvoiceRow> {
  final Value<String> id;
  final Value<String> status;
  final Value<String> imageNames;
  final Value<int> attemptCount;
  final Value<int> createdAt;
  final Value<int> updatedAt;
  final Value<String?> invoiceJson;
  final Value<String?> extractedJson;
  final Value<String?> failureKind;
  final Value<int?> savedAt;
  final Value<int?> remoteSyncedAt;
  final Value<int?> deletedAt;
  final Value<int> rowid;
  const InvoiceRowsCompanion({
    this.id = const Value.absent(),
    this.status = const Value.absent(),
    this.imageNames = const Value.absent(),
    this.attemptCount = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.invoiceJson = const Value.absent(),
    this.extractedJson = const Value.absent(),
    this.failureKind = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.remoteSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  InvoiceRowsCompanion.insert({
    required String id,
    required String status,
    required String imageNames,
    required int attemptCount,
    required int createdAt,
    required int updatedAt,
    this.invoiceJson = const Value.absent(),
    this.extractedJson = const Value.absent(),
    this.failureKind = const Value.absent(),
    this.savedAt = const Value.absent(),
    this.remoteSyncedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       status = Value(status),
       imageNames = Value(imageNames),
       attemptCount = Value(attemptCount),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<InvoiceRow> custom({
    Expression<String>? id,
    Expression<String>? status,
    Expression<String>? imageNames,
    Expression<int>? attemptCount,
    Expression<int>? createdAt,
    Expression<int>? updatedAt,
    Expression<String>? invoiceJson,
    Expression<String>? extractedJson,
    Expression<String>? failureKind,
    Expression<int>? savedAt,
    Expression<int>? remoteSyncedAt,
    Expression<int>? deletedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (status != null) 'status': status,
      if (imageNames != null) 'image_names': imageNames,
      if (attemptCount != null) 'attempt_count': attemptCount,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (invoiceJson != null) 'invoice_json': invoiceJson,
      if (extractedJson != null) 'extracted_json': extractedJson,
      if (failureKind != null) 'failure_kind': failureKind,
      if (savedAt != null) 'saved_at': savedAt,
      if (remoteSyncedAt != null) 'remote_synced_at': remoteSyncedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  InvoiceRowsCompanion copyWith({
    Value<String>? id,
    Value<String>? status,
    Value<String>? imageNames,
    Value<int>? attemptCount,
    Value<int>? createdAt,
    Value<int>? updatedAt,
    Value<String?>? invoiceJson,
    Value<String?>? extractedJson,
    Value<String?>? failureKind,
    Value<int?>? savedAt,
    Value<int?>? remoteSyncedAt,
    Value<int?>? deletedAt,
    Value<int>? rowid,
  }) {
    return InvoiceRowsCompanion(
      id: id ?? this.id,
      status: status ?? this.status,
      imageNames: imageNames ?? this.imageNames,
      attemptCount: attemptCount ?? this.attemptCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      invoiceJson: invoiceJson ?? this.invoiceJson,
      extractedJson: extractedJson ?? this.extractedJson,
      failureKind: failureKind ?? this.failureKind,
      savedAt: savedAt ?? this.savedAt,
      remoteSyncedAt: remoteSyncedAt ?? this.remoteSyncedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (imageNames.present) {
      map['image_names'] = Variable<String>(imageNames.value);
    }
    if (attemptCount.present) {
      map['attempt_count'] = Variable<int>(attemptCount.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (invoiceJson.present) {
      map['invoice_json'] = Variable<String>(invoiceJson.value);
    }
    if (extractedJson.present) {
      map['extracted_json'] = Variable<String>(extractedJson.value);
    }
    if (failureKind.present) {
      map['failure_kind'] = Variable<String>(failureKind.value);
    }
    if (savedAt.present) {
      map['saved_at'] = Variable<int>(savedAt.value);
    }
    if (remoteSyncedAt.present) {
      map['remote_synced_at'] = Variable<int>(remoteSyncedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<int>(deletedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InvoiceRowsCompanion(')
          ..write('id: $id, ')
          ..write('status: $status, ')
          ..write('imageNames: $imageNames, ')
          ..write('attemptCount: $attemptCount, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('invoiceJson: $invoiceJson, ')
          ..write('extractedJson: $extractedJson, ')
          ..write('failureKind: $failureKind, ')
          ..write('savedAt: $savedAt, ')
          ..write('remoteSyncedAt: $remoteSyncedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $InvoiceRowsTable invoiceRows = $InvoiceRowsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [invoiceRows];
}

typedef $$InvoiceRowsTableCreateCompanionBuilder =
    InvoiceRowsCompanion Function({
      required String id,
      required String status,
      required String imageNames,
      required int attemptCount,
      required int createdAt,
      required int updatedAt,
      Value<String?> invoiceJson,
      Value<String?> extractedJson,
      Value<String?> failureKind,
      Value<int?> savedAt,
      Value<int?> remoteSyncedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });
typedef $$InvoiceRowsTableUpdateCompanionBuilder =
    InvoiceRowsCompanion Function({
      Value<String> id,
      Value<String> status,
      Value<String> imageNames,
      Value<int> attemptCount,
      Value<int> createdAt,
      Value<int> updatedAt,
      Value<String?> invoiceJson,
      Value<String?> extractedJson,
      Value<String?> failureKind,
      Value<int?> savedAt,
      Value<int?> remoteSyncedAt,
      Value<int?> deletedAt,
      Value<int> rowid,
    });

class $$InvoiceRowsTableFilterComposer
    extends Composer<_$AppDatabase, $InvoiceRowsTable> {
  $$InvoiceRowsTableFilterComposer({
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

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get imageNames => $composableBuilder(
    column: $table.imageNames,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get invoiceJson => $composableBuilder(
    column: $table.invoiceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get extractedJson => $composableBuilder(
    column: $table.extractedJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get failureKind => $composableBuilder(
    column: $table.failureKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get remoteSyncedAt => $composableBuilder(
    column: $table.remoteSyncedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InvoiceRowsTableOrderingComposer
    extends Composer<_$AppDatabase, $InvoiceRowsTable> {
  $$InvoiceRowsTableOrderingComposer({
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

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get imageNames => $composableBuilder(
    column: $table.imageNames,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get invoiceJson => $composableBuilder(
    column: $table.invoiceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get extractedJson => $composableBuilder(
    column: $table.extractedJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get failureKind => $composableBuilder(
    column: $table.failureKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get savedAt => $composableBuilder(
    column: $table.savedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get remoteSyncedAt => $composableBuilder(
    column: $table.remoteSyncedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InvoiceRowsTableAnnotationComposer
    extends Composer<_$AppDatabase, $InvoiceRowsTable> {
  $$InvoiceRowsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get imageNames => $composableBuilder(
    column: $table.imageNames,
    builder: (column) => column,
  );

  GeneratedColumn<int> get attemptCount => $composableBuilder(
    column: $table.attemptCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get invoiceJson => $composableBuilder(
    column: $table.invoiceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get extractedJson => $composableBuilder(
    column: $table.extractedJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get failureKind => $composableBuilder(
    column: $table.failureKind,
    builder: (column) => column,
  );

  GeneratedColumn<int> get savedAt =>
      $composableBuilder(column: $table.savedAt, builder: (column) => column);

  GeneratedColumn<int> get remoteSyncedAt => $composableBuilder(
    column: $table.remoteSyncedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);
}

class $$InvoiceRowsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InvoiceRowsTable,
          InvoiceRow,
          $$InvoiceRowsTableFilterComposer,
          $$InvoiceRowsTableOrderingComposer,
          $$InvoiceRowsTableAnnotationComposer,
          $$InvoiceRowsTableCreateCompanionBuilder,
          $$InvoiceRowsTableUpdateCompanionBuilder,
          (
            InvoiceRow,
            BaseReferences<_$AppDatabase, $InvoiceRowsTable, InvoiceRow>,
          ),
          InvoiceRow,
          PrefetchHooks Function()
        > {
  $$InvoiceRowsTableTableManager(_$AppDatabase db, $InvoiceRowsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InvoiceRowsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InvoiceRowsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InvoiceRowsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> imageNames = const Value.absent(),
                Value<int> attemptCount = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<String?> invoiceJson = const Value.absent(),
                Value<String?> extractedJson = const Value.absent(),
                Value<String?> failureKind = const Value.absent(),
                Value<int?> savedAt = const Value.absent(),
                Value<int?> remoteSyncedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvoiceRowsCompanion(
                id: id,
                status: status,
                imageNames: imageNames,
                attemptCount: attemptCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                invoiceJson: invoiceJson,
                extractedJson: extractedJson,
                failureKind: failureKind,
                savedAt: savedAt,
                remoteSyncedAt: remoteSyncedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String status,
                required String imageNames,
                required int attemptCount,
                required int createdAt,
                required int updatedAt,
                Value<String?> invoiceJson = const Value.absent(),
                Value<String?> extractedJson = const Value.absent(),
                Value<String?> failureKind = const Value.absent(),
                Value<int?> savedAt = const Value.absent(),
                Value<int?> remoteSyncedAt = const Value.absent(),
                Value<int?> deletedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => InvoiceRowsCompanion.insert(
                id: id,
                status: status,
                imageNames: imageNames,
                attemptCount: attemptCount,
                createdAt: createdAt,
                updatedAt: updatedAt,
                invoiceJson: invoiceJson,
                extractedJson: extractedJson,
                failureKind: failureKind,
                savedAt: savedAt,
                remoteSyncedAt: remoteSyncedAt,
                deletedAt: deletedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InvoiceRowsTable, InvoiceRow>(table),
                  BaseReferences<_$AppDatabase, $InvoiceRowsTable, InvoiceRow>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InvoiceRowsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InvoiceRowsTable,
      InvoiceRow,
      $$InvoiceRowsTableFilterComposer,
      $$InvoiceRowsTableOrderingComposer,
      $$InvoiceRowsTableAnnotationComposer,
      $$InvoiceRowsTableCreateCompanionBuilder,
      $$InvoiceRowsTableUpdateCompanionBuilder,
      (
        InvoiceRow,
        BaseReferences<_$AppDatabase, $InvoiceRowsTable, InvoiceRow>,
      ),
      InvoiceRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$InvoiceRowsTableTableManager get invoiceRows =>
      $$InvoiceRowsTableTableManager(_db, _db.invoiceRows);
}
