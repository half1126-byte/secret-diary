import 'package:flutter/material.dart';

import '../../core/theme/palette.dart';
import '../../core/theme/script_fonts.dart';
import '../../services/handwriting/recognizer.dart';

/// 언어 모델 다운로드 시트.
///
/// 언어를 처음 선택할 때 온디바이스 인식 모델(~20MB)을 받는다.
/// 성공하면 true를 돌려주며 닫힌다.
Future<bool> ensureLanguageModel(
  BuildContext context,
  HandwritingRecognizer recognizer,
  String languageTag,
) async {
  if (await recognizer.isModelDownloaded(languageTag)) return true;
  if (!context.mounted) return false;

  final ok = await showModalBottomSheet<bool>(
    context: context,
    isDismissible: false,
    enableDrag: false,
    builder: (_) => _DownloadSheet(
      recognizer: recognizer,
      languageTag: languageTag,
    ),
  );
  return ok ?? false;
}

class _DownloadSheet extends StatefulWidget {
  const _DownloadSheet({required this.recognizer, required this.languageTag});

  final HandwritingRecognizer recognizer;
  final String languageTag;

  @override
  State<_DownloadSheet> createState() => _DownloadSheetState();
}

class _DownloadSheetState extends State<_DownloadSheet> {
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    setState(() => _failed = false);
    try {
      await widget.recognizer.downloadModel(widget.languageTag);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name =
        ScriptFonts.supportedLanguages[widget.languageTag] ?? widget.languageTag;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!_failed) ...[
              const SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Palette.terracotta,
                ),
              ),
              const SizedBox(height: 20),
              Text('$name 손글씨 모델을 준비하고 있어요',
                  style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '약 20MB를 한 번만 내려받아요. 이후에는 인터넷 없이도 인식돼요.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ] else ...[
              const Icon(Icons.cloud_off, size: 36, color: Palette.inkFaded),
              const SizedBox(height: 20),
              Text('모델을 내려받지 못했어요', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                '네트워크 연결을 확인하고 다시 시도해 주세요.',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('나중에'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _download,
                    style: FilledButton.styleFrom(
                      backgroundColor: Palette.terracotta,
                    ),
                    child: const Text('다시 시도'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 언어 선택 시트. 선택된 태그를 돌려준다 (취소 시 null).
Future<String?> showLanguagePicker(
  BuildContext context, {
  required String current,
}) {
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) {
      return ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            child: Text('어떤 언어로 쓸까요?',
                style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final entry in ScriptFonts.supportedLanguages.entries)
            ListTile(
              title: Text(
                entry.value,
                style: ScriptFonts.styleFor(
                  entry.key,
                  base: const TextStyle(fontSize: 20, color: Palette.ink),
                ),
              ),
              trailing: entry.key == current
                  ? const Icon(Icons.check, color: Palette.terracotta)
                  : null,
              onTap: () => Navigator.of(context).pop(entry.key),
            ),
        ],
      );
    },
  );
}
