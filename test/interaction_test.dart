import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lua_node_studio/main.dart';
import 'package:lua_node_studio/ui/editor_page.dart';
import 'package:lua_node_studio/ui/node_widget.dart';
import 'package:lua_node_studio/ui/output_panel.dart';

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2400, 3000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const LuaNodeApp(home: EditorPage()));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('拖动节点主体可以移动节点', (tester) async {
    await _boot(tester);

    final finder = find.byWidgetPredicate(
        (w) => w is NodeWidget && w.node.id == 'assign_sum');
    expect(finder, findsOneWidget);

    final before = tester.widget<NodeWidget>(finder).node.pos;
    await tester.drag(finder, const Offset(50, 30));
    await tester.pump();

    final after = tester.widget<NodeWidget>(finder).node.pos;
    expect(after.dx, greaterThan(before.dx));
    expect(after.dy, greaterThan(before.dy));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('从一个端口拖到另一个端口可以连线', (tester) async {
    await _boot(tester);

    final outKey = const ValueKey('port_var_i_value_out');
    final inKey = const ValueKey('port_assign_sum_value_in');
    expect(find.byKey(outKey), findsOneWidget);
    expect(find.byKey(inKey), findsOneWidget);

    final ctrl = tester.widget<OutputPanel>(find.byType(OutputPanel)).controller;
    final before = ctrl.graph.links.length;

    final start = tester.getCenter(find.byKey(outKey));
    final end = tester.getCenter(find.byKey(inKey));

    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 20));
    const steps = 8;
    for (var i = 1; i <= steps; i++) {
      await gesture.moveTo(start + (end - start) * (i / steps));
      await tester.pump(const Duration(milliseconds: 10));
    }
    await gesture.up();
    await tester.pump();

    final added = ctrl.graph.links.where((l) =>
        l.fromNode == 'var_i' &&
        l.fromPort == 'value' &&
        l.toNode == 'assign_sum' &&
        l.toPort == 'value');
    expect(ctrl.graph.links.length, greaterThan(before));
    expect(added, isNotEmpty, reason: '拖拽连线没有建立');
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
  });

  testWidgets('长按空白处弹出节点面板', (tester) async {
    await _boot(tester);

    await tester.longPressAt(const Offset(1160, 200));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('添加节点'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('点按端口两次即可连线（触屏手感）', (tester) async {
    await _boot(tester);

    final ctrl = tester.widget<OutputPanel>(find.byType(OutputPanel)).controller;
    final before = ctrl.graph.links.length;

    await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('port_var_i_value_out'))));
    await tester.pump(const Duration(milliseconds: 60));
    expect(find.textContaining('连线中'), findsOneWidget);

    await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('port_assign_sum_value_in'))));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.textContaining('连线中'), findsNothing);
    expect(ctrl.graph.links.length, greaterThan(before));
    expect(
        ctrl.graph.links.any((l) =>
            l.fromNode == 'var_i' &&
            l.toPort == 'value' &&
            l.toNode == 'assign_sum'),
        isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('撤销能回退刚建立的连线', (tester) async {
    await _boot(tester);
    final ctrl = tester.widget<OutputPanel>(find.byType(OutputPanel)).controller;
    final before = ctrl.graph.links.length;

    await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('port_var_i_value_out'))));
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(
        tester.getCenter(find.byKey(const ValueKey('port_assign_sum_value_in'))));
    await tester.pump(const Duration(milliseconds: 60));
    expect(ctrl.graph.links.length, greaterThan(before));

    await tester.tap(find.byTooltip('撤销').first);
    await tester.pump(const Duration(milliseconds: 200));

    expect(ctrl.graph.links.length, before);
    expect(tester.takeException(), isNull);
  });

  testWidgets('一键整理后布局收窄，代码不受影响', (tester) async {
    await _boot(tester);
    final ctrl = tester.widget<OutputPanel>(find.byType(OutputPanel)).controller;
    final codeBefore = ctrl.lastGen!.code;

    await tester.tap(find.byIcon(Icons.auto_awesome_mosaic_outlined));
    await tester.pump(const Duration(milliseconds: 400));

    final xs = ctrl.graph.nodes.map((n) => n.pos.dx).toSet();
    expect(xs.length, lessThanOrEqualTo(3), reason: '整理后应该只有 3 列');

    // 竖排之后所有节点互不重叠
    final list = ctrl.graph.nodes.toList();
    for (var i = 0; i < list.length; i++) {
      for (var j = i + 1; j < list.length; j++) {
        final a = list[i].pos & list[i].size;
        final b = list[j].pos & list[j].size;
        expect(a.overlaps(b), isFalse,
            reason: '\${list[i].id} 和 \${list[j].id} 重叠了');
      }
    }
    expect(ctrl.lastGen!.code, codeBefore);
    expect(tester.takeException(), isNull);
  });
}
