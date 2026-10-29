import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/auto_layout.dart';
import '../models/graph.dart';
import '../models/node_spec.dart';

class BlueprintResult {
  const BlueprintResult({this.graph, this.error, this.warnings = const []});

  /// 解析成功时非空。
  final NodeGraph? graph;

  /// 解析失败时的错误说明。
  final String? error;

  /// 解析过程中自动修正/忽略的内容。
  final List<String> warnings;

  bool get ok => graph != null;
}

/// 把「AI 返回的文本」变成可加载的节点图。
///
/// 设计目标是「尽量能用」：模型偶尔多写解释、漏掉开始节点、写错端口时，
/// 这里做提取、校验和自动修复，并把改动记录到 [BlueprintResult.warnings]。
class GraphBlueprint {
  static const int maxNodes = 60;
  static const int maxLinks = 160;

  /// 系统提示词：包含节点目录与连线的硬性规则。
  static String systemPrompt() {
    final zh = !L10n.isEnglish;
    final catalog = StringBuffer();
    for (final spec in NodeRegistry.all) {
      final inputs = spec.inputs.isEmpty
          ? '-'
          : spec.inputs
              .map((p) => '${p.id}(${p.type.name})')
              .join(', ');
      final outputs = spec.outputs.isEmpty
          ? '-'
          : spec.outputs.map((p) => '${p.id}(${p.type.name})').join(', ');
      final fields = spec.fields.isEmpty
          ? '-'
          : spec.fields
              .map((f) => '${f.id}(${f.kind.name}, 默认"${f.defaultValue}")')
              .join(', ');
      catalog.writeln(
          '- type: "${spec.type}" | 标题: ${spec.title} | 输入: $inputs | 输出: $outputs | 字段: $fields');
    }

    final rulesZh = '''
你是「Lua Node Studio」的节点图生成器。用户会用自然语言描述想要的小程序，你要输出一张可执行的节点图 JSON。

## 可用节点类型
$catalog
补充说明：
- type "func"（定义函数）的字段 params 填逗号分隔的参数名（如 "n" 或 "a, b"），保存后会自动生成 p0、p1… 数据输出端口，函数体内可用这些端口读取参数。
- type "call"（调用函数）有 arg1、arg2、arg3 三个数据输入端口，填多少用多少，从左往右；输出 ret 是函数返回值。字段 name 要和某个 func 节点的函数名一致。
- type "stop"（结束）的 value 输入用于 return 表达式。
- type "comment"（注释）只用于画布说明，不要连进执行流。

## 连线规则（很重要）
1. 必须且只能有 1 个 "start" 节点，整个执行流从它开始。
2. 端口类型 exec 表示执行流，只能 exec 输出 → exec 输入；其它类型是数据端口，只能数据输出 → 数据输入（any 可以和任何数据端口相连；number/string/boolean 之间不要混连）。
3. 每个执行输出最多 1 条出边；每个数据输入最多 1 条入边；数据输出可以接多个输入。
4. 分支汇合：if/for/while 的两条分支，把各自的 exec 输出都连到同一个下游节点的 in 端口（同一个 exec 输入允许多条入边），生成代码时会自动汇合。
5. 循环回边：for/while 的 body 执行输出可以连回它自己的 in 端口，表示循环体结束后继续下一轮。
6. 没有连线的数据输入用 literals 提供 Lua 表达式字符串：数字直接写 "5"，字符串要带引号写成 "\\"hello\\""，布尔写 "true"/"false"，变量名直接写 "sum"。
7. fields 只填需要覆盖默认值的字段，例如 assign 的 name、for 的 var、math 的 op、func 的 name/params。

## 输出格式
只输出一个 JSON 对象，不要 markdown 代码块，不要解释文字：
{"name":"图名","nodes":[{"id":"n1","type":"start","x":60,"y":100,"fields":{},"literals":{}}],"links":[{"from":"n1","fromPort":"out","to":"n2","toPort":"in"}]}
坐标从 (60,100) 开始：按执行流从左到右分列，列间距 340，同一列里的节点行间距 180，尽量避免重叠。
id 用 n1、n2… 保持唯一。''';

    final rulesEn = '''
You are the node-graph generator of "Lua Node Studio". The user describes a small program in natural language; you must output an executable node-graph JSON.

## Available node types
$catalog
Notes:
- "func" (define function) has a field params with comma-separated parameter names (e.g. "n" or "a, b"); data outputs p0, p1… become available inside the function body.
- "call" (call function) has data inputs arg1, arg2, arg3 (fill as many as needed, left to right) and output ret (return value). Field name must match a func node's name.
- "stop" (return) has a value input used as the return expression.
- "comment" is only for canvas notes; never connect it to the execution flow.

## Wiring rules (important)
1. Exactly one "start" node; the whole execution flow begins there.
2. Ports of type exec are execution flow: exec output -> exec input only. Other ports are data: data output -> data input (any connects to any data port; do not mix number/string/boolean).
3. Each exec output has at most 1 outgoing edge; each data input has at most 1 incoming edge; data outputs may fan out.
4. Branch merge: connect both branch exec outputs to the same downstream node's "in" port (multiple incoming edges to one exec input are allowed and merge automatically).
5. Loop back: a for/while body exec output may connect back to the loop node's own "in" port.
6. Unconnected data inputs use literals as Lua expressions: numbers "5", strings "\\"hi\\"", booleans "true"/"false", variables "sum".
7. fields only override defaults (assign.name, for.var, math.op, func.name/params, ...).

## Output format
Output a single JSON object, no markdown fences, no prose:
{"name":"graph name","nodes":[{"id":"n1","type":"start","x":60,"y":100,"fields":{},"literals":{}}],"links":[{"from":"n1","fromPort":"out","to":"n2","toPort":"in"}]}
Coordinates start at (60,100): columns left to right, 340 apart; 180 apart vertically; avoid overlaps. Keep ids unique (n1, n2, …).''';

    return zh ? rulesZh : rulesEn;
  }

  /// 解析模型返回的文本，成功时得到一张可加载的图。
  static BlueprintResult parse(String raw, {String name = ''}) {
    final warnings = <String>[];
    final jsonText = _extractJson(raw);
    if (jsonText == null) {
      return BlueprintResult(
        error: L10n.t('AI 的回复里没有找到 JSON 节点图，请再试一次',
            'No JSON graph found in the AI reply, please retry'),
      );
    }
    dynamic decoded;
    try {
      decoded = jsonDecode(jsonText);
    } catch (e) {
      return BlueprintResult(
          error: L10n.t('JSON 解析失败：$e', 'Failed to parse JSON: $e'));
    }
    if (decoded is! Map<String, dynamic>) {
      return BlueprintResult(
          error: L10n.t('AI 返回的不是 JSON 对象', 'AI reply is not a JSON object'));
    }
    final nodesJson = decoded['nodes'];
    final linksJson = decoded['links'];
    if (nodesJson is! List || nodesJson.isEmpty) {
      return BlueprintResult(
          error: L10n.t('AI 没有生成任何节点', 'The AI produced no nodes'));
    }
    final graphName = (decoded['name'] as String?)?.trim();
    final graph = NodeGraph(name: name.trim().isNotEmpty ? name.trim() : (graphName ?? ''));

    final usedIds = <String>{};
    var needsLayout = false;
    for (final item in nodesJson) {
      if (graph.nodes.length >= maxNodes) {
        warnings.add(L10n.t('节点数超过 $maxNodes 个，多余部分已忽略',
            'More than $maxNodes nodes, extra ones dropped'));
        break;
      }
      if (item is! Map) {
        warnings.add(L10n.t('忽略了一个格式不正确的节点', 'Dropped a malformed node'));
        continue;
      }
      final type = _asString(item['type']);
      if (type == null || !NodeRegistry.byType.containsKey(type)) {
        warnings.add(L10n.t('已忽略未知节点类型：$type',
            'Dropped unknown node type: $type'));
        continue;
      }
      var id = _asString(item['id'])?.trim() ?? '';
      if (id.isEmpty) id = 'n${graph.nodes.length + 1}';
      if (!usedIds.add(id)) {
        warnings.add(L10n.t('重复的节点 id：$id，已跳过',
            'Duplicate node id: $id, skipped'));
        continue;
      }
      final x = _asDouble(item['x']);
      final y = _asDouble(item['y']);
      if (x == null || y == null) needsLayout = true;
      graph.nodes.add(GraphNode(
        id: id,
        type: type,
        pos: Offset(x ?? 0, y ?? 0),
        fields: _stringMap(item['fields']),
        literals: _stringMap(item['literals']),
      ));
    }
    if (graph.nodes.isEmpty) {
      return BlueprintResult(
          error: L10n.t('AI 生成的节点都无法识别，请重试',
              'None of the generated nodes are usable, please retry'));
    }

    if (linksJson is List) {
      final known = {for (final n in graph.nodes) n.id: n};
      final dataInputs = <String>{};
      final execOutputs = <String>{};
      for (final item in linksJson) {
        if (graph.links.length >= maxLinks) {
          warnings.add(L10n.t('连线数超过 $maxLinks 条，多余部分已忽略',
              'More than $maxLinks links, extra ones dropped'));
          break;
        }
        if (item is! Map) continue;
        final from = _asString(item['from']);
        final to = _asString(item['to']);
        final fromPort = _asString(item['fromPort']);
        final toPort = _asString(item['toPort']);
        if (from == null || to == null || fromPort == null || toPort == null) {
          warnings.add(L10n.t('忽略了一条格式不正确的连线', 'Dropped a malformed link'));
          continue;
        }
        final fromNode = known[from];
        final toNode = known[to];
        if (fromNode == null || toNode == null) {
          warnings.add(L10n.t('连线指向不存在的节点：$from → $to',
              'Link points to a missing node: $from → $to'));
          continue;
        }
        final outSpec = fromNode.spec.outputById(fromPort);
        final inSpec = toNode.spec.inputById(toPort);
        if (outSpec == null || inSpec == null) {
          warnings.add(L10n.t('端口不存在：$from.$fromPort → $to.$toPort',
              'Port does not exist: $from.$fromPort → $to.$toPort'));
          continue;
        }
        final exec = outSpec.type.isExec;
        if (exec != inSpec.type.isExec) {
          warnings.add(L10n.t('执行流和数据线不能混连：$from.$fromPort → $to.$toPort',
              'Cannot mix exec and data ports: $from.$fromPort → $to.$toPort'));
          continue;
        }
        if (!exec && !_compatible(outSpec.type, inSpec.type)) {
          warnings.add(L10n.t('数据类型不匹配：$from.$fromPort → $to.$toPort',
              'Data type mismatch: $from.$fromPort → $to.$toPort'));
          continue;
        }
        if (exec) {
          if (!execOutputs.add('$from:$fromPort')) {
            warnings.add(L10n.t('执行输出只允许一条出边：$from.$fromPort',
                'An exec output can only have one outgoing edge: $from.$fromPort'));
            continue;
          }
        } else {
          if (!dataInputs.add('$to:$toPort')) {
            warnings.add(L10n.t('数据输入只能连一条线：$to.$toPort',
                'A data input can only have one incoming edge: $to.$toPort'));
            continue;
          }
        }
        graph.links.add(GraphLink(
          fromNode: from,
          fromPort: fromPort,
          toNode: to,
          toPort: toPort,
          isExec: exec,
        ));
      }
    }

    _ensureStart(graph, warnings, usedIds);

    if (needsLayout || _allAtOrigin(graph)) {
      applyAutoLayout(graph);
    }
    if (graph.name.trim().isEmpty) {
      graph.name = L10n.t('AI 生成的图', 'AI generated graph');
    }
    return BlueprintResult(graph: graph, warnings: warnings);
  }

  // ------------------------------------------------------------------ 内部

  static void _ensureStart(
      NodeGraph graph, List<String> warnings, Set<String> usedIds) {
    if (graph.startNode != null) return;
    var id = 'start';
    var i = 2;
    while (usedIds.contains(id)) {
      id = 'start$i';
      i++;
    }
    usedIds.add(id);
    final start = GraphNode(
        id: id, type: 'start', pos: const Offset(40, 80));
    graph.nodes.insert(0, start);
    // 找一个还没有执行流入边的节点，把开始节点的执行输出接过去。
    for (final node in graph.nodes) {
      if (node.id == start.id || node.type == 'start') continue;
      PortSpec? execIn;
      for (final p in node.spec.inputs) {
        if (p.type.isExec) {
          execIn = p;
          break;
        }
      }
      if (execIn == null) continue;
      final hasIncoming = graph.links
          .any((l) => l.toNode == node.id && l.toPort == execIn!.id && l.isExecFlow);
      if (hasIncoming) continue;
      graph.links.add(GraphLink(
        fromNode: start.id,
        fromPort: 'out',
        toNode: node.id,
        toPort: execIn.id,
        isExec: true,
      ));
      break;
    }
    warnings.add(L10n.t('AI 没有生成开始节点，已自动补上',
        'The AI omitted the Start node; one was added automatically'));
  }

  static bool _allAtOrigin(NodeGraph graph) =>
      graph.nodes.length > 1 &&
      graph.nodes.every((n) => n.pos.dx == 0 && n.pos.dy == 0);

  static bool _compatible(PortType out, PortType input) {
    if (out == PortType.any || input == PortType.any) return true;
    return out == input;
  }

  static String? _extractJson(String raw) {
    final start = raw.indexOf('{');
    if (start < 0) return null;
    var depth = 0;
    var inString = false;
    var escaped = false;
    for (var i = start; i < raw.length; i++) {
      final ch = raw[i];
      if (inString) {
        if (escaped) {
          escaped = false;
        } else if (ch == '\\') {
          escaped = true;
        } else if (ch == '"') {
          inString = false;
        }
        continue;
      }
      if (ch == '"') {
        inString = true;
      } else if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) return raw.substring(start, i + 1);
      }
    }
    return null;
  }

  static String? _asString(Object? v) {
    if (v == null) return null;
    if (v is String) return v;
    if (v is num) {
      if (v is double && v == v.roundToDouble()) return v.toInt().toString();
      return v.toString();
    }
    if (v is bool) return v ? 'true' : 'false';
    return v.toString();
  }

  static double? _asDouble(Object? v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v);
    return null;
  }

  static Map<String, String> _stringMap(Object? v) {
    final result = <String, String>{};
    if (v is Map) {
      for (final entry in v.entries) {
        final key = entry.key.toString();
        final value = _asString(entry.value);
        if (value != null) result[key] = value;
      }
    }
    return result;
  }

  /// 给界面用：统计图大小。
  static String describe(NodeGraph graph) =>
      L10n.t('${graph.nodes.length} 个节点 · ${graph.links.length} 条连线',
          '${graph.nodes.length} nodes · ${graph.links.length} links');
}
