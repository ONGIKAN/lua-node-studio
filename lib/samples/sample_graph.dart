import 'dart:ui';

import '../models/graph.dart';

/// 内置示例图：1 到 10 求和。
///
/// 生成的 Lua：
/// ```lua
/// local sum = 0
/// for i = 1, 10 do
///   sum = (sum + i)
/// end
/// print("sum =", sum)
/// ```
NodeGraph buildSampleGraph() {
  final g = NodeGraph(name: '示例：1 到 10 求和');

  GraphNode add(String id, String type, Offset pos,
      {Map<String, String>? fields, Map<String, String>? literals}) {
    final n = GraphNode(
        id: id, type: type, pos: pos, fields: fields, literals: literals);
    g.nodes.add(n);
    return n;
  }

  add('start', 'start', const Offset(40, 280));
  add('assign_sum', 'assign', const Offset(300, 280), fields: {'name': 'sum'});
  add('for1', 'for', const Offset(560, 250), fields: {'var': 'i'});
  add('assign_body', 'assign', const Offset(560, 520),
      fields: {'name': 'sum'});
  add('var_sum', 'var', const Offset(160, 600), fields: {'name': 'sum'});
  add('var_i', 'var', const Offset(160, 760), fields: {'name': 'i'});
  add('math_add', 'math', const Offset(380, 680), fields: {'op': '+'});
  add('print1', 'print', const Offset(880, 250),
      literals: {'value': '"sum =", sum'});

  void link(String from, String fromPort, String to, String toPort,
      {bool exec = false}) {
    g.links.add(GraphLink(
        fromNode: from,
        fromPort: fromPort,
        toNode: to,
        toPort: toPort,
        isExec: exec));
  }

  link('start', 'out', 'assign_sum', 'in', exec: true);
  link('assign_sum', 'out', 'for1', 'in', exec: true);
  link('for1', 'body', 'assign_body', 'in', exec: true);
  link('assign_body', 'out', 'for1', 'in', exec: true);
  link('for1', 'done', 'print1', 'in', exec: true);

  link('var_sum', 'value', 'math_add', 'a');
  link('var_i', 'value', 'math_add', 'b');
  link('math_add', 'result', 'assign_body', 'value');

  return g;
}
