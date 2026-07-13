import 'package:characters/characters.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../db/app_database.dart';
import '../models/chat_message.dart';
import '../models/diary_entry.dart';
import '../models/stroke.dart';

/// 과거 일기 스니펫 (AI 기억 블록용).
class EntrySnippet {
  const EntrySnippet({required this.date, required this.text});

  final DateTime date;
  final String text;
}

/// 일기·메시지 저장소. drift DB를 도메인 모델로 감싼다.
class DiaryRepository {
  DiaryRepository(this._db, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final AppDatabase _db;
  final Uuid _uuid;

  Stream<List<DiaryEntry>> watchEntries() =>
      _db.watchEntries().map((rows) => rows.map(_toEntry).toList());

  Future<DiaryEntry?> getEntry(String id) async {
    final row = await _db.getEntry(id);
    return row == null ? null : _toEntry(row);
  }

  /// 가장 최근에 수정된 항목 (오늘 일기 이어쓰기 판단용).
  Future<DiaryEntry?> latestEntry({EntryKind? kind}) async {
    final row = await _db.latestEntry(kind: kind?.dbValue);
    return row == null ? null : _toEntry(row);
  }

  /// 해당 월에 항목이 있는 날 → 그날의 항목들.
  Future<Map<int, List<DiaryEntry>>> entriesByDayInMonth(
      DateTime month) async {
    final from = DateTime(month.year, month.month, 1);
    final to = DateTime(month.year, month.month + 1, 1);
    final rows = await _db.entriesInRange(
        from.millisecondsSinceEpoch, to.millisecondsSinceEpoch);
    final map = <int, List<DiaryEntry>>{};
    for (final row in rows) {
      final entry = _toEntry(row);
      map.putIfAbsent(entry.createdAt.day, () => []).add(entry);
    }
    return map;
  }

  Stream<List<ChatMessage>> watchMessages(String entryId) =>
      _db.watchMessages(entryId).map((rows) => rows.map(_toMessage).toList());

  Future<List<ChatMessage>> getMessages(String entryId) async =>
      (await _db.getMessages(entryId)).map(_toMessage).toList();

  /// 새 항목을 만든다.
  Future<DiaryEntry> createEntry({
    required String languageTag,
    EntryKind kind = EntryKind.diary,
  }) async {
    final now = DateTime.now();
    final entry = DiaryEntry(
      id: _uuid.v4(),
      createdAt: now,
      updatedAt: now,
      languageTag: languageTag,
      kind: kind,
    );
    await _db.into(_db.entries).insert(EntriesCompanion.insert(
          id: entry.id,
          createdAt: now.millisecondsSinceEpoch,
          updatedAt: now.millisecondsSinceEpoch,
          languageTag: languageTag,
          kind: Value(kind.dbValue),
        ));
    return entry;
  }

  /// 메시지를 추가하고 항목의 updatedAt·title을 갱신한다.
  Future<ChatMessage> appendMessage({
    required String entryId,
    required MessageRole role,
    required String text,
    List<DiaryStroke>? strokes,
  }) async {
    final now = DateTime.now();
    final message = ChatMessage(
      id: _uuid.v4(),
      entryId: entryId,
      role: role,
      text: text,
      createdAt: now,
      strokes: strokes,
    );
    await _db.transaction(() async {
      await _db.into(_db.messages).insert(MessagesCompanion.insert(
            id: message.id,
            entryId: entryId,
            role: role.name,
            body: text,
            strokesJson: Value(
              strokes == null ? null : StrokeCodec.encode(strokes),
            ),
            createdAt: now.millisecondsSinceEpoch,
          ));

      final entry = await _db.getEntry(entryId);
      final needsTitle =
          entry != null && entry.title == null && role == MessageRole.user;
      await (_db.update(_db.entries)..where((t) => t.id.equals(entryId)))
          .write(EntriesCompanion(
        updatedAt: Value(now.millisecondsSinceEpoch),
        title: needsTitle ? Value(_titleFrom(text)) : const Value.absent(),
      ));
    });
    return message;
  }

  /// 항목의 첫 사용자 메시지 (잉크 썸네일용).
  Future<ChatMessage?> firstUserMessage(String entryId) async {
    final row = await _db.firstUserMessage(entryId);
    return row == null ? null : _toMessage(row);
  }

  /// AI 기억 블록용 최근 일기 스니펫 (최신순).
  Future<List<EntrySnippet>> recentEntrySnippets({int limit = 5}) async {
    final messages = await _db.firstUserMessagesOfRecentEntries(limit);
    return [
      for (final m in messages)
        EntrySnippet(
          date: DateTime.fromMillisecondsSinceEpoch(m.createdAt),
          text: _truncate(m.body, 200),
        ),
    ];
  }

  static String _titleFrom(String text) =>
      _truncate(text.split('\n').first.trim(), 30);

  /// 이모지(서로게이트 페어)를 반으로 자르지 않도록 grapheme 단위로 자른다.
  static String _truncate(String text, int max) =>
      text.characters.length > max
          ? text.characters.take(max).toString()
          : text;

  static DiaryEntry _toEntry(Entry row) => DiaryEntry(
        id: row.id,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(row.updatedAt),
        languageTag: row.languageTag,
        kind: EntryKind.fromDb(row.kind),
        title: row.title,
        mood: row.mood,
      );

  static ChatMessage _toMessage(Message row) => ChatMessage(
        id: row.id,
        entryId: row.entryId,
        role: row.role == 'ai' ? MessageRole.ai : MessageRole.user,
        text: row.body,
        createdAt: DateTime.fromMillisecondsSinceEpoch(row.createdAt),
        strokes: row.strokesJson == null ? null : _tryDecode(row.strokesJson!),
      );

  /// 손상된 잉크 JSON 한 건 때문에 일기 전체를 못 여는 일이 없도록
  /// 디코딩 실패는 잉크 없음으로 처리한다.
  static List<DiaryStroke>? _tryDecode(String json) {
    try {
      return StrokeCodec.decode(json);
    } catch (_) {
      return null;
    }
  }
}
