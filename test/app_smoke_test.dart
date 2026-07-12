import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:secret_diary/app.dart';

import 'helpers/test_env.dart';

void main() {
  setUpAll(() => initializeDateFormatting('ko'));

  testWidgets('앱이 홈 화면과 함께 뜬다', (tester) async {
    final env = TestEnv();
    addTearDown(env.dispose);

    await tester.pumpWidget(ProviderScope(
      overrides: env.overrides,
      child: const SecretDiaryApp(),
    ));
    await tester.pump();

    expect(find.text('비밀 일기'), findsOneWidget);
    await TestEnv.unmount(tester);
  });
}
