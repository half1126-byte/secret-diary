import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_diary/data/db/app_database.dart';
import 'package:secret_diary/data/models/chat_message.dart';
import 'package:secret_diary/data/models/stroke.dart';
import 'package:secret_diary/data/repositories/diary_repository.dart';

void main() {
  late AppDatabase db;
  late DiaryRepository repo;

  setUp(() {
    db = AppDatabase.withExecutor(NativeDatabase.memory());
    repo = DiaryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('항목 생성 후 타임라인에 나타난다', () async {
    final entry = await repo.createEntry(languageTag: 'ko');

    final entries = await repo.watchEntries().first;
    expect(entries, hasLength(1));
    expect(entries.first.id, entry.id);
    expect(entries.first.languageTag, 'ko');
    expect(entries.first.title, isNull);
  });

  test('첫 사용자 메시지가 제목이 되고 손글씨가 보존된다', () async {
    final entry = await repo.createEntry(languageTag: 'ko');
    final strokes = [
      const DiaryStroke(points: [
        DiaryPoint(x: 1, y: 2, pressure: 0.5, t: 0),
        DiaryPoint(x: 3, y: 4, pressure: 0.7, t: 10),
      ]),
    ];

    await repo.appendMessage(
      entryId: entry.id,
      role: MessageRole.user,
      text: '오늘은 비가 와서 마음이 차분했다. 오랜만에 혼자 걷는 길이 좋았다.',
      strokes: strokes,
    );
    await repo.appendMessage(
      entryId: entry.id,
      role: MessageRole.ai,
      text: '비 오는 날의 산책, 참 좋지요.',
    );

    final saved = await repo.getEntry(entry.id);
    expect(saved!.title, '오늘은 비가 와서 마음이 차분했다. 오랜만에 혼자 걷는');
    expect(saved.title!.length, lessThanOrEqualTo(30));

    final messages = await repo.getMessages(entry.id);
    expect(messages, hasLength(2));
    expect(messages[0].role, MessageRole.user);
    expect(messages[0].strokes, hasLength(1));
    expect(messages[0].strokes![0].points, hasLength(2));
    expect(messages[1].role, MessageRole.ai);
    expect(messages[1].strokes, isNull);
  });

  test('제목이 이모지를 반으로 자르지 않는다', () async {
    final entry = await repo.createEntry(languageTag: 'ko');
    // 30번째 문자 경계에 서로게이트 페어(이모지)가 걸리는 텍스트.
    final text = '가' * 29 + '😊나머지 텍스트';
    await repo.appendMessage(
        entryId: entry.id, role: MessageRole.user, text: text);

    final saved = await repo.getEntry(entry.id);
    expect(saved!.title, '가' * 29 + '😊');
    // 잘린 제목에 깨진 서로게이트가 없어야 한다.
    expect(saved.title!.codeUnits.last, isNot(inInclusiveRange(0xD800, 0xDBFF)));
  });

  test('두 번째 사용자 메시지는 제목을 덮어쓰지 않는다', () async {
    final entry = await repo.createEntry(languageTag: 'en');
    await repo.appendMessage(
        entryId: entry.id, role: MessageRole.user, text: 'first note');
    await repo.appendMessage(
        entryId: entry.id, role: MessageRole.user, text: 'second note');

    final saved = await repo.getEntry(entry.id);
    expect(saved!.title, 'first note');
  });

  test('recentEntrySnippets가 최신 항목의 첫 사용자 텍스트를 준다', () async {
    for (var i = 0; i < 7; i++) {
      final entry = await repo.createEntry(languageTag: 'ko');
      await repo.appendMessage(
        entryId: entry.id,
        role: MessageRole.user,
        text: '일기 $i',
      );
      // updatedAt 정렬이 안정되도록 시간 차이를 둔다.
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }

    final snippets = await repo.recentEntrySnippets(limit: 5);
    expect(snippets, hasLength(5));
    expect(snippets.first.text, '일기 6');
  });

  test('손상된 잉크 JSON이 있어도 일기를 열 수 있다', () async {
    final entry = await repo.createEntry(languageTag: 'ko');
    // 과거 버그 등으로 손상된 행을 직접 삽입.
    await db.into(db.messages).insert(MessagesCompanion.insert(
          id: 'corrupt-1',
          entryId: entry.id,
          role: 'user',
          body: '손상된 메시지',
          strokesJson: const Value('{"s": [[[NaN'),
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ));

    final messages = await repo.getMessages(entry.id);
    expect(messages, hasLength(1));
    expect(messages.single.text, '손상된 메시지');
    expect(messages.single.strokes, isNull); // 잉크만 포기, 일기는 살린다.

    final streamed = await repo.watchMessages(entry.id).first;
    expect(streamed, hasLength(1));
  });

  test('watchMessages가 새 메시지를 스트림으로 반영한다', () async {
    final entry = await repo.createEntry(languageTag: 'ko');
    final stream = repo.watchMessages(entry.id);

    await repo.appendMessage(
        entryId: entry.id, role: MessageRole.user, text: '안녕');

    final messages = await stream.first;
    expect(messages, hasLength(1));
    expect(messages.single.text, '안녕');
  });
}
