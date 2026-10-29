import 'dart:ui';

import '../l10n/l10n.dart';
import '../models/graph.dart';

/// 手工摆放示例图的小工具。
///
/// 节点宽 212、表头 34、每行端口 26，下方还有参数行，坐标按这些几何量留白，
/// 保证节点之间不重叠（测试里有专门的防重叠断言）。
class SampleBuilder {
  SampleBuilder(String name) : graph = NodeGraph(name: name);

  final NodeGraph graph;

  GraphNode node(String id, String type, double x, double y,
      {Map<String, String>? fields, Map<String, String>? literals}) {
    final n = GraphNode(
      id: id,
      type: type,
      pos: Offset(x, y),
      fields: fields,
      literals: literals,
    );
    graph.nodes.add(n);
    return n;
  }

  void exec(String from, String fromPort, String to, String toPort) {
    graph.links.add(GraphLink(
      fromNode: from,
      fromPort: fromPort,
      toNode: to,
      toPort: toPort,
      isExec: true,
    ));
  }

  void data(String from, String fromPort, String to, String toPort) {
    graph.links.add(GraphLink(
      fromNode: from,
      fromPort: fromPort,
      toNode: to,
      toPort: toPort,
    ));
  }
}

/// 阶乘：演示「定义函数」带参数、函数体读参数、结束节点带返回值、调用带参数。
///
/// ```lua
/// local function factorial(n)
///   local r = 1
///   for i = 1, n do
///     r = (r * i)
///   end
///   return r
/// end
/// local __ret_0 = factorial(5)
/// print(("5! = " .. __ret_0))
/// ```
NodeGraph buildFactorialSample() {
  final b = SampleBuilder(L10n.t('示例：阶乘 factorial', 'Sample: factorial'));

  b.node('start', 'start', 40, 260);
  b.node('func', 'func', 320, 240,
      fields: {'name': 'factorial', 'params': 'n'});
  b.node('call', 'call', 620, 260,
      fields: {'name': 'factorial'}, literals: {'arg1': '5'});
  b.node('concat', 'math', 900, 300,
      fields: {'op': '..'}, literals: {'a': '"5! = "'});
  b.node('print1', 'print', 1180, 260);

  b.exec('start', 'out', 'func', 'in');
  b.exec('func', 'done', 'call', 'in');
  b.exec('call', 'out', 'print1', 'in');
  b.data('func', 'p0', 'for1', 'to');
  b.data('call', 'ret', 'concat', 'b');
  b.data('concat', 'result', 'print1', 'value');

  // ---- 函数体：r = 1; for i = 1..n do r = r * i end; return r
  b.node('assign_r', 'assign', 320, 760,
      fields: {'name': 'r'}, literals: {'value': '1'});
  b.node('for1', 'for', 620, 740, fields: {'var': 'i'});
  b.node('assign_mul', 'assign', 620, 1000, fields: {'name': 'r'});
  b.node('stop_ret', 'stop', 920, 760);

  b.exec('func', 'body', 'assign_r', 'in');
  b.exec('assign_r', 'out', 'for1', 'in');
  b.exec('for1', 'body', 'assign_mul', 'in');
  b.exec('assign_mul', 'out', 'for1', 'in'); // 循环体绕回循环
  b.exec('for1', 'done', 'stop_ret', 'in');

  b.node('math_mul', 'math', 320, 1000, fields: {'op': '*'});
  b.node('var_r', 'var', 40, 1130, fields: {'name': 'r'});
  b.node('var_i', 'var', 40, 990, fields: {'name': 'i'});
  b.data('var_r', 'value', 'math_mul', 'a');
  b.data('var_i', 'value', 'math_mul', 'b');
  b.data('math_mul', 'result', 'assign_mul', 'value');
  b.data('var_r', 'value', 'stop_ret', 'value');

  return b.graph;
}

/// 斐波那契：循环里维护 a、b 两个变量，返回第 n 项。
NodeGraph buildFibonacciSample() {
  final b = SampleBuilder(L10n.t('示例：斐波那契数列', 'Sample: Fibonacci'));

  b.node('start', 'start', 40, 260);
  b.node('func', 'func', 320, 240, fields: {'name': 'fib', 'params': 'n'});
  b.node('call', 'call', 620, 260,
      fields: {'name': 'fib'}, literals: {'arg1': '10'});
  b.node('concat', 'math', 900, 300,
      fields: {'op': '..'}, literals: {'a': '"fib(10) = "'});
  b.node('print1', 'print', 1180, 260);

  b.exec('start', 'out', 'func', 'in');
  b.exec('func', 'done', 'call', 'in');
  b.exec('call', 'out', 'print1', 'in');
  b.data('func', 'p0', 'for2', 'to');
  b.data('call', 'ret', 'concat', 'b');
  b.data('concat', 'result', 'print1', 'value');

  // ---- 函数体：a = 0; b = 1; for i = 1..n do t = a + b; a = b; b = t end; return a
  b.node('assign_a', 'assign', 320, 760,
      fields: {'name': 'a'}, literals: {'value': '0'});
  b.node('assign_b', 'assign', 620, 760,
      fields: {'name': 'b'}, literals: {'value': '1'});
  b.node('for2', 'for', 920, 740, fields: {'var': 'i'});
  b.node('stop_ret', 'stop', 1220, 760);

  b.exec('func', 'body', 'assign_a', 'in');
  b.exec('assign_a', 'out', 'assign_b', 'in');
  b.exec('assign_b', 'out', 'for2', 'in');
  b.exec('for2', 'body', 'assign_t', 'in');
  b.exec('assign_t', 'out', 'assign_a2', 'in');
  b.exec('assign_a2', 'out', 'assign_b2', 'in');
  b.exec('assign_b2', 'out', 'for2', 'in'); // 循环体绕回循环
  b.exec('for2', 'done', 'stop_ret', 'in');

  b.node('assign_t', 'assign', 920, 1000, fields: {'name': 't'});
  b.node('assign_a2', 'assign', 1220, 1000, fields: {'name': 'a'});
  b.node('assign_b2', 'assign', 1520, 1000, fields: {'name': 'b'});
  b.node('math_add', 'math', 620, 1250, fields: {'op': '+'});
  b.node('var_a', 'var', 40, 1250, fields: {'name': 'a'});
  b.node('var_b', 'var', 40, 1390, fields: {'name': 'b'});
  b.node('var_t', 'var', 40, 1530, fields: {'name': 't'});

  b.data('var_a', 'value', 'math_add', 'a');
  b.data('var_b', 'value', 'math_add', 'b');
  b.data('math_add', 'result', 'assign_t', 'value');
  b.data('var_b', 'value', 'assign_a2', 'value');
  b.data('var_t', 'value', 'assign_b2', 'value');
  b.data('var_a', 'value', 'stop_ret', 'value');

  return b.graph;
}

/// 最大公约数：两个参数 + while 循环 + 取模运算 + 返回值。
NodeGraph buildGcdSample() {
  final b = SampleBuilder(L10n.t('示例：最大公约数 gcd', 'Sample: GCD'));

  b.node('start', 'start', 40, 260);
  b.node('func', 'func', 320, 240, fields: {'name': 'gcd', 'params': 'a, b'});
  b.node('call', 'call', 620, 260,
      fields: {'name': 'gcd'}, literals: {'arg1': '48', 'arg2': '36'});
  b.node('concat', 'math', 900, 300,
      fields: {'op': '..'}, literals: {'a': '"gcd(48, 36) = "'});
  b.node('print1', 'print', 1180, 260);

  b.exec('start', 'out', 'func', 'in');
  b.exec('func', 'done', 'call', 'in');
  b.exec('call', 'out', 'print1', 'in');
  b.data('call', 'ret', 'concat', 'b');
  b.data('concat', 'result', 'print1', 'value');

  // ---- 函数体：while b ~= 0 do t = b; b = a % b; a = t end; return a
  b.node('while1', 'while', 320, 760);
  b.node('stop_ret', 'stop', 620, 760);
  b.exec('func', 'body', 'while1', 'in');
  b.exec('while1', 'done', 'stop_ret', 'in');

  b.node('assign_t', 'assign', 320, 1000, fields: {'name': 't'});
  b.node('assign_b', 'assign', 620, 1000, fields: {'name': 'b'});
  b.node('assign_a', 'assign', 920, 1000, fields: {'name': 'a'});
  b.exec('while1', 'body', 'assign_t', 'in');
  b.exec('assign_t', 'out', 'assign_b', 'in');
  b.exec('assign_b', 'out', 'assign_a', 'in');
  b.exec('assign_a', 'out', 'while1', 'in'); // 循环体绕回循环

  b.node('compare_bz', 'compare', 620, 1250,
      fields: {'op': '~='}); // b ~= 0
  b.data('func', 'p1', 'compare_bz', 'a');
  b.data('compare_bz', 'result', 'while1', 'cond');

  b.node('math_mod', 'math', 900, 1250, fields: {'op': '%'});
  b.data('func', 'p0', 'math_mod', 'a');
  b.data('func', 'p1', 'math_mod', 'b');
  b.data('math_mod', 'result', 'assign_b', 'value');

  b.node('var_b', 'var', 40, 1000, fields: {'name': 'b'});
  b.node('var_t', 'var', 40, 1250, fields: {'name': 't'});
  b.data('var_b', 'value', 'assign_t', 'value');
  b.data('var_t', 'value', 'assign_a', 'value');
  b.data('func', 'p0', 'stop_ret', 'value'); // return a（a 就是第一个参数）

  return b.graph;
}

/// 素数判断：if/else 提前返回、while 试除、布尔返回值。
NodeGraph buildPrimeSample() {
  final b = SampleBuilder(L10n.t('示例：素数判断', 'Sample: prime check'));

  b.node('start', 'start', 40, 260);
  b.node('func', 'func', 320, 240,
      fields: {'name': 'isPrime', 'params': 'n'});
  b.node('call', 'call', 620, 260,
      fields: {'name': 'isPrime'}, literals: {'arg1': '97'});
  b.node('print1', 'print', 900, 260);

  b.exec('start', 'out', 'func', 'in');
  b.exec('func', 'done', 'call', 'in');
  b.exec('call', 'out', 'print1', 'in');
  b.data('call', 'ret', 'print1', 'value');

  // ---- 函数体：if n < 2 then return false else ... 试除 ... return ok end
  b.node('if_lt', 'if', 320, 760);
  b.node('stop_false', 'stop', 620, 760, literals: {'value': 'false'});
  b.exec('func', 'body', 'if_lt', 'in');
  b.exec('if_lt', 'then', 'stop_false', 'in');

  b.node('compare_lt', 'compare', 620, 520, fields: {'op': '<'});
  b.data('func', 'p0', 'compare_lt', 'a');
  b.literal('compare_lt', {'b': '2'});
  b.data('compare_lt', 'result', 'if_lt', 'cond');

  b.node('assign_d', 'assign', 320, 1000,
      fields: {'name': 'd'}, literals: {'value': '2'});
  b.node('assign_ok', 'assign', 620, 1000,
      fields: {'name': 'ok'}, literals: {'value': 'true'});
  b.node('while1', 'while', 920, 1000);
  b.exec('if_lt', 'else', 'assign_d', 'in');
  b.exec('assign_d', 'out', 'assign_ok', 'in');
  b.exec('assign_ok', 'out', 'while1', 'in');

  // while (d*d) <= n do
  b.node('math_mul_dd', 'math', 320, 1250, fields: {'op': '*'});
  b.node('compare_le', 'compare', 620, 1250, fields: {'op': '<='});
  b.data('var_d', 'value', 'math_mul_dd', 'a');
  b.data('var_d', 'value', 'math_mul_dd', 'b');
  b.data('math_mul_dd', 'result', 'compare_le', 'a');
  b.data('func', 'p0', 'compare_le', 'b');
  b.data('compare_le', 'result', 'while1', 'cond');

  // if (n % d) == 0 then ok = false end
  b.node('if_mod', 'if', 920, 1250);
  b.node('assign_ok_false', 'assign', 920, 1480,
      fields: {'name': 'ok'}, literals: {'value': 'false'});
  b.node('assign_d_inc', 'assign', 1220, 1480, fields: {'name': 'd'});
  b.exec('while1', 'body', 'if_mod', 'in');
  b.exec('if_mod', 'then', 'assign_ok_false', 'in');
  b.exec('assign_ok_false', 'out', 'assign_d_inc', 'in');
  b.exec('if_mod', 'else', 'assign_d_inc', 'in'); // 两个分支汇合到 d = d + 1
  b.exec('assign_d_inc', 'out', 'while1', 'in'); // 循环体绕回循环

  b.node('math_mod', 'math', 1420, 1250, fields: {'op': '%'});
  b.node('compare_eq', 'compare', 1420, 1700, fields: {'op': '=='});
  b.data('func', 'p0', 'math_mod', 'a');
  b.data('var_d', 'value', 'math_mod', 'b');
  b.data('math_mod', 'result', 'compare_eq', 'a');
  b.data('compare_eq', 'result', 'if_mod', 'cond');

  b.node('math_add_inc', 'math', 1720, 1450, fields: {'op': '+'});
  b.data('var_d', 'value', 'math_add_inc', 'a');
  b.literal('math_add_inc', {'b': '1'});
  b.data('math_add_inc', 'result', 'assign_d_inc', 'value');

  b.node('stop_ok', 'stop', 1520, 1000);
  b.exec('while1', 'done', 'stop_ok', 'in');

  b.node('var_d', 'var', 40, 1250, fields: {'name': 'd'});
  b.node('var_ok', 'var', 40, 1450, fields: {'name': 'ok'});
  b.data('var_ok', 'value', 'stop_ok', 'value');

  return b.graph;
}

extension on SampleBuilder {
  /// 给节点补一批 literal，只是为了让示例图长得更紧凑。
  void literal(String nodeId, Map<String, String> values) {
    graph.byId(nodeId)!.literals.addAll(values);
  }
}
