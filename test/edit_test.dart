import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lua_node_studio/main.dart';
import 'package:lua_node_studio/ui/editor_page.dart';
import 'package:lua_node_studio/ui/output_panel.dart';

Future<OutputPanel> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2400, 3000);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const LuaNodeApp(home: EditorPage()));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
  return tester.widget<OutputPanel>(find.byType(OutputPanel));
}

void main() {
  testWidgets('点字段弹出编辑器，改完值生效并重新生成代码', (tester) async {
    final panel = await _boot(tester);
    final ctrl = panel.controller;

    expect(ctrl.graph.byId('assign_sum')!.field('name'), 'sum');

    // 「变量名」这一行的文字
    final label = find.text('变量名').first;
    await tester.tap(label, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget, reason: '没有弹出编辑框');

    await tester.enterText(find.byType(TextField), 'total');
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(ctrl.graph.byId('assign_sum')!.field('name'), 'total');
    expect(ctrl.lastGen!.code, contains('local total = 0'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('点取值 chip 能改 Lua 表达式', (tester) async {
    final panel = await _boot(tester);
    final ctrl = panel.controller;

    expect(ctrl.graph.byId('print1')!.literal('value'), '"sum =", sum');

    await tester.tap(find.textContaining('sum =').first, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(AlertDialog), findsOneWidget, reason: 'chip 没有弹出编辑框');

    await tester.enterText(find.byType(TextField), '"结果是", sum');
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(ctrl.graph.byId('print1')!.literal('value'), '"结果是", sum');
    expect(ctrl.lastGen!.code, contains('print("结果是", sum)'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('手指带一点位移也不会变成拖节点（宽容点击）', (tester) async {
    final panel = await _boot(tester);
    final ctrl = panel.controller;
    final before = ctrl.graph.byId('assign_sum')!.pos;

    final label = find.text('变量名').first;
    final center = tester.getCenter(label);

    // 模拟真实手指：按下后偏移 6px 再抬起
    final gesture = await tester.startGesture(center);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(4, 4));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AlertDialog), findsOneWidget, reason: '轻微位移导致没打开编辑框');
    expect(ctrl.graph.byId('assign_sum')!.pos, before, reason: '节点被误拖动了');
    expect(tester.takeException(), isNull);
  });
}
