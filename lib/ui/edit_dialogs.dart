import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/l10n.dart';
import '../models/node_spec.dart';
import '../samples/sample_catalog.dart';

Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  String initial = '',
  String hint = '',
  bool mono = false,
  TextInputType? keyboardType,
}) {
  final ctrl = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 16)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        keyboardType: keyboardType,
        style: TextStyle(
          fontFamily: mono ? 'monospace' : null,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.t('取消', 'Cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: Text(L10n.t('确定', 'OK')),
        ),
      ],
    ),
  );
}

Future<void> editField(
  BuildContext context,
  NodeSpec spec,
  NodeField field,
  String current,
  void Function(String) onSave,
) async {
  if (field.kind == FieldKind.select && field.options.isNotEmpty) {
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(
            L10n.t('${field.label}（${spec.title}）',
                '${field.label} (${spec.title})'),
            style: const TextStyle(fontSize: 15)),
        children: [
          for (final opt in field.options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, opt),
              child: Row(
                children: [
                  Icon(
                    opt == current
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(opt, style: const TextStyle(fontFamily: 'monospace')),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked != null) onSave(picked);
    return;
  }

  final v = await showTextPrompt(
    context,
    title: field.label,
    initial: current,
    hint: field.hint,
    mono: true,
    keyboardType:
        field.kind == FieldKind.number ? TextInputType.number : TextInputType.text,
  );
  if (v != null) onSave(v);
}

Future<void> editLiteral(
  BuildContext context,
  PortSpec port,
  String current,
  void Function(String) onSave,
) async {
  final v = await showTextPrompt(
    context,
    title: L10n.t('${port.label}（Lua 表达式）', '${port.label} (Lua expression)'),
    initial: current,
    hint: L10n.t(
        '例如 42 / "文本" / sum / (a+b)', 'e.g. 42 / "text" / sum / (a+b)'),
    mono: true,
  );
  if (v != null && v.trim().isNotEmpty) onSave(v.trim());
}

Future<bool> confirm(
  BuildContext context,
  String title, {
  String? message,
  String? okLabel,
}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: const TextStyle(fontSize: 16)),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(L10n.t('取消', 'Cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okLabel ?? L10n.t('确定', 'OK'))),
      ],
    ),
  );
  return r ?? false;
}

void copyToClipboard(String text) {
  Clipboard.setData(ClipboardData(text: text));
}

/// 选择一张内置示例图（普通对话框，返回 null 表示取消）。
Future<SampleEntry?> showSamplePicker(BuildContext context) {
  return showDialog<SampleEntry>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(L10n.t('载入示例图', 'Load sample graph'),
          style: const TextStyle(fontSize: 16)),
      children: [
        for (final s in kSamples)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, s),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.displayTitle,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    s.displayDescription,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9A9AA4)),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}
