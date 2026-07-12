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
