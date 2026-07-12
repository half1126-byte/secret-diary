import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class Entries extends Table {
  TextColumn get id => text()();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get languageTag => text()();
  TextColumn get title => text().nullable()();
  TextColumn get mood => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Messages extends Table {
  TextColumn get id => text()();
  TextColumn get entryId => text().references(Entries, #id)();
  TextColumn get role => text()(); // 'user' | 'ai'
  TextColumn get body => text()();
  TextColumn get strokesJson => text().nullable()();
  IntColumn get createdAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

@DriftDatabase(tables: [Entries, Messages])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(driftDatabase(name: 'secret_diary'));

  /// 테스트용 인메모리 등 임의 executor 주입.
  AppDatabase.withExecutor(super.e);

  @override
  int get schemaVersion => 1;

  /// 최신 항목부터 정렬된 타임라인 스트림.
  Stream<List<Entry>> watchEntries() {
    return (select(entries)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)]))
        .watch();
  }

  Future<Entry?> getEntry(String id) =>
      (select(entries)..where((t) => t.id.equals(id))).getSingleOrNull();

  Stream<List<Message>> watchMessages(String entryId) {
    return (select(messages)
          ..where((t) => t.entryId.equals(entryId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  Future<List<Message>> getMessages(String entryId) {
    return (select(messages)
          ..where((t) => t.entryId.equals(entryId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .get();
  }

  /// AI 기억 블록용: 최근 항목들의 사용자 텍스트 스니펫.
  Future<List<Message>> firstUserMessagesOfRecentEntries(int limit) async {
    final recent = await (select(entries)
          ..orderBy([(t) => OrderingTerm.desc(t.updatedAt)])
          ..limit(limit))
        .get();
    final result = <Message>[];
    for (final e in recent) {
      final m = await (select(messages)
            ..where((t) => t.entryId.equals(e.id) & t.role.equals('user'))
            ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
            ..limit(1))
          .getSingleOrNull();
      if (m != null) result.add(m);
    }
    return result;
  }
}
