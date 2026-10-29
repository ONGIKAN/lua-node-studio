import 'package:flutter_test/flutter_test.dart';
import 'package:lua_node_studio/codegen/lua_generator.dart';
import 'package:lua_node_studio/engine/lua_engine.dart';
import 'package:lua_node_studio/models/graph.dart';
import 'package:lua_node_studio/models/node_spec.dart';
import 'package:lua_node_studio/samples/sample_algorithms.dart';
import 'package:lua_node_studio/samples/sample_catalog.dart';
import 'package:lua_node_studio/samples/sample_graph.dart';

void main() {
  test('示例图生成 Lua 并执行', () async {
    final g = buildSampleGraph();
    final result = LuaGenerator(g).generate();
    // ignore: avoid_print
    print('--- generated ---\n${result.code}\n--- warnings: ${result.warnings}');

    final run = await const DartLuaEngine().run(result.code);
    // ignore: avoid_print
    print('--- stdout ---\n${run.output}\n--- error: ${run.error}');

    expect(run.success, isTrue, reason: run.error ?? '');
    expect(run.output.trim(), 'sum =\t55');
  });

  test('条件分支 + 汇合点', () async {
    final g = NodeGraph(name: 'if 测试');
    g.nodes.addAll([
      GraphNode(id: 's', type: 'start', pos: Offset.zero),
      GraphNode(id: 'a', type: 'assign', pos: Offset.zero, fields: {'name': 'x'}),
      GraphNode(id: 'i', type: 'if', pos: Offset.zero),
      GraphNode(id: 't', type: 'print', pos: Offset.zero, literals: {'value': '"big"'}),
      GraphNode(id: 'e', type: 'print', pos: Offset.zero, literals: {'value': '"small"'}),
      GraphNode(id: 'm', type: 'print', pos: Offset.zero, literals: {'value': '"done"'}),
    ]);
    g.links.addAll([
      GraphLink(fromNode: 's', fromPort: 'out', toNode: 'a', toPort: 'in', isExec: true),
      GraphLink(fromNode: 'a', fromPort: 'out', toNode: 'i', toPort: 'in', isExec: true),
      GraphLink(fromNode: 'i', fromPort: 'then', toNode: 't', toPort: 'in', isExec: true),
      GraphLink(fromNode: 'i', fromPort: 'else', toNode: 'e', toPort: 'in', isExec: true),
      GraphLink(fromNode: 't', fromPort: 'out', toNode: 'm', toPort: 'in', isExec: true),
      GraphLink(fromNode: 'e', fromPort: 'out', toNode: 'm', toPort: 'in', isExec: true),
    ]);
    g.byId('a')!.literals['value'] = '7';
    g.byId('i')!.literals['cond'] = '(x > 5)';

    final result = LuaGenerator(g).generate();
    // ignore: avoid_print
    print('--- if graph ---\n${result.code}');

    final run = await const DartLuaEngine().run(result.code);
    // ignore: avoid_print
    print('--- stdout ---\n${run.output}');

    expect(run.success, isTrue, reason: run.error ?? '');
    expect(run.output.trim().split('\n'), ['big', 'done']);
  });

  test('语法错误能被捕获', () async {
    final run = await const DartLuaEngine().run('print(');
    expect(run.success, isFalse);
    expect(run.error, isNotNull);
  });

  test('内置示例清单：生成代码、执行并匹配预期输出', () async {
    final engine = const DartLuaEngine();
    for (final sample in kSamples) {
      final g = sample.build();
      final result = LuaGenerator(g).generate();
      // ignore: avoid_print
      print('=== ${sample.title} ===\n${result.code}');
      expect(result.warnings, isEmpty,
          reason: '${sample.title} 生成代码时有警告：${result.warnings}');

      final run = await engine.run(result.code);
      expect(run.success, isTrue,
          reason: '${sample.title} 执行失败：${run.error ?? ''}');
      expect(run.output.trim(), sample.expectOutput,
          reason: '${sample.title} 输出与预期不符');
    }
  });

  test('函数定义支持参数与返回值', () {
    final code = LuaGenerator(buildFactorialSample()).generate().code;
    expect(code, contains('local function factorial(n)'));
    expect(code, contains('local r = 1'));
    expect(code, contains('for i = 1, n do'));
    expect(code, contains('r = (r * i)'));
    expect(code, contains('return r'));
    expect(code, contains('local __ret_0 = factorial(5)'));
  });

  test('函数节点参数端口随参数列表变化', () {
    final g = NodeGraph(name: 'params');
    g.nodes.add(GraphNode(
      id: 'f',
      type: 'func',
      pos: Offset.zero,
      fields: {'name': 'add', 'params': 'a, b'},
    ));
    final spec = g.byId('f')!.spec;
    expect(spec.outputById('body')?.type, PortType.exec);
    expect(spec.outputById('p0')?.label, 'a');
    expect(spec.outputById('p1')?.label, 'b');
    expect(spec.outputById('p2'), isNull);

    g.byId('f')!.fields['params'] = 'x';
    expect(g.byId('f')!.spec.outputById('p0')?.label, 'x');
    expect(g.byId('f')!.spec.outputById('p1'), isNull);
  });

  test('非法参数列表会被忽略并给出警告', () {
    final g = NodeGraph(name: 'bad params');
    g.nodes.addAll([
      GraphNode(id: 's', type: 'start', pos: Offset.zero),
      GraphNode(
        id: 'f',
        type: 'func',
        pos: Offset.zero,
        fields: {'name': 'f', 'params': '1bad, end'},
      ),
    ]);
    g.links.add(GraphLink(
        fromNode: 's', fromPort: 'out', toNode: 'f', toPort: 'in', isExec: true));
    final result = LuaGenerator(g).generate();
    expect(result.code, contains('local function f()'));
    expect(result.warnings.join(), contains('不是合法的参数列表'));
  });

  test('内置示例图的节点互不重叠', () {
    for (final sample in kSamples) {
      final g = sample.build();
      final rects =
          g.nodes.map((n) => (n.id, n.pos & n.size)).toList(growable: false);
      for (var i = 0; i < rects.length; i++) {
        for (var j = i + 1; j < rects.length; j++) {
          final (idA, rectA) = rects[i];
          final (idB, rectB) = rects[j];
          expect(rectA.overlaps(rectB), isFalse,
              reason: '${sample.title}：节点 $idA 与 $idB 重叠');
        }
      }
    }
  });

  test('数学函数节点生成 math.* 调用并可执行', () async {
    final b = SampleBuilder('数学函数测试');
    b.node('start', 'start', 0, 0);
    b.node('num9', 'number', 0, 200, fields: {'value': '9'});
    b.node('sqrt', 'mathfn', 0, 400, fields: {'fn': 'sqrt'});
    b.node('concat', 'math', 0, 600,
        fields: {'op': '..'}, literals: {'a': '"sqrt(9) = "'});
    b.node('p', 'print', 0, 800);
    b.exec('start', 'out', 'p', 'in');
    b.data('num9', 'value', 'sqrt', 'a');
    b.data('sqrt', 'result', 'concat', 'b');
    b.data('concat', 'result', 'p', 'value');

    final result = LuaGenerator(b.graph).generate();
    expect(result.warnings, isEmpty);
    expect(result.code, contains('math.sqrt('));
    final run = await const DartLuaEngine().run(result.code);
    expect(run.success, isTrue, reason: run.error ?? '');
    expect(run.output.trim(), 'sqrt(9) = 3.0');
  });

  test('表达式节点替换 a/b/c 占位符', () async {
    final b = SampleBuilder('表达式测试');
    b.node('start', 'start', 0, 0);
    b.node('num2', 'number', 0, 200, fields: {'value': '2'});
    b.node('num3', 'number', 0, 350, fields: {'value': '3'});
    b.node('expr', 'expr', 0, 500,
        fields: {'expression': 'a * b + 10'});
    b.node('p', 'print', 0, 800);
    b.exec('start', 'out', 'p', 'in');
    b.data('num2', 'value', 'expr', 'a');
    b.data('num3', 'value', 'expr', 'b');
    b.data('expr', 'result', 'p', 'value');

    final result = LuaGenerator(b.graph).generate();
    expect(result.warnings, isEmpty);
    final run = await const DartLuaEngine().run(result.code);
    expect(run.success, isTrue, reason: run.error ?? '');
    expect(run.output.trim(), '16');
  });
}
