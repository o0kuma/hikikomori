import 'package:drift/drift.dart';

/// On-device tone / style samples (tech-design.md §2 — never upload the full corpus).
class ToneSamples extends Table {
  TextColumn get id => text()();
  TextColumn get sampleText => text()();
  IntColumn get createdAtMs => integer()();
  IntColumn get sortOrder => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Small key/value bag for onboarding flags and local prefs that must stay encrypted.
class LocalKv extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}
