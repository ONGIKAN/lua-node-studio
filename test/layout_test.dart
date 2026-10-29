import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lua_node_studio/main.dart';
import 'package:lua_node_studio/ui/editor_page.dart';
import 'package:lua_node_studio/ui/project_manager_page.dart';

void main() {
  testWidgets('手机尺寸下项目管理首页可以正常布局并进入编辑器', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LuaNodeApp());
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 600));

    expect(tester.takeException(), isNull);
    expect(find.byType(ProjectManagerPage), findsOneWidget);
    expect(find.text('内置示例'), findsOneWidget);

    // 点第一张内置示例，进入编辑器
    await tester.tap(find.byKey(const ValueKey('pm-sample-0')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(EditorPage), findsOneWidget);
    expect(find.textContaining('LuaDardo'), findsOneWidget);
  });

  testWidgets('平板上横屏布局同样正常', (tester) async {
    tester.view.physicalSize = const Size(2000, 1200);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LuaNodeApp());
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.byType(ProjectManagerPage), findsOneWidget);
  });
}
