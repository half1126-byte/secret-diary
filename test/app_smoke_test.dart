import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secret_diary/app.dart';

void main() {
  testWidgets('앱이 홈 화면과 함께 뜬다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: SecretDiaryApp()));
    await tester.pump();
    expect(find.text('비밀 일기'), findsOneWidget);
  });
}
