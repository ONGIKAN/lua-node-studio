import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lua_node_studio/main.dart';
import 'package:lua_node_studio/ui/editor_page.dart';
import 'package:lua_node_studio/ui/output_panel.dart';

/// 用系统字体渲染快照，方便检查中文排版（测试环境默认字体是方块）。
Future<void> _loadSystemFonts() async {
  Future<void> load(String family, String path) async {
    final f = File(path);
    if (!f.existsSync()) return;
    final bytes = f.readAsBytesSync();
    final loader = FontLoader(family)
      ..addFont(Future.value(ByteData.view(bytes.buffer)));
    await loader.load();
  }

  await load('Roboto', r'C:\Windows\Fonts\Deng.ttf');
  await load('monospace', r'C:\Windows\Fonts\consola.ttf');
}

void main() {
  testWidgets('整机渲染快照（手机尺寸）', (tester) async {
    await tester.runAsync(_loadSystemFonts);
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LuaNodeApp(home: EditorPage()));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 600));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/editor_phone.png'),
    );
  });

  testWidgets('点击运行能拿到 Lua 输出', (tester) async {
    await tester.runAsync(_loadSystemFonts);
    tester.view.physicalSize = const Size(1080, 2200);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const LuaNodeApp(home: EditorPage()));
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();

    for (var i = 0; i < 6; i++) {
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 250));
      });
      await tester.pump(const Duration(milliseconds: 120));
    }

    final panel = tester.widget<OutputPanel>(find.byType(OutputPanel));
    // ignore: avoid_print
    print('lastRun output=${panel.controller.lastRun?.output} '
        'error=${panel.controller.lastRun?.error} '
        'status=${panel.controller.statusMessage}');

    expect(tester.takeException(), isNull);
    expect(find.textContaining('55'), findsWidgets);

    // 耗时数字会变，快照前固定成常量
    panel.controller.statusNotifier.value = '运行完成 · 0ms';
    await tester.pump();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/editor_after_run.png'),
    );
  });
}
