import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lua_node_studio/l10n/l10n.dart';
import 'package:lua_node_studio/models/graph.dart';
import 'package:lua_node_studio/samples/sample_catalog.dart';
import 'package:lua_node_studio/storage/project_store.dart';
import 'package:lua_node_studio/ui/editor_page.dart';
import 'package:lua_node_studio/ui/project_manager_page.dart';

NodeGraph _graph(String name) {
  return NodeGraph(name: name)
    ..nodes.add(GraphNode(id: 'start', type: 'start', pos: const Offset(60, 60)))
    ..nodes.add(GraphNode(
        id: 'print1', type: 'print', pos: const Offset(360, 60)));
}

/// widget 测试里没有真实事件循环，文件 IO 需要用 runAsync 放行；
/// 同时避免 pumpAndSettle 被 loading spinner 的无限动画卡住。
Future<void> _flush(WidgetTester tester, {int rounds = 30}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 8));
    });
    await tester.pump(const Duration(milliseconds: 16));
  }
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump(const Duration(milliseconds: 500));
}

Future<void> _waitUntil(WidgetTester tester, bool Function() ready,
    {Duration timeout = const Duration(seconds: 8)}) async {
  final start = DateTime.now();
  while (DateTime.now().difference(start) < timeout) {
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    await tester.pump(const Duration(milliseconds: 30));
    if (ready()) return;
  }
  fail('等待 UI 更新超时');
}

Future<void> _pumpManager(WidgetTester tester, ProjectStore store,
    {bool settle = true}) async {
  tester.view.physicalSize = const Size(900, 3600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData.dark(useMaterial3: true),
    home: ProjectManagerPage(store: store),
  ));
  if (settle) {
    await _flush(tester);
  } else {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  setUp(() => L10n.setLanguage(AppLanguage.zh));
  tearDown(() => L10n.setLanguage(AppLanguage.zh));

  late Directory tempDir;
  late ProjectStore store;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('lua_node_studio_pm_');
    store = ProjectStore(directory: tempDir);
  });

  tearDown(() {
    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {
      // 测试目录清理失败就不管了
    }
  });

  testWidgets('默认首页是项目管理：内置示例 + 空工程列表', (tester) async {
    await _pumpManager(tester, store);

    expect(find.byType(ProjectManagerPage), findsOneWidget);
    expect(find.text('Lua Node Studio'), findsWidgets);
    expect(find.text('内置示例'), findsOneWidget);
    expect(find.text('我的项目'), findsOneWidget);
    expect(find.text('还没有自己的项目'), findsOneWidget);

    for (var i = 0; i < kSamples.length; i++) {
      expect(find.byKey(ValueKey('pm-sample-$i')), findsOneWidget);
      expect(find.text(kSamples[i].displayTitle), findsOneWidget);
    }
    // 示例卡片上展示了预期输出
    expect(find.textContaining('sum ='), findsWidgets);
  });

  testWidgets('点击内置示例可以直接进入编辑器并返回', (tester) async {
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await _pumpManager(tester, store);
    await tester.tap(find.byKey(const ValueKey('pm-sample-0')));
    await _flush(tester);

    expect(find.byType(EditorPage), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await _flush(tester);
    expect(find.byType(ProjectManagerPage), findsOneWidget);
  });

  testWidgets('新建项目进入空白图编辑器', (tester) async {
    await _pumpManager(tester, store);
    await tester.tap(find.byKey(const ValueKey('pm-new')));
    await _flush(tester);

    expect(find.byType(EditorPage), findsOneWidget);
    // 空白图只有「开始」节点，名字是「未命名」
    expect(find.text('未命名'), findsWidgets);
  });

  testWidgets('已保存的工程出现在「我的项目」里，并且可以打开', (tester) async {
    await tester.runAsync(() async {
      await store.save('我的算法', _graph('我的算法'));
      await store.registerProject('我的算法', name: '我的算法');
    });

    await _pumpManager(tester, store);
    expect(find.byKey(const ValueKey('pm-project-我的算法')), findsOneWidget);
    expect(find.text('我的算法'), findsOneWidget);
    expect(find.textContaining('2 个节点'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pm-project-我的算法')));
    await _flush(tester);
    expect(find.byType(EditorPage), findsOneWidget);
  });

  testWidgets('导入 JSON 后工程出现在列表中并直接打开', (tester) async {
    final json = jsonEncode(_graph('导入而来的工程').toJson());
    await _pumpManager(tester, store);

    await tester.tap(find.byKey(const ValueKey('pm-import')));
    await _flush(tester);

    await tester.enterText(
        find.byKey(const ValueKey('pm-import-json')), json);
    await tester.enterText(
        find.byKey(const ValueKey('pm-import-name')), '导入测试');
    await tester.tap(find.widgetWithText(FilledButton, '导入'));
    await _flush(tester);

    expect(find.byType(EditorPage), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await _flush(tester);
    expect(find.byKey(const ValueKey('pm-project-导入测试')), findsOneWidget);
  });

  testWidgets('工程可以重命名和删除', (tester) async {
    await tester.runAsync(() async {
      await store.save('旧名字', _graph('旧名字'));
      await store.registerProject('旧名字', name: '旧名字');
    });
    await _pumpManager(tester, store);

    // 重命名
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('pm-project-旧名字')),
      matching: find.byType(PopupMenuButton<String>),
    ));
    await _flush(tester);
    await tester.tap(find.text('重命名'));
    await _flush(tester);
    await tester.enterText(find.byType(TextField), '新名字');
    await tester.tap(find.text('确定'));
    await _flush(tester);

    final projects = await tester.runAsync(() => store.listProjects()) ?? [];
    expect(projects.map((e) => e.name), contains('新名字'));
    await _waitUntil(tester,
        () => find.byKey(const ValueKey('pm-project-新名字')).evaluate().isNotEmpty);

    // 删除（文件名会跟着改成 新名字）
    await tester.tap(find.descendant(
      of: find.byKey(const ValueKey('pm-project-新名字')),
      matching: find.byType(PopupMenuButton<String>),
    ));
    await _flush(tester);
    await tester.tap(find.text('删除').first);
    await _flush(tester);
    await tester.tap(find.widgetWithText(FilledButton, '删除'));
    await _flush(tester);

    final left = await tester.runAsync(() => store.listProjects()) ?? [];
    expect(left, isEmpty);
    await _waitUntil(tester,
        () => find.text('还没有自己的项目').evaluate().isNotEmpty);
  });

  testWidgets('存在自动保存时首页显示「继续上次编辑」', (tester) async {
    await tester.runAsync(
        () => store.save('__autosave', _graph('未命名')));
    await _pumpManager(tester, store);

    expect(find.byKey(const ValueKey('pm-resume')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pm-resume')));
    await _flush(tester);
    expect(find.byType(EditorPage), findsOneWidget);
  });

  testWidgets('项目管理页可以切换中英文', (tester) async {
    await _pumpManager(tester, store);
    expect(find.text('内置示例'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pm-lang')));
    await _flush(tester);

    expect(L10n.isEnglish, isTrue);
    expect(find.text('Built-in samples'), findsOneWidget);
    expect(find.text('New project'), findsOneWidget);
    expect(find.text('Import JSON'), findsOneWidget);
    expect(find.text('My projects'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pm-lang')));
    await _flush(tester);
    expect(L10n.isEnglish, isFalse);
    expect(find.text('内置示例'), findsOneWidget);
  });
}
