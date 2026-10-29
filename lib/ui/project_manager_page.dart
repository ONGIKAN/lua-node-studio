import 'package:flutter/material.dart';

import '../ai/ai_chat_page.dart';
import '../l10n/l10n.dart';
import '../l10n/language_store.dart';
import '../samples/sample_catalog.dart';
import '../storage/project_store.dart';
import 'edit_dialogs.dart';
import 'editor_page.dart';

/// 默认首页：项目管理。
///
/// - 内置示例图（kSamples）直接列出来，点开即可进入编辑器
/// - 用户新建 / 导入 / 保存过的工程都会出现在「我的项目」里
/// - 上一次编辑的自动保存会显示成「继续编辑」卡片
class ProjectManagerPage extends StatefulWidget {
  const ProjectManagerPage({super.key, this.store});

  /// 注入 store 方便测试；默认使用真实本地目录。
  final ProjectStore? store;

  @override
  State<ProjectManagerPage> createState() => _ProjectManagerPageState();
}

class _ProjectManagerPageState extends State<ProjectManagerPage> {
  late final ProjectStore _store = widget.store ?? ProjectStore();

  List<ProjectInfo> _projects = const [];
  bool _hasAutosave = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    L10n.listenable.addListener(_onLanguageChanged);
    _reload();
  }

  void _onLanguageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    L10n.listenable.removeListener(_onLanguageChanged);
    super.dispose();
  }

  Future<void> _reload() async {
    try {
      final projects = await _store.listProjects();
      final autosave = await _store.hasAutosave();
      if (!mounted) return;
      setState(() {
        _projects = projects;
        _hasAutosave = autosave;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _reload();
  }

  void _openNew() => _open(const EditorPage(startBlank: true));

  /// 打开 AI 对话页：配置自定义 AI API 后，用自然语言生成节点图。
  void _openAiChat() => _open(AiChatPage(store: _store));

  void _openResume() => _open(const EditorPage());

  void _openSample(int index) =>
      _open(EditorPage(initialGraph: kSamples[index].build()));

  void _openProject(ProjectInfo p) =>
      _open(EditorPage(initialFileName: p.fileName));

  Future<void> _importJson() async {
    final result = await showDialog<_ImportResult>(
      context: context,
      builder: (ctx) => _ImportDialog(store: _store),
    );
    if (result == null) return;
    try {
      final fileName =
          await _store.importJson(result.json, name: result.name);
      await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(L10n.t('已导入工程：$fileName', 'Imported: $fileName')),
        ));
      await _open(EditorPage(initialFileName: fileName));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(L10n.t('导入失败：JSON 格式不正确', 'Import failed: invalid JSON')),
        ));
    }
  }

  Future<void> _rename(ProjectInfo p) async {
    final v = await showTextPrompt(
      context,
      title: L10n.t('重命名工程', 'Rename project'),
      initial: p.name,
      hint: L10n.t('新的名字', 'New name'),
    );
    if (v == null || v.trim().isEmpty) return;
    await _store.renameProject(p.fileName, v.trim());
    await _reload();
  }

  Future<void> _duplicate(ProjectInfo p) async {
    final g = await _store.load(p.fileName);
    if (g == null) return;
    final base = L10n.t('${p.name} 副本', '${p.name} copy');
    final copy = await _store.uniqueFileName(base);
    g.name = copy;
    await _store.save(copy, g);
    await _store.registerProject(copy, name: copy);
    await _reload();
  }

  Future<void> _delete(ProjectInfo p) async {
    final ok = await confirm(
      context,
      L10n.t('删除工程？', 'Delete project?'),
      message: L10n.t(
          '「${p.name}」的文件会从本地删除，无法恢复。',
          'The file for "${p.name}" will be deleted permanently.'),
      okLabel: L10n.t('删除', 'Delete'),
    );
    if (!ok) return;
    await _store.forgetProject(p.fileName);
    await _reload();
  }

  Future<void> _showLocation() async {
    final dir = await _store.directoryPath();
    if (!mounted) return;
    copyToClipboard(dir);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(L10n.t('工程目录已复制：$dir', 'Project folder copied: $dir')),
        duration: const Duration(seconds: 3),
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161619),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF6FE08A),
          backgroundColor: const Color(0xFF232327),
          onRefresh: _reload,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: [
              _header(),
              const SizedBox(height: 18),
              _heroCard(),
              if (_hasAutosave) ...[
                const SizedBox(height: 12),
                _resumeCard(),
              ],
              const SizedBox(height: 22),
              _sectionTitle(
                L10n.t('内置示例', 'Built-in samples'),
                subtitle: L10n.t('点开就能运行，不用先建项目',
                    'Open and run right away'),
              ),
              const SizedBox(height: 10),
              for (var i = 0; i < kSamples.length; i++)
                _sampleCard(i, kSamples[i]),
              const SizedBox(height: 22),
              _sectionTitle(
                L10n.t('我的项目', 'My projects'),
                subtitle: L10n.t('新建、导入、保存的工程都会在这里',
                    'Projects you create, import or save appear here'),
                trailing: Semantics(
                  label: L10n.t('刷新', 'Refresh'),
                  child: IconButton(
                    key: const ValueKey('pm-refresh'),
                    tooltip: L10n.t('刷新', 'Refresh'),
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    color: const Color(0xFF8A8A94),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else if (_error != null)
                _hintCard(
                  icon: Icons.error_outline,
                  title: L10n.t('读取工程列表失败', 'Failed to load projects'),
                  message: _error,
                )
              else if (_projects.isEmpty)
                _emptyProjectsCard()
              else
                for (final p in _projects) _projectCard(p),
              const SizedBox(height: 26),
              _footer(),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ 头部

  Widget _header() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1E4A30), Color(0xFF111118)],
            ),
            border: Border.all(color: const Color(0xFF2E2E38)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.asset(
            'assets/app_icon.png',
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const Icon(
              Icons.account_tree_rounded,
              color: Color(0xFF6FE08A),
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lua Node Studio',
                style: const TextStyle(
                    fontSize: 19, fontWeight: FontWeight.w700, height: 1.15),
              ),
              const SizedBox(height: 2),
              Text(
                L10n.t('拖拽节点，生成 Lua 代码', 'Drag nodes, generate Lua code'),
                style: const TextStyle(fontSize: 11.5, color: Color(0xFF8A8A94)),
              ),
            ],
          ),
        ),
        TextButton(
          key: const ValueKey('pm-lang'),
          onPressed: () => LanguageStore.apply(
              L10n.isEnglish ? AppLanguage.zh : AppLanguage.en),
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF9FB6E8),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 32),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            L10n.isEnglish ? '中文' : 'EN',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ),
        IconButton(
          key: const ValueKey('pm-info'),
          tooltip: L10n.t('关于', 'About'),
          onPressed: _showAbout,
          icon: const Icon(Icons.info_outline, size: 19),
          color: const Color(0xFF8A8A94),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  Widget _heroCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B3324), Color(0xFF1A1A22)],
        ),
        border: Border.all(color: const Color(0xFF2B3A30)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  L10n.t('把节点连成能跑的 Lua 程序', 'Turn nodes into runnable Lua'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, height: 1.25),
                ),
              ),
              const Icon(Icons.auto_awesome,
                  size: 18, color: Color(0xFF6FE08A)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            L10n.t('17 种节点 · 自定义函数 · 内置 Lua 5.3 运行时',
                '17 node types · user functions · built-in Lua 5.3 runtime'),
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF9A9AA4)),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const ValueKey('pm-new'),
                onPressed: _openNew,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(L10n.t('新建项目', 'New project')),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3F8F62),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  minimumSize: const Size(0, 40),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('pm-import'),
                onPressed: _importJson,
                icon: const Icon(Icons.file_download_outlined, size: 17),
                label: Text(L10n.t('导入 JSON', 'Import JSON')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB6C4DE),
                  side: const BorderSide(color: Color(0xFF3A3A46)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 40),
                ),
              ),
              OutlinedButton.icon(
                key: const ValueKey('pm-ai'),
                onPressed: _openAiChat,
                icon: const Icon(Icons.auto_awesome, size: 17),
                label: Text(L10n.t('AI 生成', 'Generate with AI')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF8FD9A8),
                  side: const BorderSide(color: Color(0xFF356B4C)),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  minimumSize: const Size(0, 40),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _showLocation,
            icon: const Icon(Icons.folder_open_rounded, size: 15),
            label: Text(
              L10n.t('查看工程文件夹', 'Open project folder'),
              style: const TextStyle(fontSize: 11.5),
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF7A8DAE),
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 26),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumeCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('pm-resume'),
        borderRadius: BorderRadius.circular(14),
        onTap: _openResume,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1D2430),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2C3A4E)),
          ),
          child: Row(
            children: [
              const Icon(Icons.restore_rounded,
                  size: 20, color: Color(0xFF7AB8FF)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.t('继续上次编辑', 'Continue where you left off'),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      L10n.t('上次退出前自动保存的工程',
                          'Auto-saved project from your last session'),
                      style: const TextStyle(
                          fontSize: 10.5, color: Color(0xFF8A9AB4)),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: Color(0xFF6E7E96)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title,
      {String? subtitle, Widget? trailing}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                    fontSize: 14.5, fontWeight: FontWeight.w700),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style:
                      const TextStyle(fontSize: 10.5, color: Color(0xFF7A7A84)),
                ),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _sampleCard(int index, SampleEntry sample) {
    const colors = [
      Color(0xFF6FD9A0),
      Color(0xFFC58CE0),
      Color(0xFF82B8F0),
      Color(0xFFE0B070),
      Color(0xFF9FB6E8),
    ];
    final accent = colors[index % colors.length];
    return _cardShell(
      key: ValueKey('pm-sample-$index'),
      onTap: () => _openSample(index),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: accent.withValues(alpha: 0.65)),
            ),
            child: Icon(
              [
                Icons.functions_rounded,
                Icons.calculate_outlined,
                Icons.timeline_rounded,
                Icons.rule_rounded,
                Icons.percent_rounded,
              ][index % 5],
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        sample.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF23232B),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: const Color(0xFF343440)),
                      ),
                      child: Text(
                        L10n.t('示例', 'Sample'),
                        style: const TextStyle(
                            fontSize: 9, color: Color(0xFF9A9AA4)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  sample.displayDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 10.5, color: Color(0xFF8A8A94), height: 1.35),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.terminal_rounded,
                        size: 11, color: Color(0xFF5E7A68)),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        sample.expectOutput.split('\n').first,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: Color(0xFF6F9B7E)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              size: 18, color: Color(0xFF5A5A66)),
        ],
      ),
    );
  }

  Widget _projectCard(ProjectInfo p) {
    return _cardShell(
      key: ValueKey('pm-project-${p.fileName}'),
      onTap: () => _openProject(p),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF232A38),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFF31405A)),
            ),
            child: const Icon(Icons.grid_view_rounded,
                size: 19, color: Color(0xFF7AB8FF)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  L10n.t('${p.nodeCount} 个节点 · ${_relativeTime(p.updatedAt)}',
                      '${p.nodeCount} nodes · ${_relativeTime(p.updatedAt)}'),
                  style: const TextStyle(
                      fontSize: 10.5, color: Color(0xFF8A8A94)),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, size: 17),
            padding: EdgeInsets.zero,
            color: const Color(0xFF26262B),
            onSelected: (v) {
              switch (v) {
                case 'rename':
                  _rename(p);
                case 'duplicate':
                  _duplicate(p);
                case 'delete':
                  _delete(p);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: 'rename',
                  child: Text(L10n.t('重命名', 'Rename'))),
              PopupMenuItem(
                  value: 'duplicate',
                  child: Text(L10n.t('创建副本', 'Duplicate'))),
              PopupMenuItem(
                  value: 'delete',
                  child: Text(L10n.t('删除', 'Delete'),
                      style: const TextStyle(color: Color(0xFFE06C6C)))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyProjectsCard() {
    return _hintCard(
      icon: Icons.folder_outlined,
      title: L10n.t('还没有自己的项目', 'No projects yet'),
      message: L10n.t(
          '点上面的「新建项目」从空白图开始，或者先打开一个内置示例。',
          'Tap "New project" above to start from a blank graph, or open a sample.'),
    );
  }

  Widget _hintCard(
      {required IconData icon, required String title, String? message}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A32)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: const Color(0xFF5A5A66)),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFFB8B8C2)),
          ),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 10.5, color: Color(0xFF7A7A84)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _cardShell(
      {required Key key, required VoidCallback onTap, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: key,
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E24),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2C2C34)),
            ),
            child: child,
          ),
        ),
      ),
    );
  }

  Widget _footer() {
    return Column(
      children: [
        Text(
          L10n.t(
              '本地存储 · 开源免费 · Android + Windows',
              'Stored locally · open source · Android + Windows'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Color(0xFF5E5E6A)),
        ),
        const SizedBox(height: 6),
        Text(
          'github.com/ONGIKAN/lua-node-studio',
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6E86B4),
              fontFamily: 'monospace'),
        ),
      ],
    );
  }

  String _relativeTime(DateTime t) {
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return L10n.t('刚刚', 'just now');
    if (diff.inHours < 1) {
      return L10n.t('${diff.inMinutes} 分钟前', '${diff.inMinutes} min ago');
    }
    if (diff.inDays < 1) {
      return L10n.t('${diff.inHours} 小时前', '${diff.inHours} h ago');
    }
    if (diff.inDays == 1) return L10n.t('昨天', 'yesterday');
    return L10n.t(
        '${t.month} 月 ${t.day} 日', '${t.month}/${t.day}');
  }

  Future<void> _showAbout() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.t('关于', 'About'),
            style: const TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lua Node Studio',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              L10n.t(
                  'Flutter 可视化节点编程编辑器：拖拽节点生成 Lua 5.3 代码，内置纯 Dart 运行时，支持 Android 与 Windows。',
                  'A Flutter visual node editor that generates Lua 5.3 code, with a built-in pure-Dart runtime for Android and Windows.'),
              style: const TextStyle(fontSize: 12, height: 1.45),
            ),
            const SizedBox(height: 10),
            SelectableText(
              'github.com/ONGIKAN/lua-node-studio',
              style: const TextStyle(
                  fontSize: 11.5,
                  fontFamily: 'monospace',
                  color: Color(0xFF7AB8FF)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              copyToClipboard('https://github.com/ONGIKAN/lua-node-studio');
              Navigator.pop(ctx);
            },
            child: Text(L10n.t('复制链接', 'Copy link')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.t('关闭', 'Close')),
          ),
        ],
      ),
    );
  }
}

class _ImportResult {
  const _ImportResult(this.json, this.name);
  final String json;
  final String? name;
}

class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.store});
  final ProjectStore store;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  final TextEditingController _json = TextEditingController();
  final TextEditingController _name = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _json.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(L10n.t('导入工程 JSON', 'Import project JSON'),
          style: const TextStyle(fontSize: 16)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              L10n.t('把工程 JSON 粘贴到这里（也可以先把 .json 文件放进工程文件夹再刷新列表）。',
                  'Paste project JSON here (or drop a .json file into the project folder and refresh).'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9A9AA4)),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('pm-import-json'),
              controller: _json,
              minLines: 5,
              maxLines: 9,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              decoration: InputDecoration(
                hintText: '{"name": "...", "nodes": [...], "links": [...]}',
                isDense: true,
                border: const OutlineInputBorder(),
                errorText: _error,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const ValueKey('pm-import-name'),
              controller: _name,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: L10n.t('工程名（可选）', 'Project name (optional)'),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(L10n.t('取消', 'Cancel'))),
        FilledButton(
          onPressed: _submit,
          child: Text(L10n.t('导入', 'Import')),
        ),
      ],
    );
  }

  void _submit() {
    final raw = _json.text.trim();
    if (raw.isEmpty) {
      setState(() => _error = L10n.t('请先粘贴 JSON', 'Paste JSON first'));
      return;
    }
    try {
      final decoded = raw;
      // 只做一次格式校验，真正的解析交给 store.importJson
      if (!decoded.startsWith('{')) {
        setState(() => _error = L10n.t('不是合法的 JSON 对象', 'Not a JSON object'));
        return;
      }
      Navigator.pop(
          context,
          _ImportResult(
              raw, _name.text.trim().isEmpty ? null : _name.text.trim()));
    } catch (_) {
      setState(() => _error = L10n.t('JSON 解析失败', 'Failed to parse JSON'));
    }
  }
}
