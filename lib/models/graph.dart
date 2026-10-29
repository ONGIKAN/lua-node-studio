import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'node_spec.dart';

/// 节点几何布局。全部解析式计算，方便端口命中测试与连线绘制。
class NodeLayout {
  static const double width = 212;
  static const double headerH = 34;
  static const double rowH = 26;
  static const double fieldH = 30;
  static const double bottomPad = 8;

  static Size sizeOf(NodeSpec spec) {
    final rows = math.max(spec.inputs.length, spec.outputs.length);
    final fields = spec.fields.length;
    var h = headerH + rows * rowH + bottomPad;
    if (fields > 0) {
      h += (rows > 0 ? 8 : 4) + fields * fieldH;
    }
    if (rows == 0 && fields == 0) h = headerH + 14;
    return Size(width, h);
  }

  static double rowCenterY(int index) => headerH + index * rowH + rowH / 2;

  /// 触摸热区（画布坐标）。保证换算到屏幕上始终约 44dp，缩小时自动放大。
  static const double touchTarget = 44;

  static double hitOf(double scale) =>
      (touchTarget / scale).clamp(26.0, 110.0);

  /// 节点外扩的触摸留白，让贴在节点边缘的端口也能点中。
  static Offset padOf(double scale) {
    final h = hitOf(scale) / 2;
    return Offset(h, math.max(9.0, h));
  }

  static Offset inputPortPos(NodeSpec spec, int index) =>
      Offset(0, rowCenterY(index));

  static Offset outputPortPos(NodeSpec spec, int index) =>
      Offset(width, rowCenterY(index));

  static double fieldsTop(NodeSpec spec) {
    final rows = math.max(spec.inputs.length, spec.outputs.length);
    return headerH + rows * rowH + (rows > 0 ? 8 : 4);
  }
}

class GraphNode {
  final String id;
  final String type;
  Offset pos;
  final Map<String, String> fields;
  final Map<String, String> literals;

  /// 「定义函数」节点的端口随字段变化，这里缓存最近一次算出的 spec。
  NodeSpec? _dynSpec;
  String? _dynSpecKey;

  GraphNode({
    required this.id,
    required this.type,
    required this.pos,
    Map<String, String>? fields,
    Map<String, String>? literals,
  })  : fields = fields ?? {},
        literals = literals ?? {};

  /// 节点对应的端口定义。
  ///
  /// 大多数节点类型是静态的；「定义函数」会把「参数」里的变量名展开成
  /// `p0..pN` 数据输出端口，好让函数体直接读到这些参数。
  NodeSpec get spec {
    final base = NodeRegistry.of(type);
    if (type != 'func') return base;
    final raw = fields['params'] ?? _defaultField('params');
    if (_dynSpec != null && _dynSpecKey == raw) return _dynSpec!;
    final params = parseParamNames(raw);
    _dynSpec = params.isEmpty
        ? base
        : NodeSpec(
            type: base.type,
            title: base.title,
            subtitle: base.subtitle,
            category: base.category,
            inputs: base.inputs,
            outputs: [
              ...base.outputs,
              for (var i = 0; i < params.length; i++)
                PortSpec('p$i', params[i], PortType.any),
            ],
            fields: base.fields,
          );
    _dynSpecKey = raw;
    return _dynSpec!;
  }

  Size get size => NodeLayout.sizeOf(spec);

  Offset get center => pos + Offset(size.width / 2, size.height / 2);

  String _defaultField(String id) {
    for (final f in NodeRegistry.of(type).fields) {
      if (f.id == id) return f.defaultValue;
    }
    return '';
  }

  String field(String id) {
    final f = fields[id];
    if (f != null) return f;
    return _defaultField(id);
  }

  String literal(String portId) {
    final l = literals[portId];
    if (l != null) return l;
    return NodeRegistry.of(type).inputById(portId)?.defaultLiteral ?? 'nil';
  }

  Offset inputPortOffset(String portId) {
    final i = spec.inputs.indexWhere((p) => p.id == portId);
    if (i < 0) return Offset.zero;
    return NodeLayout.inputPortPos(spec, i);
  }

  Offset inputPortPos(String portId) => pos + inputPortOffset(portId);

  Offset outputPortOffset(String portId) {
    final i = spec.outputs.indexWhere((p) => p.id == portId);
    if (i < 0) return Offset.zero;
    return NodeLayout.outputPortPos(spec, i);
  }

  Offset outputPortPos(String portId) => pos + outputPortOffset(portId);

  GraphNode copyWith({String? id, Offset? pos}) => GraphNode(
        id: id ?? this.id,
        type: type,
        pos: pos ?? this.pos,
        fields: Map.of(fields),
        literals: Map.of(literals),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'x': pos.dx,
        'y': pos.dy,
        'fields': fields,
        'literals': literals,
      };

  static GraphNode fromJson(Map<String, dynamic> j) => GraphNode(
        id: j['id'] as String,
        type: j['type'] as String,
        pos: Offset((j['x'] as num).toDouble(), (j['y'] as num).toDouble()),
        fields: Map<String, String>.from(
            (j['fields'] as Map?)?.cast<String, String>() ?? {}),
        literals: Map<String, String>.from(
            (j['literals'] as Map?)?.cast<String, String>() ?? {}),
      );
}

class GraphLink {
  final String fromNode;
  final String fromPort;
  final String toNode;
  final String toPort;
  bool isExecFlow = false;

  GraphLink({
    required this.fromNode,
    required this.fromPort,
    required this.toNode,
    required this.toPort,
    bool? isExec,
  }) {
    isExecFlow = isExec ?? false;
  }

  String get key => '$fromNode:$fromPort->$toNode:$toPort';

  bool sameTarget(GraphLink o) =>
      o.fromNode == fromNode &&
      o.fromPort == fromPort &&
      o.toNode == toNode &&
      o.toPort == toPort;

  Map<String, dynamic> toJson() => {
        'from': fromNode,
        'fromPort': fromPort,
        'to': toNode,
        'toPort': toPort,
        'exec': isExecFlow,
      };

  static GraphLink fromJson(Map<String, dynamic> j) => GraphLink(
        fromNode: j['from'] as String,
        fromPort: j['fromPort'] as String,
        toNode: j['to'] as String,
        toPort: j['toPort'] as String,
        isExec: j['exec'] as bool? ?? false,
      );
}

class NodeGraph {
  final List<GraphNode> nodes;
  final List<GraphLink> links;
  String name;

  NodeGraph({List<GraphNode>? nodes, List<GraphLink>? links, this.name = '未命名'})
      : nodes = nodes ?? [],
        links = links ?? [];

  GraphNode? byId(String? id) {
    if (id == null) return null;
    for (final n in nodes) {
      if (n.id == id) return n;
    }
    return null;
  }

  GraphNode? get startNode {
    for (final n in nodes) {
      if (n.type == 'start') return n;
    }
    return null;
  }

  GraphLink? linkInto(String nodeId, String portId) {
    for (final l in links) {
      if (l.toNode == nodeId && l.toPort == portId) return l;
    }
    return null;
  }

  GraphLink? linkFrom(String nodeId, String portId) {
    for (final l in links) {
      if (l.fromNode == nodeId && l.fromPort == portId) return l;
    }
    return null;
  }

  List<GraphLink> linksFromNode(String nodeId) =>
      links.where((l) => l.fromNode == nodeId).toList();

  /// 沿执行流走一步。
  String? nextExec(String nodeId, String portId) =>
      linkFrom(nodeId, portId)?.toNode;

  void removeNode(String id) {
    nodes.removeWhere((n) => n.id == id);
    links.removeWhere((l) => l.fromNode == id || l.toNode == id);
  }

  void removeLinksInto(String nodeId, String portId) {
    links.removeWhere((l) => l.toNode == nodeId && l.toPort == portId);
  }

  void removeLinksFrom(String nodeId, String portId) {
    links.removeWhere((l) => l.fromNode == nodeId && l.fromPort == portId);
  }

  NodeGraph clone() => NodeGraph(
        nodes: nodes.map((n) => n.copyWith()).toList(),
        links: links.map((l) => GraphLink.fromJson(l.toJson())).toList(),
        name: name,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'nodes': nodes.map((n) => n.toJson()).toList(),
        'links': links.map((l) => l.toJson()).toList(),
      };

  static NodeGraph fromJson(Map<String, dynamic> j) => NodeGraph(
        name: j['name'] as String? ?? '未命名',
        nodes: (j['nodes'] as List)
            .map((e) => GraphNode.fromJson(e as Map<String, dynamic>))
            .toList(),
        links: (j['links'] as List)
            .map((e) => GraphLink.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
