import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:secret_diary/features/settings/settings_screen.dart';

import '../helpers/test_env.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  Future<void> pumpSettings(WidgetTester tester, TestEnv env) async {
    await tester.pumpWidget(ProviderScope(
      overrides: env.overrides,
      child: const MaterialApp(home: SettingsScreen()),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('키가 내장된 빌드는 AI 준비됨으로 표시된다', (tester) async {
    final env = TestEnv(apiKey: 'embedded-key');
    addTearDown(env.dispose);

    await pumpSettings(tester, env);

    expect(find.text('일기 친구가 함께하고 있어요'), findsOneWidget);
    // 키 입력칸은 존재하지 않는다 — 사용자에게 키가 노출되지 않는다.
    expect(find.byType(TextField), findsNothing);
    await TestEnv.unmount(tester);
  });

  testWidgets('인식기가 고장나도 AI 상태는 표시된다', (tester) async {
    final env =
        TestEnv(apiKey: 'embedded-key', recognizer: ThrowingRecognizer());
    addTearDown(env.dispose);

    await pumpSettings(tester, env);

    // downloadedModels()가 throw해도 AI/모델 상태는 정상 로딩되어야 한다.
    expect(find.text('일기 친구가 함께하고 있어요'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.textContaining('아직 내려받은 언어 모델이 없어요'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('아직 내려받은 언어 모델이 없어요'), findsOneWidget);
    await TestEnv.unmount(tester);
  });

  testWidgets('키 없는 빌드는 미준비로 표시된다', (tester) async {
    final env = TestEnv();
    addTearDown(env.dispose);

    await pumpSettings(tester, env);

    expect(find.text('이 빌드에는 AI가 준비되지 않았어요'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await TestEnv.unmount(tester);
  });
}
