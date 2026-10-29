import '../l10n/l10n.dart';
import '../models/graph.dart';
import 'sample_algorithms.dart';

/// 模块演示：直接用「求和模块」节点，不用手搭循环。
///
/// ```lua
/// local function __mod_sum(n) ... end
/// print(("sum(1..100) = " .. __mod_sum(100)))
/// ```
NodeGraph buildModuleSumSample() {
  final b =
      SampleBuilder(L10n.t('示例：模块化 1 到 100 求和', 'Sample: module sum 1..100'));

  b.node('num_n', 'number', 40, 470, fields: {'value': '100'});
  b.node('m_sum', 'm_sum', 360, 470);
  b.node('concat', 'math', 680, 470,
      fields: {'op': '..'}, literals: {'a': '"sum(1..100) = "'});
  b.node('start', 'start', 40, 280);
  b.node('print1', 'print', 1000, 280);

  b.exec('start', 'out', 'print1', 'in');
  b.data('num_n', 'value', 'm_sum', 'n');
  b.data('m_sum', 'result', 'concat', 'b');
  b.data('concat', 'result', 'print1', 'value');

  return b.graph;
}

/// 表达式节点演示：一个节点里写完 (a + b) * (a - b)。
NodeGraph buildExpressionSample() {
  final b =
      SampleBuilder(L10n.t('示例：表达式一句话算完', 'Sample: one-node expression'));

  b.node('num_a', 'number', 40, 470, fields: {'value': '6'});
  b.node('num_b', 'number', 40, 620, fields: {'value': '4'});
  b.node('expr', 'expr', 360, 520,
      fields: {'expression': '(a + b) * (a - b)'});
  b.node('concat', 'math', 700, 470,
      fields: {'op': '..'}, literals: {'a': '"expr = "'});
  b.node('start', 'start', 40, 280);
  b.node('print1', 'print', 1020, 280);

  b.exec('start', 'out', 'print1', 'in');
  b.data('num_a', 'value', 'expr', 'a');
  b.data('num_b', 'value', 'expr', 'b');
  b.data('expr', 'result', 'concat', 'b');
  b.data('concat', 'result', 'print1', 'value');

  return b.graph;
}

/// 加减乘除演示：12 和 4 分别做四种运算并打印。
NodeGraph buildArithmeticSample() {
  final b =
      SampleBuilder(L10n.t('示例：加减乘除四则运算', 'Sample: arithmetic four ops'));

  b.node('start', 'start', 40, 260);
  b.node('num_a', 'number', 40, 460, fields: {'value': '12'});
  b.node('num_b', 'number', 40, 610, fields: {'value': '4'});

  b.node('add', 'add', 300, 460);
  b.node('sub', 'sub', 300, 610);
  b.node('mul', 'mul', 300, 760);
  b.node('div', 'div', 300, 910);

  b.node('c_add', 'math', 640, 460,
      fields: {'op': '..'}, literals: {'a': '"12 + 4 = "'});
  b.node('c_sub', 'math', 640, 610,
      fields: {'op': '..'}, literals: {'a': '"12 - 4 = "'});
  b.node('c_mul', 'math', 640, 760,
      fields: {'op': '..'}, literals: {'a': '"12 * 4 = "'});
  b.node('c_div', 'math', 640, 910,
      fields: {'op': '..'}, literals: {'a': '"12 / 4 = "'});

  b.node('p_add', 'print', 980, 460);
  b.node('p_sub', 'print', 980, 610);
  b.node('p_mul', 'print', 980, 760);
  b.node('p_div', 'print', 980, 910);

  b.exec('start', 'out', 'p_add', 'in');
  b.exec('p_add', 'out', 'p_sub', 'in');
  b.exec('p_sub', 'out', 'p_mul', 'in');
  b.exec('p_mul', 'out', 'p_div', 'in');

  b.data('num_a', 'value', 'add', 'a');
  b.data('num_b', 'value', 'add', 'b');
  b.data('add', 'result', 'c_add', 'b');
  b.data('c_add', 'result', 'p_add', 'value');

  b.data('num_a', 'value', 'sub', 'a');
  b.data('num_b', 'value', 'sub', 'b');
  b.data('sub', 'result', 'c_sub', 'b');
  b.data('c_sub', 'result', 'p_sub', 'value');

  b.data('num_a', 'value', 'mul', 'a');
  b.data('num_b', 'value', 'mul', 'b');
  b.data('mul', 'result', 'c_mul', 'b');
  b.data('c_mul', 'result', 'p_mul', 'value');

  b.data('num_a', 'value', 'div', 'a');
  b.data('num_b', 'value', 'div', 'b');
  b.data('div', 'result', 'c_div', 'b');
  b.data('c_div', 'result', 'p_div', 'value');

  return b.graph;
}
