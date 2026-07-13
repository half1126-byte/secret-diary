import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/script_fonts.dart';
import '../../core/widgets/paper_background.dart';
import '../../providers.dart';
import '../../services/ai/gemini_client.dart';
import 'language_model_sheet.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _aiReady = false;
  bool _testing = false;
  String _model = 'gemini-2.5-flash';
  List<String> _downloadedModels = const [];

  static const _models = ['gemini-2.5-flash', 'gemini-2.5-flash-lite'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = ref.read(settingsRepositoryProvider);
    final key = await settings.getGeminiApiKey();
    final model = await settings.getModel();
    // 인식기 플랫폼 오류가 키/모델 상태 표시까지 막지 않도록 분리.
    List<String> downloaded;
    try {
      downloaded = await ref.read(recognizerProvider).downloadedModels();
    } catch (_) {
      downloaded = const [];
    }
    if (!mounted) return;
    setState(() {
      _aiReady = key != null && key.isNotEmpty;
      _model = _models.contains(model) ? model : _models.first;
      _downloadedModels = downloaded;
    });
  }

  Future<void> _testConnection() async {
    setState(() => _testing = true);
    try {
      final settings = ref.read(settingsRepositoryProvider);
      final key = await settings.getGeminiApiKey() ?? '';
      await ref.read(geminiClientProvider).testConnection(
            apiKey: key,
            model: _model,
          );
      _showSnack('연결 성공! 이제 일기에 답장이 와요.');
    } on GeminiException catch (e) {
      _showSnack(switch (e.type) {
        GeminiErrorType.noApiKey => '이 빌드에는 AI가 준비되지 않았어요.',
        GeminiErrorType.invalidApiKey => 'AI 연결에 문제가 있어요. 앱 제작자에게 알려주세요.',
        GeminiErrorType.rateLimited => '지금은 한도에 걸렸어요. 잠시 후 다시 시도해 주세요.',
        _ => '연결하지 못했어요. 네트워크를 확인해 주세요.',
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: PaperBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            _sectionTitle('AI 답장'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _aiReady
                              ? Icons.auto_awesome
                              : Icons.hourglass_empty,
                          size: 18,
                          color: _aiReady ? Palette.sage : Palette.inkFaded,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _aiReady
                                ? '일기 친구가 함께하고 있어요'
                                : '이 빌드에는 AI가 준비되지 않았어요',
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _aiReady
                          ? '일기 끝에 마침표(.)를 찍으면 답장이 와요.'
                          : '앱을 빌드할 때 AI 키가 내장되지 않았어요.',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (_aiReady) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: !_testing ? _testConnection : null,
                        child: Text(_testing ? '확인 중…' : '연결 테스트'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text('AI 모델', style: theme.textTheme.bodyMedium),
                    ),
                    DropdownButton<String>(
                      value: _model,
                      underline: const SizedBox.shrink(),
                      items: [
                        for (final m in _models)
                          DropdownMenuItem(value: m, child: Text(m)),
                      ],
                      onChanged: (value) async {
                        if (value == null) return;
                        setState(() => _model = value);
                        await ref
                            .read(settingsRepositoryProvider)
                            .setModel(value);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('손글씨 인식 언어'),
            Card(
              child: Column(
                children: [
                  if (_downloadedModels.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        '아직 내려받은 언어 모델이 없어요.\n쓰기 화면에서 언어를 고르면 자동으로 준비돼요.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  for (final tag in _downloadedModels)
                    ListTile(
                      title: Text(
                        ScriptFonts.supportedLanguages[tag] ?? tag,
                        style: ScriptFonts.styleFor(
                          tag,
                          base: const TextStyle(
                              fontSize: 18, color: Palette.ink),
                        ),
                      ),
                      subtitle: Text('내려받음 · 기기에서만 인식',
                          style: theme.textTheme.bodySmall),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Palette.inkFaded),
                        onPressed: () async {
                          try {
                            await ref.read(recognizerProvider).deleteModel(tag);
                          } catch (_) {
                            _showSnack('모델을 지우지 못했어요.');
                          }
                          _load();
                        },
                      ),
                    ),
                  ListTile(
                    leading: const Icon(Icons.add, color: Palette.terracotta),
                    title: Text('언어 추가하기', style: theme.textTheme.bodyMedium),
                    onTap: () async {
                      final tag = await showLanguagePicker(context,
                          current: ref.read(languageTagProvider));
                      if (tag == null || !context.mounted) return;
                      try {
                        await ensureLanguageModel(
                            context, ref.read(recognizerProvider), tag);
                      } catch (_) {
                        _showSnack('언어 모델을 준비하지 못했어요.');
                      }
                      _load();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('프라이버시'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  '모든 일기와 대화는 이 기기 안에만 저장돼요.\n'
                  '손글씨 인식도 기기 안에서 이루어져요.\n'
                  'AI 답장을 쓸 때만 일기 내용이 Google Gemini로 전송돼요.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: '비밀 일기',
                ),
                child: Text('오픈소스 라이선스',
                    style: theme.textTheme.bodySmall),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8, top: 8),
        child: Text(title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Palette.inkFaded)),
      );
}
