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

  testWidgets('저장된 키가 있으면 연결됨으로 표시된다', (tester) async {
    final env = TestEnv(apiKey: 'saved-key');
    addTearDown(env.dispose);

    await pumpSettings(tester, env);

    expect(find.text('Gemini 키가 연결되어 있어요'), findsOneWidget);
    await TestEnv.unmount(tester);
  });

  testWidgets('인식기가 고장나도 키 상태는 표시된다', (tester) async {
    final env = TestEnv(apiKey: 'saved-key', recognizer: ThrowingRecognizer());
    addTearDown(env.dispose);

    await pumpSettings(tester, env);

    // downloadedModels()가 throw해도 키/모델 상태는 정상 로딩되어야 한다.
    expect(find.text('Gemini 키가 연결되어 있어요'), findsOneWidget);
    expect(find.textContaining('아직 내려받은 언어 모델이 없어요'), findsOneWidget);
    await TestEnv.unmount(tester);
  });

  testWidgets('키가 없으면 미연결로 표시된다', (tester) async {
    final env = TestEnv();
    addTearDown(env.dispose);

    await pumpSettings(tester, env);

    expect(find.text('Gemini 키가 아직 없어요'), findsOneWidget);
    await TestEnv.unmount(tester);
  });
}
