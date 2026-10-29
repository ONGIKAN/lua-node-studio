import '../models/graph.dart';
import '../models/node_spec.dart';

const Set<String> luaKeywords = {
  'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function',
  'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then',
  'true', 'until', 'while',
};

class LuaGenResult {
  final String code;
  final List<String> warnings;
  const LuaGenResult(this.code, this.warnings);
}

/// 把节点图编译成 Lua 源码。
///
/// 执行流（exec 端口）决定语句顺序；数据流（data 端口）递归展开成表达式。
/// 分支/循环的收口采用"汇合点"规则：两条分支链路上第一个共同节点即为 continue 点，
/// 因此不需要额外的 merge 节点。
class LuaGenerator {
  final NodeGraph graph;
  final StringBuffer _out = StringBuffer();
  final Set<String> _declared = {};
  final List<String> _warnings = [];
  int _indent = 0;
  int _budget = 4000;

  LuaGenerator(this.graph);

  LuaGenResult generate() {
    final start = graph.startNode;
    if (start == null) {
      return const LuaGenResult('-- 缺少「开始」节点，无法生成代码', []);
    }
    _out.writeln('-- 由 Lua Node Studio 自动生成');
    _out.writeln('-- 图名：${graph.name}');
    _out.writeln();
    _emitChain(start.id, <String>{});
    final code = _out.toString().trimRight();
    return LuaGenResult(code, List.unmodifiable(_warnings));
  }

  void _line(String s) {
    if (s.isEmpty) {
      _out.writeln();
      return;
    }
    _out.writeln('${'  ' * _indent}$s');
  }

  void _emitChain(String? nodeId, Set<String> guard, {String? stopAt}) {
    var cur = nodeId;
    while (cur != null && cur != stopAt) {
      if (_budget-- <= 0) {
        _warnings.add('语句数量超出上限，已截断');
        break;
      }
      if (guard.contains(cur)) {
        _warnings.add('检测到环路，已在节点 $cur 处停止');
        break;
      }
      guard.add(cur);
      final node = graph.byId(cur);
      if (node == null) break;
      cur = _emitNode(node, guard, stopAt);
    }
  }

  String? _emitNode(GraphNode node, Set<String> guard, String? stopAt) {
    switch (node.type) {
      case 'start':
        return graph.nextExec(node.id, 'out');
      case 'print':
        _line('print(${_expr(node, 'value')})');
        return graph.nextExec(node.id, 'out');
      case 'assign':
        final name = _ident(node.field('name'), 'x');
        final value = _expr(node, 'value');
        if (_declared.add(name)) {
          _line('local $name = $value');
        } else {
          _line('$name = $value');
        }
        return graph.nextExec(node.id, 'out');
      case 'call':
        final name = _ident(node.field('name'), 'myFunc');
        _line('$name()');
        return graph.nextExec(node.id, 'out');
      case 'stop':
        _line('return');
        return null;
      case 'comment':
        for (final l in node.field('text').split('\n')) {
          _line('-- $l');
        }
        return null;
      case 'if':
        return _emitIf(node, guard);
      case 'for':
        return _emitFor(node, guard);
      case 'while':
        return _emitWhile(node, guard);
      case 'func':
        return _emitFunc(node, guard);
      default:
        _warnings.add('「${node.spec.title}」不是语句节点，不能串在执行流上');
        return null;
    }
  }

  String? _emitIf(GraphNode node, Set<String> guard) {
    final cond = _expr(node, 'cond');
    final thenStart = graph.nextExec(node.id, 'then');
    final elseStart = graph.nextExec(node.id, 'else');
    final converge = _findConvergence(thenStart, elseStart);

    _line('if $cond then');
    _indent++;
    if (thenStart == null) {
      _line('-- 空分支');
    } else {
      _emitChain(thenStart, <String>{...guard}, stopAt: converge);
    }
    _indent--;
    if (elseStart != null) {
      _line('else');
      _indent++;
      _emitChain(elseStart, <String>{...guard}, stopAt: converge);
      _indent--;
    }
    _line('end');
    return converge;
  }

  String? _emitFor(GraphNode node, Set<String> guard) {
    final from = _expr(node, 'from');
    final to = _expr(node, 'to');
    final step = _expr(node, 'step');
    final varName = _ident(node.field('var'), 'i');
    final bodyStart = graph.nextExec(node.id, 'body');
    final doneStart = graph.nextExec(node.id, 'done');
    final converge = _convergeForLoop(node, bodyStart, doneStart);

    final head = (step == '1' || step.isEmpty)
        ? 'for $varName = $from, $to do'
        : 'for $varName = $from, $to, $step do';
    _line(head);
    _indent++;
    if (bodyStart == null) {
      _line('-- 空循环体');
    } else {
      _emitChain(bodyStart, <String>{...guard, node.id},
          stopAt: converge ?? node.id);
    }
    _indent--;
    _line('end');
    if (converge != null) return converge;
    if (doneStart != null) {
      _emitChain(doneStart, <String>{...guard, node.id});
    }
    return null;
  }

  String? _emitWhile(GraphNode node, Set<String> guard) {
    final cond = _expr(node, 'cond');
    final bodyStart = graph.nextExec(node.id, 'body');
    final doneStart = graph.nextExec(node.id, 'done');
    final converge = _convergeForLoop(node, bodyStart, doneStart);

    _line('while $cond do');
    _indent++;
    if (bodyStart == null) {
      _line('-- 空循环体');
    } else {
      _emitChain(bodyStart, <String>{...guard, node.id},
          stopAt: converge ?? node.id);
    }
    _indent--;
    _line('end');
    if (converge != null) return converge;
    if (doneStart != null) {
      _emitChain(doneStart, <String>{...guard, node.id});
    }
    return null;
  }

  String? _emitFunc(GraphNode node, Set<String> guard) {
    final name = _ident(node.field('name'), 'myFunc');
    final bodyStart = graph.nextExec(node.id, 'body');
    final doneStart = graph.nextExec(node.id, 'done');
    final converge = _convergeForLoop(node, bodyStart, doneStart);

    _declared.add(name);
    _line('local function $name()');
    _indent++;
    if (bodyStart == null) {
      _line('-- 空函数体');
    } else {
      _emitChain(bodyStart, <String>{...guard, node.id},
          stopAt: converge ?? node.id);
    }
    _indent--;
    _line('end');
    if (converge != null) return converge;
    if (doneStart != null) {
      _emitChain(doneStart, <String>{...guard, node.id});
    }
    return null;
  }

  /// 循环体/函数体如果"绕回自己"，说明用的是回环写法，此时不做汇合点分析，
  /// 结束端口之后的链路就是后续流程。
  String? _convergeForLoop(
      GraphNode node, String? bodyStart, String? doneStart) {
    if (bodyStart == null || doneStart == null) return null;
    if (_linearChain(bodyStart).contains(node.id)) return null;
    return _findConvergence(bodyStart, doneStart);
  }

  // ---------------------------------------------------------------- 数据流

  String _expr(GraphNode node, String portId, [int depth = 0]) {
    if (depth > 40) return 'nil';
    final link = graph.linkInto(node.id, portId);
    if (link == null) return node.literal(portId);
    final src = graph.byId(link.fromNode);
    if (src == null) return 'nil';
    return _exprOfOutput(src, link.fromPort, depth + 1);
  }

  String _exprOfOutput(GraphNode src, String portId, int depth) {
    if (depth > 40) {
      _warnings.add('数据链路过深或存在环，已在「${src.spec.title}」截断');
      return 'nil';
    }
    switch (src.type) {
      case 'number':
        return _number(src.field('value'));
      case 'text':
        return _luaString(src.field('value'));
      case 'bool':
        return src.field('value') == 'false' ? 'false' : 'true';
      case 'var':
        return _ident(src.field('name'), 'x');
      case 'math':
        final op = src.field('op');
        return '(${_expr(src, 'a', depth)} $op ${_expr(src, 'b', depth)})';
      case 'compare':
        final op = src.field('op');
        return '(${_expr(src, 'a', depth)} $op ${_expr(src, 'b', depth)})';
      case 'logic':
        final op = src.field('op');
        if (op == 'not') return '(not ${_expr(src, 'a', depth)})';
        return '(${_expr(src, 'a', depth)} $op ${_expr(src, 'b', depth)})';
      default:
        _warnings.add('「${src.spec.title}」没有可用的数据输出');
        return 'nil';
    }
  }

  String _number(String raw) {
    final v = raw.trim();
    if (v.isEmpty) return '0';
    if (double.tryParse(v) == null) {
      _warnings.add('数字节点内容「$v」不是合法数字，已按 0 处理');
      return '0';
    }
    return v;
  }

  String _luaString(String raw) {
    final escaped = raw
        .replaceAll('\\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
    return '"$escaped"';
  }

  String _ident(String raw, String fallback) {
    final v = raw.trim();
    if (v.isNotEmpty &&
        RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$').hasMatch(v) &&
        !luaKeywords.contains(v)) {
      return v;
    }
    _warnings.add('「$raw」不是合法 Lua 标识符，已替换为 $fallback');
    return fallback;
  }

  // -------------------------------------------------------------- 汇合检测

  String? _findConvergence(String? a, String? b) {
    if (a == null || b == null) return null;
    final chainA = _linearChain(a);
    final chainB = _linearChain(b).toSet();
    for (final id in chainA) {
      if (chainB.contains(id)) return id;
    }
    return null;
  }

  List<String> _linearChain(String? start) {
    final ids = <String>[];
    final seen = <String>{};
    var cur = start;
    while (cur != null && ids.length < 300) {
      if (!seen.add(cur)) break;
      ids.add(cur);
      final node = graph.byId(cur);
      if (node == null) break;
      cur = _firstExecOut(node);
    }
    return ids;
  }

  String? _firstExecOut(GraphNode node) {
    for (final p in const ['out', 'then', 'done', 'body', 'else']) {
      if (node.spec.outputById(p) != null) {
        final nx = graph.nextExec(node.id, p);
        if (nx != null) return nx;
      }
    }
    for (final p in node.spec.outputs) {
      if (p.type == PortType.exec) {
        final nx = graph.nextExec(node.id, p.id);
        if (nx != null) return nx;
      }
    }
    return null;
  }
}
