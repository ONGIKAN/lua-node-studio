import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../state/graph_controller.dart';
import 'edit_dialogs.dart';
import 'node_canvas.dart';
import 'output_panel.dart';

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final GraphController c = GraphController();
  final GlobalKey<NodeCanvasState> _canvasKey = GlobalKey<NodeCanvasState>();
  final GlobalKey<OutputPanelState> _panelKey = GlobalKey<OutputPanelState>();

  bool _showPanel = true;
  double? _panelH;

  @override
  void initState() {
    super.initState();
    c.restoreAutosave();
  }

  @override
  void dispose() {
    c.dispose();
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
          animation: c,
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
    return AppBar(
      backgroundColor: const Color(0xFF1D1D21),
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 12,
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
        _iconBtn(Icons.undo_rounded, '撤销', c.canUndo ? c.undo : null),
        _iconBtn(Icons.redo_rounded, '重做', c.canRedo ? c.redo : null),
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
            tooltip: '运行',
            icon: const Icon(Icons.play_arrow_rounded, size: 28),
            color: const Color(0xFF6FE08A),
            visualDensity: VisualDensity.compact,
            onPressed: _run,
          ),
        _iconBtn(
          _showPanel ? Icons.vertical_split_outlined : Icons.terminal_outlined,
          _showPanel ? '收起面板' : '展开面板',
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
                c.loadSample();
                _canvasKey.currentState?.fitToContent();
              case 'save':
                await _save();
              case 'open':
                await _open();
              case 'fit':
                _canvasKey.currentState?.fitToContent();
            }
          },
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'save', child: Text('保存工程')),
            PopupMenuItem(value: 'open', child: Text('打开工程')),
            PopupMenuItem(value: 'new', child: Text('新建空白图')),
            PopupMenuItem(value: 'sample', child: Text('载入示例图')),
            PopupMenuItem(value: 'fit', child: Text('居中显示')),
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
        title: '工程名称', initial: c.graph.name, hint: '给这张图起个名字');
    if (v != null && v.trim().isNotEmpty) c.renameGraph(v.trim());
  }

  Future<void> _save() async {
    final v = await showTextPrompt(context,
        title: '保存工程',
        initial: c.currentFileName ?? c.graph.name,
        hint: '文件名');
    if (v == null || v.trim().isEmpty) return;
    await c.saveAs(v.trim());
    if (!mounted) return;
    final dir = await c.store.directoryPath();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text('已保存：${v.trim()}\n$dir'),
        duration: const Duration(seconds: 2),
      ));
  }

  Future<void> _open() async {
    final names = await c.store.list();
    if (!mounted) return;
    if (names.isEmpty) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('还没有保存过任何工程')));
      return;
    }
    final picked = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('打开工程', style: TextStyle(fontSize: 15)),
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
