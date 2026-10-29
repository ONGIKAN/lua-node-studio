import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../codegen/lua_generator.dart';
import '../engine/lua_engine.dart';
import '../l10n/l10n.dart';
import '../models/auto_layout.dart';
import '../models/graph.dart';
import '../models/node_spec.dart';
import '../samples/sample_graph.dart';
import '../storage/project_store.dart';

/// 画布/代码面板的刷新拆成三条独立的通知通道：
/// - 本类自身的 [notifyListeners]：只用于画布（位置、选中）
/// - [codeNotifier]：只有图结构变化时才重新生成，拖节点不会触发
/// - [runNotifier] / [statusNotifier]：运行结果
///
/// 之前拖动节点时每帧都重算 Lua 代码并重建代码面板，手机上会明显卡顿。
class GraphController extends ChangeNotifier {
  GraphController({LuaEngine? engine})
      : engine = engine ?? const DartLuaEngine() {
    _graph = buildSampleGraph();
    _regenerate();
    L10n.notifier.addListener(_onLanguageChanged);
  }

  /// 切换语言后重新生成代码（节点标题/警告文案会变），并刷新界面。
  void _onLanguageChanged() {
    _regenerate();
    notifyListeners();
  }

  final LuaEngine engine;
  final ProjectStore store = ProjectStore();

  final ValueNotifier<LuaGenResult?> codeNotifier = ValueNotifier(null);
  final ValueNotifier<LuaRunResult?> runNotifier = ValueNotifier(null);
  final ValueNotifier<String?> statusNotifier = ValueNotifier(null);

  /// 拖动节点时只动这一个计数器：画布重绘，但顶栏/代码面板都不重建。
  final ValueNotifier<int> layoutTick = ValueNotifier(0);

  late NodeGraph _graph;
  NodeGraph get graph => _graph;

  String? selectedNodeId;
  bool running = false;
  bool dirty = false;
  String? currentFileName;

  /// 兼容旧调用点
  LuaGenResult? get lastGen => codeNotifier.value;
  LuaRunResult? get lastRun => runNotifier.value;
  String? get statusMessage => statusNotifier.value;
  set statusMessage(String? v) => statusNotifier.value = v;

  final List<String> _undo = [];
  final List<String> _redo = [];
  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  int _idSeed = 0;
  Timer? _autosave;
  bool _dragSnapshotTaken = false;

  // ------------------------------------------------------------- 撤销栈

  /// 在会改变图结构的操作前调用
  void pushUndo() {
    _undo.add(jsonEncode(_graph.toJson()));
    if (_undo.length > 40) _undo.removeAt(0);
    _redo.clear();
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(jsonEncode(_graph.toJson()));
    final raw = _undo.removeLast();
    _graph = NodeGraph.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    selectedNodeId = null;
    _afterStructureChange(autosave: true);
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(jsonEncode(_graph.toJson()));
    final raw = _redo.removeLast();
    _graph = NodeGraph.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    selectedNodeId = null;
    _afterStructureChange(autosave: true);
  }

  void _afterStructureChange({bool autosave = true}) {
    _regenerate();
    dirty = true;
    notifyListeners();
    if (autosave) _scheduleAutosave();
  }

  // ------------------------------------------------------------- 图操作

  String _newId(String type) =>
      '${type}_${DateTime.now().millisecondsSinceEpoch % 100000}_${_idSeed++}';

  GraphNode addNode(String type, Offset pos) {
    pushUndo();
    final spec = NodeRegistry.of(type);
    final node = GraphNode(
      id: _newId(type),
      type: type,
      pos: pos,
      fields: {
        for (final f in spec.fields) f.id: f.defaultValue,
      },
    );
    _graph.nodes.add(node);
    selectedNodeId = node.id;
    _afterStructureChange();
    return node;
  }

  /// 拖动中调用：只更新坐标并刷新画布，不重算代码、不写盘。
  void moveNode(String id, Offset delta) {
    final n = _graph.byId(id);
    if (n == null) return;
    final size = n.size;
    var p = n.pos + delta;
    p = Offset(
      p.dx.clamp(0.0, 5000.0 - size.width),
      p.dy.clamp(0.0, 5000.0 - size.height),
    );
    n.pos = p;
    layoutTick.value++;
  }

  void beginNodeDrag() {
    if (_dragSnapshotTaken) return;
    _dragSnapshotTaken = true;
    pushUndo();
  }

  void endNodeDrag() {
    if (!_dragSnapshotTaken) return;
    _dragSnapshotTaken = false;
    dirty = true;
    _scheduleAutosave();
  }

  void duplicateNode(String id) {
    final n = _graph.byId(id);
    if (n == null) return;
    pushUndo();
    final copy =
        n.copyWith(id: _newId(n.type), pos: n.pos + const Offset(28, 28));
    _graph.nodes.add(copy);
    selectedNodeId = copy.id;
    _afterStructureChange();
  }

  void deleteNode(String id) {
    pushUndo();
    _graph.removeNode(id);
    if (selectedNodeId == id) selectedNodeId = null;
    _afterStructureChange();
  }

  void unlinkNode(String id) {
    pushUndo();
    _graph.links
        .removeWhere((l) => l.fromNode == id || l.toNode == id);
    _afterStructureChange();
  }

  void setField(String nodeId, String fieldId, String value) {
    final n = _graph.byId(nodeId);
    if (n == null) return;
    pushUndo();
    n.fields[fieldId] = value;
    _afterStructureChange();
  }

  void setLiteral(String nodeId, String portId, String value) {
    final n = _graph.byId(nodeId);
    if (n == null) return;
    pushUndo();
    n.literals[portId] = value;
    _afterStructureChange();
  }

  bool connect(String fromNode, String fromPort, String toNode, String toPort) {
    if (fromNode == toNode) return false;
    final src = _graph.byId(fromNode);
    final dst = _graph.byId(toNode);
    if (src == null || dst == null) return false;
    final outSpec = src.spec.outputById(fromPort);
    final inSpec = dst.spec.inputById(toPort);
    if (outSpec == null || inSpec == null) return false;
    if (outSpec.type.isExec != inSpec.type.isExec) return false;
    pushUndo();
    // exec 端口一对一；数据输入一对一
    if (outSpec.type.isExec) _graph.removeLinksFrom(fromNode, fromPort);
    _graph.removeLinksInto(toNode, toPort);
    _graph.links.add(GraphLink(
      fromNode: fromNode,
      fromPort: fromPort,
      toNode: toNode,
      toPort: toPort,
      isExec: outSpec.type.isExec,
    ));
    _afterStructureChange();
    return true;
  }

  void deleteLink(GraphLink link) {
    pushUndo();
    _graph.links.removeWhere((l) => l.sameTarget(link));
    _afterStructureChange();
  }

  void autoLayout() {
    pushUndo();
    applyAutoLayout(_graph);
    _afterStructureChange();
  }

  void selectNode(String? id) {
    selectedNodeId = id;
    notifyListeners();
  }

  // ------------------------------------------------------------- 生成/运行

  void _regenerate() {
    codeNotifier.value = LuaGenerator(_graph).generate();
  }

  Future<void> run() async {
    if (running) return;
    _regenerate();
    running = true;
    statusNotifier.value = null;
    notifyListeners();
    final sw = Stopwatch()..start();
    final code = lastGen?.code ?? '';
    final result = await engine.run(code);
    sw.stop();
    runNotifier.value = result;
    running = false;
    statusNotifier.value = result.success
        ? L10n.t('运行完成 · ${sw.elapsedMilliseconds}ms',
            'Finished · ${sw.elapsedMilliseconds}ms')
        : (result.timedOut
            ? L10n.t('执行超时', 'Timed out')
            : L10n.t('运行出错', 'Runtime error'));
    notifyListeners();
  }

  void clearRun() {
    runNotifier.value = null;
    statusNotifier.value = null;
    notifyListeners();
  }

  void loadSample() => loadGraph(buildSampleGraph());

  /// 载入任意一张图（内置示例、模板或外部来源）。
  void loadGraph(NodeGraph graph) {
    pushUndo();
    _graph = graph;
    if (_graph.startNode == null) {
      _graph.nodes.add(
          GraphNode(id: _newId('start'), type: 'start', pos: const Offset(60, 60)));
    }
    selectedNodeId = null;
    currentFileName = null;
    _afterStructureChange();
    dirty = false;
    notifyListeners();
  }

  void newGraph() {
    pushUndo();
    _graph = NodeGraph(name: L10n.t('未命名', 'Untitled'));
    _graph.nodes
        .add(GraphNode(id: 'start', type: 'start', pos: const Offset(60, 60)));
    selectedNodeId = null;
    currentFileName = null;
    _regenerate();
    dirty = false;
    notifyListeners();
  }

  void replaceGraph(NodeGraph g) {
    pushUndo();
    _graph = g;
    if (_graph.startNode == null) {
      _graph.nodes.add(
          GraphNode(id: _newId('start'), type: 'start', pos: const Offset(60, 60)));
    }
    selectedNodeId = null;
    _regenerate();
    notifyListeners();
  }

  void renameGraph(String name) {
    _graph.name = name;
    dirty = true;
    notifyListeners();
    _scheduleAutosave();
  }

  // ------------------------------------------------------------- 持久化

  void _scheduleAutosave() {
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 1200), () {
      store.save('__autosave', _graph).catchError((_) {});
    });
  }

  Future<void> saveAs(String name) async {
    if (_graph.name.trim().isEmpty ||
        _graph.name == L10n.t('未命名', 'Untitled')) {
      _graph.name = name;
    }
    await store.save(name, _graph);
    currentFileName = name;
    dirty = false;
    await store.registerProject(name, name: _graph.name);
    statusMessage = L10n.t('已保存到本地：$name', 'Saved locally: $name');
    notifyListeners();
  }

  Future<void> loadFile(String name) async {
    final g = await store.load(name);
    if (g == null) return;
    currentFileName = name;
    replaceGraph(g);
    dirty = false;
    await store.registerProject(name, name: g.name);
    statusMessage = L10n.t('已打开：$name', 'Opened: $name');
    notifyListeners();
  }

  Future<void> restoreAutosave() async {
    NodeGraph? g;
    try {
      g = await store.load('__autosave');
    } catch (_) {
      return;
    }
    if (g == null) return;
    _graph = g;
    _regenerate();
    notifyListeners();
  }

  @override
  void dispose() {
    L10n.notifier.removeListener(_onLanguageChanged);
    _autosave?.cancel();
    layoutTick.dispose();
    codeNotifier.dispose();
    runNotifier.dispose();
    statusNotifier.dispose();
    super.dispose();
  }
}
