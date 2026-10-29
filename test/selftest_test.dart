import 'package:flutter_test/flutter_test.dart';
import 'package:lua_node_studio/codegen/lua_generator.dart';
import 'package:lua_node_studio/engine/lua_engine.dart';
import 'package:lua_node_studio/models/graph.dart';
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
}
