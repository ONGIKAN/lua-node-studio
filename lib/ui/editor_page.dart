import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../l10n/language_store.dart';
import '../models/graph.dart';
import '../state/graph_controller.dart';
import 'edit_dialogs.dart';
import 'node_canvas.dart';
import 'output_panel.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({
    super.key,
    this.controller,
    this.initialGraph,
    this.initialFileName,
    this.startBlank = false,
  });

  /// 外部注入的控制器（项目管理页可复用同一个实例）；为空时自己创建。
  final GraphController? controller;

  /// 用一张现成的图打开编辑器（内置示例、导入结果等）。
  final NodeGraph? initialGraph;

  /// 打开本地已保存的工程文件名。
  final String? initialFileName;

  /// 新建空白图。
  final bool startBlank;

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final GraphController c;
  late final bool _ownsController;
  final GlobalKey<NodeCanvasState> _canvasKey = GlobalKey<NodeCanvasState>();
  final GlobalKey<OutputPanelState> _panelKey = GlobalKey<OutputPanelState>();

  bool _showPanel = true;
  double? _panelH;

  @override
  void initState() {
    super.initState();
    c = widget.controller ?? GraphController();
    _ownsController = widget.controller == null;
    if (widget.startBlank) {
      c.newGraph();
    } else if (widget.initialFileName != null) {
      c.loadFile(widget.initialFileName!).then((_) {
        if (!mounted) return;
        WidgetsBinding.instance.addPostFrameCallback(
            (_) => _canvasKey.currentState?.fitToContent());
      });
    } else if (widget.initialGraph != null) {
      c.loadGraph(widget.initialGraph!);
      WidgetsBinding.instance.addPostFrameCallback(
          (_) => _canvasKey.currentState?.fitToContent());
    } else {
      c.restoreAutosave();
    }
  }

  @override
  void dispose() {
    if (_ownsController) c.dispose();
    super.dispose();
  }

  Future<void> _run() async {
    if (!_showPanel) setState(() => _showPanel = true);
    await c.run();
    _panelKey.currentState?.switchTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final panelH =
        (_panelH ?? math.min(h * 0.4, 380.0)).clamp(140.0, h * 0.72).toDouble();

    return Scaffold(
      backgroundColor: const Color(0xFF161619),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: AnimatedBuilder(
          animation: Listenable.merge([c, L10n.listenable]),
          builder: (context, _) => _appBar(),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: NodeCanvas(key: _canvasKey, controller: c)),
          if (_showPanel)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: (d) => setState(() {
                _panelH = (panelH - d.delta.dy).clamp(140.0, h * 0.72);
              }),
              child: Container(
                height: 16,
                color: const Color(0xFF1A1A1D),
                alignment: Alignment.center,
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E3E46),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          if (_showPanel)
            SizedBox(
              height: panelH,
              child: OutputPanel(key: _panelKey, controller: c),
            ),
        ],
      ),
    );
  }

  Widget _appBar() {
    final canPop = Navigator.of(context).canPop();
    return AppBar(
      backgroundColor: const Color(0xFF1D1D21),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: canPop
          ? IconButton(
              tooltip: L10n.t('返回项目列表', 'Back to projects'),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              onPressed: () => Navigator.of(context).maybePop(),
            )
          : null,
      titleSpacing: canPop ? 4 : 12,
      title: GestureDetector(
        onTap: _renameGraph,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    c.graph.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14.5, fontWeight: FontWeight.w600),
                  ),
                ),
                if (c.dirty)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Text('•',
                        style:
                            TextStyle(fontSize: 15, color: Color(0xFF7AB8FF))),
                  ),
              ],
            ),
            Text(
              '${c.engine.name} · ${c.engine.version}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 9, color: Color(0xFF7A7A84), height: 1.2),
            ),
          ],
        ),
      ),
      actions: [
        _iconBtn(Icons.undo_rounded, L10n.t('撤销', 'Undo'),
            c.canUndo ? c.undo : null),
        _iconBtn(Icons.redo_rounded, L10n.t('重做', 'Redo'),
            c.canRedo ? c.redo : null),
        if (c.running)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          IconButton(
            tooltip: L10n.t('运行', 'Run'),
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            color: const Color(0xFF6FE08A),
            visualDensity: VisualDensity.compact,
            onPressed: _run,
          ),
        _iconBtn(
          _showPanel ? Icons.vertical_split_outlined : Icons.terminal_outlined,
          _showPanel
              ? L10n.t('收起面板', 'Hide panel')
              : L10n.t('展开面板', 'Show panel'),
          () => setState(() => _showPanel = !_showPanel),
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 20),
          padding: EdgeInsets.zero,
          color: const Color(0xFF26262B),
          onSelected: (v) async {
            switch (v) {
              case 'new':
                c.newGraph();
                _canvasKey.currentState?.fitToContent();
              case 'sample':
                final entry = await showSamplePicker(context);
                if (entry != null) {
                  c.loadGraph(entry.build());
                  _canvasKey.currentState?.fitToContent();
                }
              case 'save':
                await _save();
              case 'open':
                await _open();
              case 'fit':
                _canvasKey.currentState?.fitToContent();
              case 'lang':
                await LanguageStore.apply(
                    L10n.isEnglish ? AppLanguage.zh : AppLanguage.en);
              case 'projects':
                Navigator.of(context).maybePop();
            }
          },
          itemBuilder: (ctx) => [
            if (canPop)
              PopupMenuItem(
                  value: 'projects',
                  child: Text(L10n.t('项目管理', 'Projects'))),
            PopupMenuItem(
                value: 'save', child: Text(L10n.t('保存工程', 'Save project'))),
            PopupMenuItem(
                value: 'open', child: Text(L10n.t('打开工程', 'Open project'))),
            PopupMenuItem(
                value: 'new',
                child: Text(L10n.t('新建空白图', 'New blank graph'))),
            PopupMenuItem(
                value: 'sample',
                child: Text(L10n.t('载入示例图', 'Load sample graph'))),
            PopupMenuItem(
                value: 'fit', child: Text(L10n.t('居中显示', 'Center view'))),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'lang',
              child: Row(
                children: [
                  const Icon(Icons.translate, size: 16),
                  const SizedBox(width: 8),
                  Text(L10n.isEnglish
                      ? '中文'
                      : 'English'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _iconBtn(IconData icon, String tip, VoidCallback? onTap) {
    return IconButton(
      tooltip: tip,
      icon: Icon(icon, size: 20),
      onPressed: onTap,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 38, minHeight: 40),
    );
  }

  Future<void> _renameGraph() async {
    final v = await showTextPrompt(context,
        title: L10n.t('工程名称', 'Project name'),
        initial: c.graph.name,
        hint: L10n.t('给这张图起个名字', 'Give this graph a name'));
    if (v != null && v.trim().isNotEmpty) c.renameGraph(v.trim());
  }

  Future<void> _save() async {
    final v = await showTextPrompt(context,
        title: L10n.t('保存工程', 'Save project'),
        initial: c.currentFileName ?? c.graph.name,
        hint: L10n.t('文件名', 'File name'));
    if (v == null || v.trim().isEmpty) return;
    await c.saveAs(v.trim());
    if (!mounted) return;
    final dir = await c.store.directoryPath();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(L10n.t('已保存：${v.trim()}\n$dir',
            'Saved: ${v.trim()}\n$dir')),
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _open() async {
    final names = await c.store.list();
    if (!mounted) return;
    if (names.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
            content:
                Text(L10n.t('还没有保存过任何工程', 'No saved projects yet'))));
      return;
    }
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(L10n.t('打开工程', 'Open project'),
            style: const TextStyle(fontSize: 15)),
        children: [
          for (final n in names)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, n),
              child: Row(
                children: [
                  const Icon(Icons.grid_view_rounded, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(n, overflow: TextOverflow.ellipsis)),
                ],
              ),
            ),
        ],
      ),
    );
    if (picked == null) return;
    await c.loadFile(picked);
    _canvasKey.currentState?.fitToContent();
  }
}
