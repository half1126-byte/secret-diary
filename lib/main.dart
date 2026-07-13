import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'coach/coach_app.dart';

/// 빌드 시 --dart-define=APP_MODE=coach 를 주면 팩폭상담소가 된다.
const _appMode = String.fromEnvironment('APP_MODE', defaultValue: 'reme');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko');
  runApp(ProviderScope(
    child: _appMode == 'coach' ? const CoachApp() : const SecretDiaryApp(),
  ));
}
