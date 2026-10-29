import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/graph.dart';
import '../models/node_spec.dart';
import '../state/graph_controller.dart';
import 'edit_dialogs.dart';
import 'node_widget.dart';
import 'palette_sheet.dart';

class PortRef {
  final String nodeId;
  final String portId;
  final bool isOutput;
  final Offset pos;
  final PortType type;
  const PortRef(this.nodeId, this.portId, this.isOutput, this.pos, this.type);

  bool get isExec => type.isExec;
}

enum _DragMode { none, canvas, node, port }

class NodeCanvas extends StatefulWidget {
  final GraphController controller;
  const NodeCanvas({super.key, required this.controller});

  @override
  State<NodeCanvas> createState() => NodeCanvasState();
}

/// 画布的所有手势都在这里收敛处理。
///
/// 只有一套识别器（scale 家族，单指即平移），按下时按几何位置判定意图：
/// 最近端口 > 节点本体 > 空白画布。这样端口 44dp 热区重叠也不会连错端口，
/// 拖节点和拖画布也不会互相抢。
class NodeCanvasState extends State<NodeCanvas> {
  static const Size _canvasSize = Size(5200, 5200);
  static const double _minScale = 0.35;
  static const double _maxScale = 2.2;

  final GlobalKey _viewportKey = GlobalKey();

  double _scale = 1;
  Offset _offset = const Offset(30, 30);

  // 手势状态
  _DragMode _mode = _DragMode.none;
  Offset _downCanvas = Offset.zero;
  Offset _lastFocal = Offset.zero;
  double _movedPx = 0;
  double _gestureStartScale = 1;
  Offset _gestureStartCanvasFocal = Offset.zero;

  // 拖拽连线
  PortRef? _dragOrigin;
  Offset? _pendingEnd;
  PortRef? _hover;

  // 点按连线
  PortRef? _tapLink;

  String? _dragNodeId;
  String? _pendingNodeId; // 手指落在控件上时记录所属节点，位移大就转为拖节点

  GraphController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => fitToContent());
  }

  // ------------------------------------------------------------- 坐标换算

  RenderBox? get _box {
    final ctx = _viewportKey.currentContext;
    if (ctx == null) return null;
    final ro = ctx.findRenderObject();
    return ro is RenderBox ? ro : null;
  }

  Offset _toCanvasLocal(Offset local) => (local - _offset) / _scale;

  Offset toCanvas(Offset global) {
    final box = _box;
    if (box == null) return global;
    return _toCanvasLocal(box.globalToLocal(global));
  }

  Offset _centerCanvas() {
    final box = _box;
    if (box == null) return Offset.zero;
    return (box.size.center(Offset.zero) - _offset) / _scale;
  }

  void fitToContent() {
    final box = _box;
    if (box == null) return;
    final nodes = c.graph.nodes;
    if (nodes.isEmpty) return;
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final n in nodes) {
      minX = math.min(minX, n.pos.dx);
      minY = math.min(minY, n.pos.dy);
      maxX = math.max(maxX, n.pos.dx + n.size.width);
      maxY = math.max(maxY, n.pos.dy + n.size.height);
    }
    final vp = box.size;
    final w = maxX - minX;
    final h = maxY - minY;
    // 手机上宁可保证可读性，也不要缩成一团
    final s = math.min(
      math.min(vp.width / (w + 120), vp.height / (h + 120)),
      1.0,
    ).clamp(0.55, 1.0);
    const double topInset = 66;
    final dx = w * s > vp.width - 48
        ? 24 - minX * s
        : vp.width / 2 - (minX + w / 2) * s;
    final dy = h * s > vp.height - topInset - 24
        ? topInset - minY * s
        : (vp.height + topInset) / 2 - (minY + h / 2) * s;
    setState(() {
      _scale = s;
      _offset = Offset(dx, dy);
    });
  }

  void zoomBy(double factor) {
    final box = _box;
    if (box == null) return;
    final vpCenter = box.size.center(Offset.zero);
    final canvasCenter = (vpCenter - _offset) / _scale;
    final s = (_scale * factor).clamp(_minScale, _maxScale);
    setState(() {
      _scale = s;
      _offset = vpCenter - canvasCenter * s;
    });
  }

  // ------------------------------------------------------------- 命中判定

  double get _portRadius => 24 / _scale;

  /// 全局最近的端口（屏幕半径约 24dp）。[execFilter] 非空时只找同类端口。
  PortRef? nearestPort(Offset canvasPoint,
      {bool? execFilter, String? skipNode}) {
    final radius = _portRadius;
    PortRef? best;
    var bestD = radius;
    for (final n in c.graph.nodes) {
      if (n.id == skipNode) continue;
      final spec = n.spec;
      for (var i = 0; i < spec.inputs.length; i++) {
        final p = spec.inputs[i];
        if (execFilter != null && p.type.isExec != execFilter) continue;
        final pos = n.pos + NodeLayout.inputPortPos(spec, i);
        final d = (pos - canvasPoint).distance;
        if (d < bestD) {
          bestD = d;
          best = PortRef(n.id, p.id, false, pos, p.type);
        }
      }
      for (var i = 0; i < spec.outputs.length; i++) {
        final p = spec.outputs[i];
        if (execFilter != null && p.type.isExec != execFilter) continue;
        final pos = n.pos + NodeLayout.outputPortPos(spec, i);
        final d = (pos - canvasPoint).distance;
        if (d < bestD) {
          bestD = d;
          best = PortRef(n.id, p.id, true, pos, p.type);
        }
      }
    }
    return best;
  }

  GraphNode? _nodeAt(Offset canvasPoint) {
    for (var i = c.graph.nodes.length - 1; i >= 0; i--) {
      final n = c.graph.nodes[i];
      if ((n.pos & n.size).contains(canvasPoint)) return n;
    }
    return null;
  }

  GraphLink? _hitLink(Offset p) {
    final tol = math.max(16.0, 22 / _scale);
    for (final l in c.graph.links) {
      final a = c.graph.byId(l.fromNode);
      final b = c.graph.byId(l.toNode);
      if (a == null || b == null) continue;
      final p0 = a.pos + a.outputPortOffset(l.fromPort);
      final p1 = b.pos + b.inputPortOffset(l.toPort);
      for (var t = 0.0; t <= 1.0; t += 0.02) {
        if ((_bezierPoint(p0, p1, t) - p).distance < tol) return l;
      }
    }
    return null;
  }

  static Offset _bezierPoint(Offset a, Offset b, double t) {
    final k = math.max(36.0, (b.dx - a.dx).abs() * 0.55);
    final c1 = Offset(a.dx + k, a.dy);
    final c2 = Offset(b.dx - k, b.dy);
    final u = 1 - t;
    return a * (u * u * u) +
        c1 * (3 * u * u * t) +
        c2 * (3 * u * t * t) +
        b * (t * t * t);
  }

  // ------------------------------------------------------------- 手势

  void _onPointerDown(PointerDownEvent e) {
    _downCanvas = _toCanvasLocal(e.localPosition);
  }

  void _onScaleStart(ScaleStartDetails d) {
    _gestureStartScale = _scale;
    _gestureStartCanvasFocal = _toCanvasLocal(d.localFocalPoint);
    _lastFocal = d.localFocalPoint;
    _movedPx = 0;

    if (_tapLink != null) {
      _mode = _DragMode.canvas;
      return;
    }

    // 落在字段/取值 chip 上：不拖节点也不拖画布，松手时按点击处理
    if (_fieldAt(_downCanvas) != null || _literalAt(_downCanvas) != null) {
      _mode = _DragMode.none;
      _pendingNodeId = _nodeAt(_downCanvas)?.id;
      return;
    }

    final port = nearestPort(_downCanvas);
    if (port != null) {
      _mode = _DragMode.port;
      _dragOrigin = port;
      setState(() {
        _pendingEnd = port.pos;
        _hover = null;
      });
      return;
    }

    final node = _nodeAt(_downCanvas);
    if (node != null) {
      _mode = _DragMode.node;
      _dragNodeId = node.id;
      c.selectNode(node.id);
      c.beginNodeDrag();
      return;
    }

    _mode = _DragMode.canvas;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final deltaVec = d.localFocalPoint - _lastFocal;
    _movedPx += deltaVec.distance;
    _lastFocal = d.localFocalPoint;

    switch (_mode) {
      case _DragMode.canvas:
        final s = (_gestureStartScale * d.scale).clamp(_minScale, _maxScale);
        setState(() {
          _scale = s;
          _offset = d.localFocalPoint - _gestureStartCanvasFocal * s;
        });
      case _DragMode.node:
        if (d.pointerCount > 1) return; // 双指留给缩放
        final id = _dragNodeId;
        if (id != null) c.moveNode(id, deltaVec / _scale);
      case _DragMode.port:
        final p = _toCanvasLocal(d.localFocalPoint);
        setState(() {
          _pendingEnd = p;
          _hover = nearestPort(
            p,
            execFilter: _dragOrigin?.isExec,
            skipNode: _dragOrigin?.nodeId,
          );
        });
      case _DragMode.none:
        // 从控件上起手但明显在拖：转为移动节点，兼顾"点=编辑 / 拖=移动"
        if (_movedPx > 16 && _pendingNodeId != null) {
          _mode = _DragMode.node;
          _dragNodeId = _pendingNodeId;
          c.selectNode(_pendingNodeId!);
          c.beginNodeDrag();
          c.moveNode(_pendingNodeId!, deltaVec / _scale);
        }
    }
  }

  void _onScaleEnd(ScaleEndDetails d) {
    if (_mode == _DragMode.none && _movedPx * _scale < 14) {
      _handleTap(_downCanvas);
    } else if (_mode == _DragMode.port) {
      final origin = _dragOrigin;
      final target = _hover;
      if (origin != null && target != null) {
        if (origin.isOutput) {
          c.connect(origin.nodeId, origin.portId, target.nodeId, target.portId);
        } else {
          c.connect(target.nodeId, target.portId, origin.nodeId, origin.portId);
        }
      }
    } else if (_mode == _DragMode.node) {
      c.endNodeDrag();
    }
    _mode = _DragMode.none;
    _dragOrigin = null;
    _dragNodeId = null;
    _pendingNodeId = null;
    if (_pendingEnd != null || _hover != null) {
      setState(() {
        _pendingEnd = null;
        _hover = null;
      });
    }
  }

  void _onTapUp(TapUpDetails d) => _handleTap(_toCanvasLocal(d.localPosition));

  /// 所有"点一下"的意图都在这里分流：端口 > 字段 > 取值 chip > 节点 > 空白。
  /// 控件判定用几何区域，不依赖控件自身的手势，手指落点偏几个像素也不会漏。
  void _handleTap(Offset p) {
    final port = nearestPort(p);
    if (port != null) {
      _socketTap(port);
      return;
    }
    final field = _fieldAt(p);
    if (field != null) {
      _editField(field.node, field.id);
      return;
    }
    final lit = _literalAt(p);
    if (lit != null) {
      _editLiteral(lit.node, lit.id);
      return;
    }
    final node = _nodeAt(p);
    if (node != null) {
      c.selectNode(node.id);
      return;
    }
    if (_tapLink != null) {
      setState(() => _tapLink = null);
      return;
    }
    c.selectNode(null);
  }

  // --- 控件命中区域 ---

  ({GraphNode node, String id})? _fieldAt(Offset p) {
    for (var i = c.graph.nodes.length - 1; i >= 0; i--) {
      final n = c.graph.nodes[i];
      final spec = n.spec;
      if (spec.fields.isEmpty) continue;
      final local = p - n.pos;
      if (local.dx < 2 || local.dx > NodeLayout.width - 2) continue;
      final top = NodeLayout.fieldsTop(spec);
      final bottom = top + spec.fields.length * NodeLayout.fieldH;
      if (local.dy < top - 5 || local.dy > bottom + 5) continue;
      final idx = ((local.dy - top) / NodeLayout.fieldH)
          .floor()
          .clamp(0, spec.fields.length - 1);
      return (node: n, id: spec.fields[idx].id);
    }
    return null;
  }

  ({GraphNode node, String id})? _literalAt(Offset p) {
    for (var i = c.graph.nodes.length - 1; i >= 0; i--) {
      final n = c.graph.nodes[i];
      final spec = n.spec;
      final local = p - n.pos;
      if (local.dx < NodeLayout.width - 150 ||
          local.dx > NodeLayout.width - 2) {
        continue;
      }
      for (var r = 0; r < spec.inputs.length; r++) {
        final port = spec.inputs[r];
        if (port.type.isExec) continue;
        if ((local.dy - NodeLayout.rowCenterY(r)).abs() > 13) continue;
        return (node: n, id: port.id);
      }
    }
    return null;
  }

  void _editField(GraphNode node, String fieldId) {
    final f = node.spec.fields.firstWhere((e) => e.id == fieldId);
    editField(context, node.spec, f, node.field(fieldId), (v) {
      c.setField(node.id, fieldId, v);
    });
  }

  void _editLiteral(GraphNode node, String portId) {
    final p = node.spec.inputById(portId);
    if (p == null) return;
    if (c.graph.linkInto(node.id, portId) != null) {
      // 已连线的输入用的是上游的值，默认值此时无效，说清楚比默默无反应好
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('这个输入已经连线了，先断开连线才能改默认值'),
          duration: Duration(seconds: 2),
        ));
      return;
    }
    editLiteral(context, p, node.literal(portId), (v) {
      c.setLiteral(node.id, portId, v);
    });
  }

  Future<void> _onLongPress(LongPressStartDetails d) async {
    final p = toCanvas(d.globalPosition);
    if (nearestPort(p) != null) return;
    final link = _hitLink(p);
    if (link != null) {
      final ok = await confirm(context, '删除这条连线？');
      if (ok) c.deleteLink(link);
      return;
    }
    final node = _nodeAt(p);
    if (node != null) {
      await _nodeMenu(node);
      return;
    }
    _openPalette(p);
  }

  // --- 点按连线 ---

  void _socketTap(PortRef ref) {
    final start = _tapLink;
    if (start == null) {
      setState(() => _tapLink = ref);
      return;
    }
    if (start.nodeId == ref.nodeId && start.portId == ref.portId) {
      setState(() => _tapLink = null);
      return;
    }
    setState(() => _tapLink = null);

    final ok = start.isOutput
        ? c.connect(start.nodeId, start.portId, ref.nodeId, ref.portId)
        : c.connect(ref.nodeId, ref.portId, start.nodeId, start.portId);
    if (!ok) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(
          content: Text('这两个端口接不上：要「输出 → 输入」，执行流只连执行流'),
          duration: Duration(seconds: 2),
        ));
    }
  }

  /// 点按连线模式下，所有可接的端口位置
  List<Offset> _candidates() {
    final start = _tapLink;
    if (start == null) return const [];
    final out = <Offset>[];
    for (final n in c.graph.nodes) {
      if (n.id == start.nodeId) continue;
      final spec = n.spec;
      for (var i = 0; i < spec.inputs.length; i++) {
        if (spec.inputs[i].type.isExec == start.isExec) {
          out.add(n.pos + NodeLayout.inputPortPos(spec, i));
        }
      }
      for (var i = 0; i < spec.outputs.length; i++) {
        if (spec.outputs[i].type.isExec == start.isExec) {
          out.add(n.pos + NodeLayout.outputPortPos(spec, i));
        }
      }
    }
    return out;
  }

  void _openPalette(Offset canvasPos) {
    setState(() => _tapLink = null);
    showNodePalette(context, (spec) {
      final size = NodeLayout.sizeOf(spec);
      c.addNode(spec.type, canvasPos - Offset(size.width / 2, 18));
    });
  }

  void openPaletteAtCenter() => _openPalette(_centerCanvas());

  void autoLayout() {
    c.autoLayout();
    WidgetsBinding.instance.addPostFrameCallback((_) => fitToContent());
  }

  // ------------------------------------------------------------- 构建

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([c, c.layoutTick]),
      builder: (context, _) {
        final m = Matrix4.identity()
          ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
          ..scaleByDouble(_scale, _scale, 1, 1);
        final pad = NodeLayout.padOf(_scale);
        final candidates = _candidates();

        return ClipRect(
          key: _viewportKey,
          child: Listener(
            onPointerDown: _onPointerDown,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onScaleStart: _onScaleStart,
              onScaleUpdate: _onScaleUpdate,
              onScaleEnd: _onScaleEnd,
              onTapUp: _onTapUp,
              onLongPressStart: _onLongPress,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GridPainter(offset: _offset, scale: _scale),
                    ),
                  ),
                  Transform(
                    transform: m,
                    alignment: Alignment.topLeft,
                    child: SizedBox(
                      width: _canvasSize.width,
                      height: _canvasSize.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: CustomPaint(
                              painter: _LinkPainter(
                                graph: c.graph,
                                scale: _scale,
                                pendingFrom: _dragOrigin?.pos,
                                pendingTo: _pendingEnd,
                                hover: _hover,
                                tapSource: _tapLink?.pos,
                                candidates: candidates,
                              ),
                            ),
                          ),
                          for (final node in c.graph.nodes)
                            Positioned(
                              key: ValueKey('node_${node.id}'),
                              left: node.pos.dx - pad.dx,
                              top: node.pos.dy - pad.dy,
                              child: RepaintBoundary(
                                child: NodeWidget(
                                  node: node,
                                  scale: _scale,
                                  selected: c.selectedNodeId == node.id,
                                  linkMode: _tapLink != null &&
                                      _tapLink!.nodeId != node.id,
                                  linkOf: (portId, isOutput) => isOutput
                                      ? c.graph.linkFrom(node.id, portId)
                                      : c.graph.linkInto(node.id, portId),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(left: 10, top: 10, child: _toolbar()),
                  Positioned(right: 10, bottom: 12, child: _zoomControls()),
                  if (_tapLink != null)
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: _linkBanner(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xE6242429),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF35353C)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(Icons.add, '节点', openPaletteAtCenter, primary: true),
          _pill(Icons.auto_awesome_mosaic_outlined, '整理', autoLayout),
          _pill(Icons.fit_screen_outlined, '适应', fitToContent),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label, VoidCallback onTap,
      {bool primary = false}) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Icon(icon,
                size: 17,
                color: primary
                    ? const Color(0xFF7AB8FF)
                    : const Color(0xFFB9B9C4)),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                  fontSize: 12,
                  color: primary
                      ? const Color(0xFF7AB8FF)
                      : const Color(0xFFB9B9C4),
                )),
          ],
        ),
      ),
    );
  }

  Widget _linkBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xF02B3A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF3F6B4B)),
      ),
      child: Row(
        children: [
          const Icon(Icons.touch_app_outlined,
              size: 16, color: Color(0xFF6FE08A)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              '连线中：点绿圈里的端口完成连接，点空白取消',
              style: TextStyle(fontSize: 11.5, color: Color(0xFFCDEBD5)),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _tapLink = null),
            child: const Text('取消',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF6FE08A))),
          ),
        ],
      ),
    );
  }

  Widget _zoomControls() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xE6242429),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF35353C)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _roundBtn(Icons.add, () => zoomBy(1.3)),
          Container(height: 1, width: 20, color: const Color(0xFF35353C)),
          _roundBtn(Icons.remove, () => zoomBy(0.77)),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Icon(icon, size: 20, color: const Color(0xFFB9B9C4)),
      ),
    );
  }

  Future<void> _nodeMenu(GraphNode node) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF232327),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(node.spec.title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.copy_all_outlined, size: 20),
              title: const Text('复制节点'),
              onTap: () => Navigator.pop(ctx, 'dup'),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.link_off, size: 20),
              title: const Text('断开所有连线'),
              onTap: () => Navigator.pop(ctx, 'unlink'),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.delete_outline,
                  size: 20, color: Color(0xFFE06C6C)),
              title: const Text('删除节点',
                  style: TextStyle(color: Color(0xFFE06C6C))),
              onTap: () => Navigator.pop(ctx, 'del'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'dup':
        c.duplicateNode(node.id);
      case 'unlink':
        c.unlinkNode(node.id);
      case 'del':
        c.deleteNode(node.id);
    }
  }
}

// ---------------------------------------------------------------- 绘制

class _GridPainter extends CustomPainter {
  final Offset offset;
  final double scale;
  const _GridPainter({required this.offset, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF161619),
    );

    var step = 26.0;
    while (step * scale < 13) {
      step *= 4;
    }
    final s = step * scale;
    final dot = Paint()..color = const Color(0x14FFFFFF);
    final bigDot = Paint()..color = const Color(0x22FFFFFF);

    var x = offset.dx % s;
    var i = 0;
    while (x < size.width + s) {
      var y = offset.dy % s;
      var j = 0;
      while (y < size.height + s) {
        final isBig = (i % 5 == 0) && (j % 5 == 0);
        if (isBig) {
          canvas.drawCircle(Offset(x, y), 1.7, bigDot);
        } else if (s > 16) {
          canvas.drawCircle(Offset(x, y), 1.0, dot);
        }
        y += s;
        j++;
      }
      x += s;
      i++;
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.offset != offset || old.scale != scale;
}

class _LinkPainter extends CustomPainter {
  final NodeGraph graph;
  final double scale;
  final Offset? pendingFrom;
  final Offset? pendingTo;
  final PortRef? hover;
  final Offset? tapSource;
  final List<Offset> candidates;

  const _LinkPainter({
    required this.graph,
    required this.scale,
    this.pendingFrom,
    this.pendingTo,
    this.hover,
    this.tapSource,
    this.candidates = const [],
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final l in graph.links) {
      final a = graph.byId(l.fromNode);
      final b = graph.byId(l.toNode);
      if (a == null || b == null) continue;
      final spec = a.spec.outputById(l.fromPort);
      final color = spec?.type.color ?? const Color(0xFF9A9AA4);
      final p0 = a.pos + a.outputPortOffset(l.fromPort);
      final p1 = b.pos + b.inputPortOffset(l.toPort);
      _drawCurve(canvas, p0, p1, color, 2.2 / scale);
    }

    // 点按连线：高亮所有可接端口
    if (tapSource != null) {
      final ring = Paint()
        ..color = const Color(0xFF6FE08A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 / scale;
      for (final p in candidates) {
        canvas.drawCircle(
            p, 11 / scale, Paint()..color = const Color(0x336FE08A));
        canvas.drawCircle(p, 11 / scale, ring);
      }
      canvas.drawCircle(
        tapSource!,
        15 / scale,
        Paint()
          ..color = const Color(0xFF6FE08A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.6 / scale,
      );
    }

    if (pendingFrom != null && pendingTo != null) {
      final valid = hover != null;
      final color = valid ? const Color(0xFF6FE08A) : const Color(0xFF8A8A94);
      _drawCurve(canvas, pendingFrom!, pendingTo!, color, 2.0 / scale,
          dashed: true);
      if (valid) {
        canvas.drawCircle(
          hover!.pos,
          9 / scale,
          Paint()
            ..color = const Color(0x556FE08A)
            ..style = PaintingStyle.fill,
        );
        canvas.drawCircle(
          hover!.pos,
          9 / scale,
          Paint()
            ..color = const Color(0xFF6FE08A)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6 / scale,
        );
      }
    }
  }

  void _drawCurve(Canvas canvas, Offset a, Offset b, Color color, double width,
      {bool dashed = false}) {
    final k = math.max(36.0, (b.dx - a.dx).abs() * 0.55);
    final path = Path()
      ..moveTo(a.dx, a.dy)
      ..cubicTo(a.dx + k, a.dy, b.dx - k, b.dy, b.dx, b.dy);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;

    if (!dashed) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final seg =
            metric.extractPath(d, math.min(d + 7 / scale, metric.length));
        canvas.drawPath(seg, paint);
        d += 12 / scale;
      }
    }
  }

  @override
  bool shouldRepaint(_LinkPainter old) => true;
}
