import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../state/graph_controller.dart';
import 'edit_dialogs.dart';

const Color kPanelBg = Color(0xFF141416);
const Color kMonoColor = Color(0xFFD6D6DE);

class OutputPanel extends StatefulWidget {
  final GraphController controller;
  const OutputPanel({super.key, required this.controller});

  @override
  State<OutputPanel> createState() => OutputPanelState();
}

class OutputPanelState extends State<OutputPanel> {
  int _tab = 0;
  String? _cachedCode;
  List<TextSpan> _cachedSpans = const [];

  GraphController get c => widget.controller;

  void switchTo(int i) {
    if (mounted) setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    // 只订阅代码/运行/状态，不订阅画布位置：拖节点时这里不重建
    return AnimatedBuilder(
      animation: Listenable.merge([
        c.codeNotifier,
        c.runNotifier,
        c.statusNotifier,
        L10n.listenable,
      ]),
      builder: (context, _) {
        final gen = c.lastGen;
        return Container(
          decoration: const BoxDecoration(
            color: kPanelBg,
            border: Border(top: BorderSide(color: Color(0xFF2E2E34))),
          ),
          child: Column(
            children: [
              _tabBar(),
              if (gen != null && gen.warnings.isNotEmpty && _tab == 0)
                _warnings(gen.warnings),
              Expanded(
                child: IndexedStack(
                  index: _tab,
                  children: [
                    _codeView(
                        gen?.code ?? L10n.t('-- 还没有内容', '-- No content yet')),
                    _consoleView(),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tabBar() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFF232327))),
      ),
      child: Row(
        children: [
          _tabBtn(L10n.t('Lua 代码', 'Lua code'), 0),
          _tabBtn(L10n.t('输出', 'Output'), 1,
              badge: c.lastRun?.success == false ? Colors.red : null),
          const Spacer(),
          if (_tab == 0)
            IconButton(
              tooltip: L10n.t('复制代码', 'Copy code'),
              icon: const Icon(Icons.copy_all_outlined, size: 17),
              onPressed: () {
                copyToClipboard(c.lastGen?.code ?? '');
                ScaffoldMessenger.of(context)
                  ..clearSnackBars()
                  ..showSnackBar(SnackBar(
                    content: Text(L10n.t('代码已复制', 'Code copied')),
                    duration: const Duration(seconds: 1),
                  ));
              },
            ),
          if (_tab == 1)
            IconButton(
              tooltip: L10n.t('清空', 'Clear'),
              icon: const Icon(Icons.delete_sweep_outlined, size: 17),
              onPressed: c.clearRun,
            ),
        ],
      ),
    );
  }

  Widget _tabBtn(String label, int i, {Color? badge}) {
    final active = _tab == i;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _tab = i),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? const Color(0xFF7AB8FF) : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                color:
                    active ? const Color(0xFFE8E8EE) : const Color(0xFF8A8A94),
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
            if (badge != null) ...[
              const SizedBox(width: 4),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: badge, shape: BoxShape.circle),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _warnings(List<String> warnings) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      color: const Color(0x22FFB86C),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final w in warnings.take(3))
            Text('⚠ $w',
                style:
                    const TextStyle(fontSize: 10.5, color: Color(0xFFFFC178))),
        ],
      ),
    );
  }

  Widget _codeView(String code) {
    if (code != _cachedCode) {
      _cachedCode = code;
      _cachedSpans = _highlightWithNumbers(code);
    }
    return Scrollbar(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SelectableText.rich(
            TextSpan(children: _cachedSpans),
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              height: 1.5,
              color: kMonoColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _consoleView() {
    final run = c.lastRun;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                run == null
                    ? Icons.terminal
                    : (run.success
                        ? Icons.check_circle_outline
                        : Icons.error_outline),
                size: 14,
                color: run == null
                    ? const Color(0xFF8A8A94)
                    : (run.success
                        ? const Color(0xFF6FE08A)
                        : const Color(0xFFE06C6C)),
              ),
              const SizedBox(width: 6),
              Text(
                c.statusMessage ?? L10n.t('尚未运行', 'Not run yet'),
                style: const TextStyle(fontSize: 11, color: Color(0xFF9A9AA4)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (run == null)
            Text(
              L10n.t(
                '点右上角的 ▶ 运行生成的 Lua 脚本。\n输出里的每一次 print 都会显示在这里。',
                'Click ▶ in the top-right corner to run the generated Lua script.\n'
                    'Every print from the output will show up here.',
              ),
              style: const TextStyle(
                  fontSize: 11.5, color: Color(0xFF6E6E78), height: 1.6),
            )
          else ...[
            if (run.output.isNotEmpty)
              SelectableText(
                run.output,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.5,
                  color: kMonoColor,
                ),
              ),
            if (run.error != null) ...[
              const SizedBox(height: 8),
              Text(
                run.error!,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  height: 1.5,
                  color: Color(0xFFE58A8A),
                ),
              ),
            ],
            if (run.output.isEmpty && run.error == null)
              Text(L10n.t('（没有任何输出）', '(no output)'),
                  style: const TextStyle(
                      fontSize: 11.5, color: Color(0xFF6E6E78))),
          ],
        ],
      ),
    );
  }
}

// ------------------------------------------------------------- 语法高亮

final RegExp _tokenRe = RegExp(
  r"(--\[\[[\s\S]*?\]\]|--[^\n]*)"
  r"|('[^'\n]*'|\x22[^\x22\n]*\x22)"
  r"|(\b0[xX][0-9a-fA-F]+\b|\b\d+(?:\.\d+)?(?:[eE][+-]?\d+)?\b)"
  r"|(\b(?:local|function|then|elseif|else|end|for|while|do|return|if|not|and|or|in|break|repeat|until)\b)"
  r"|(\b(?:true|false|nil)\b)"
  r"|([A-Za-z_]\w*)(?=\s*\()",
);

List<TextSpan> _highlightWithNumbers(String code) {
  final lines = code.split('\n');
  final spans = <TextSpan>[];
  final width = lines.length.toString().length.clamp(2, 4);
  for (var i = 0; i < lines.length; i++) {
    spans.add(TextSpan(
      text: '${(i + 1).toString().padLeft(width)} │ ',
      style: const TextStyle(color: Color(0xFF4A4A54)),
    ));
    spans.addAll(_highlightLine(lines[i]));
    spans.add(const TextSpan(text: '\n'));
  }
  return spans;
}

List<TextSpan> _highlightLine(String line) {
  final out = <TextSpan>[];
  var last = 0;
  for (final m in _tokenRe.allMatches(line)) {
    if (m.start > last) {
      out.add(TextSpan(text: line.substring(last, m.start)));
    }
    Color? color;
    if (m.group(1) != null) {
      color = const Color(0xFF5F7A5A);
    } else if (m.group(2) != null) {
      color = const Color(0xFFCE9178);
    } else if (m.group(3) != null) {
      color = const Color(0xFFB5CEA8);
    } else if (m.group(4) != null) {
      color = const Color(0xFFC586C0);
    } else if (m.group(5) != null) {
      color = const Color(0xFF569CD6);
    } else if (m.group(6) != null) {
      color = const Color(0xFFDCDCAA);
    }
    out.add(TextSpan(
      text: m.group(0),
      style: color == null ? null : TextStyle(color: color),
    ));
    last = m.end;
  }
  if (last < line.length) out.add(TextSpan(text: line.substring(last)));
  return out;
}
