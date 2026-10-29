import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lua_node_studio/ai/ai_client.dart';
import 'package:lua_node_studio/ai/ai_config.dart';
import 'package:lua_node_studio/ai/ai_chat_page.dart';
import 'package:lua_node_studio/ai/graph_blueprint.dart';
import 'package:lua_node_studio/storage/project_store.dart';
import 'package:lua_node_studio/ui/project_manager_page.dart';
import 'dart:io';

class _FakeTransport implements AiTransport {
  _FakeTransport(this.reply);

  final String reply;
  AiConfig? lastConfig;
  List<AiMessage>? lastMessages;

  @override
  Future<String> complete(
    AiConfig config,
    List<AiMessage> messages, {
    Duration timeout = const Duration(seconds: 90),
  }) async {
    lastConfig = config;
    lastMessages = messages;
    return reply;
  }
}

const _validBlueprint = '''
好的，给你生成这个程序：
```json
{
  "name": "1 到 10 求和",
  "nodes": [
    {"id": "n1", "type": "start", "x": 60, "y": 120},
    {"id": "n2", "type": "assign", "x": 400, "y": 120, "fields": {"name": "sum"}, "literals": {"value": "0"}},
    {"id": "n3", "type": "for", "x": 740, "y": 120, "fields": {"var": "i"}, "literals": {"from": "1", "to": "10"}},
    {"id": "n4", "type": "assign", "x": 740, "y": 380, "fields": {"name": "sum"}},
    {"id": "n5", "type": "var", "x": 400, "y": 380, "fields": {"name": "sum"}},
    {"id": "n6", "type": "var", "x": 400, "y": 560, "fields": {"name": "i"}},
    {"id": "n7", "type": "math", "x": 740, "y": 560, "fields": {"op": "+"}},
    {"id": "n8", "type": "print", "x": 1080, "y": 120, "literals": {"value": "\\"sum =\\", sum"}}
  ],
  "links": [
    {"from": "n1", "fromPort": "out", "to": "n2", "toPort": "in"},
    {"from": "n2", "fromPort": "out", "to": "n3", "toPort": "in"},
    {"from": "n3", "fromPort": "body", "to": "n4", "toPort": "in"},
    {"from": "n4", "fromPort": "out", "to": "n3", "toPort": "in"},
    {"from": "n3", "fromPort": "done", "to": "n8", "toPort": "in"},
    {"from": "n5", "fromPort": "value", "to": "n7", "toPort": "a"},
    {"from": "n6", "fromPort": "value", "to": "n7", "toPort": "b"},
    {"from": "n7", "fromPort": "result", "to": "n4", "toPort": "value"}
  ]
}
```
''';

void main() {
  group('AiConfig', () {
    test('endpoint 自动补全', () {
      expect(const AiConfig(baseUrl: 'https://api.openai.com/v1').endpoint,
          'https://api.openai.com/v1/chat/completions');
      expect(const AiConfig(baseUrl: 'https://api.deepseek.com/').endpoint,
          'https://api.deepseek.com/v1/chat/completions');
      expect(
          const AiConfig(
                  baseUrl: 'https://x.test/v1/chat/completions')
              .endpoint,
          'https://x.test/v1/chat/completions');
      expect(const AiConfig(baseUrl: 'http://localhost:11434/v1').endpoint,
          'http://localhost:11434/v1/chat/completions');
    });

    test('isConfigured 与存取', () async {
      const cfg = AiConfig(
          baseUrl: 'https://api.test/v1', apiKey: 'sk-1', model: 'm1');
      expect(cfg.isConfigured, isTrue);
      expect(AiConfig.fromJson(cfg.toJson()).model, 'm1');

      final dir = Directory.systemTemp.createTempSync('ai_store_');
      final store = ProjectStore(directory: dir);
      final configStore = AiConfigStore(store);
      await configStore.save(cfg);
      final loaded = await configStore.load();
      expect(loaded.baseUrl, 'https://api.test/v1');
      expect(loaded.apiKey, 'sk-1');
      expect(loaded.model, 'm1');
      dir.deleteSync(recursive: true);
    });
  });

  group('GraphBlueprint', () {
    test('解析合法 JSON：节点、连线、执行流标记', () {
      final result = GraphBlueprint.parse(_validBlueprint);
      expect(result.error, isNull);
      final g = result.graph!;
      expect(g.name, '1 到 10 求和');
      expect(g.nodes.length, 8);
      expect(g.startNode, isNotNull);
      expect(g.links.length, 8);
      final startLink = g.links.firstWhere((l) => l.fromNode == 'n1');
      expect(startLink.isExecFlow, isTrue);
      final dataLink =
          g.links.firstWhere((l) => l.fromNode == 'n5' && l.toNode == 'n7');
      expect(dataLink.isExecFlow, isFalse);
      expect(g.byId('n2')!.field('name'), 'sum');
      expect(g.byId('n8')!.literal('value'), '"sum =", sum');
    });

    test('没有开始节点时自动补上并连线', () {
      final raw = '''
{"name": "测试", "nodes": [
  {"id": "n1", "type": "print", "x": 200, "y": 100, "literals": {"value": "1"}}
], "links": []}
''';
      final result = GraphBlueprint.parse(raw);
      expect(result.graph, isNotNull);
      expect(result.graph!.startNode, isNotNull);
      expect(result.graph!.links.length, 1);
      expect(result.warnings, isNotEmpty);
    });

    test('未知类型/错误端口被忽略并记录警告', () {
      final raw = '''
{"name": "坏图", "nodes": [
  {"id": "n1", "type": "start", "x": 1, "y": 2},
  {"id": "n2", "type": "not_exist", "x": 3, "y": 4},
  {"id": "n3", "type": "print", "x": 5, "y": 6}
], "links": [
  {"from": "n1", "fromPort": "nope", "to": "n3", "toPort": "in"},
  {"from": "n1", "fromPort": "out", "to": "n3", "toPort": "out"}
]}
''';
      final result = GraphBlueprint.parse(raw);
      expect(result.graph, isNotNull);
      expect(result.graph!.nodes.length, 2);
      expect(result.warnings.length, greaterThanOrEqualTo(2));
    });

    test('非 JSON 回复返回错误', () {
      final result = GraphBlueprint.parse('抱歉，我无法完成。');
      expect(result.ok, isFalse);
      expect(result.error, isNotNull);
    });
  });

  testWidgets('AI 对话页：注入假网络层，生成节点图并可打开画布', (tester) async {
    final dir = Directory.systemTemp.createTempSync('ai_chat_');
    final store = ProjectStore(directory: dir);
    final transport = _FakeTransport(_validBlueprint);

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: AiChatPage(
        store: store,
        initialConfig: const AiConfig(
            baseUrl: 'https://api.test/v1', apiKey: 'sk-test', model: 'test-model'),
        transport: transport,
      ),
    ));
    await tester.pump();

    expect(find.byKey(const ValueKey('ai-input')), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('ai-input')), '帮我写 1 到 10 求和');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('ai-send')));
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('1 到 10 求和'), findsWidgets);
    expect(find.byKey(const ValueKey('ai-open-graph')), findsOneWidget);
    expect(transport.lastConfig?.model, 'test-model');

    await tester.tap(find.byKey(const ValueKey('ai-open-graph')));
    for (int i = 0; i < 20; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.textContaining('Lua 代码'), findsWidgets);

    final files = await tester.runAsync(() => store.listProjects());
    expect(files, isNotNull);
    expect(files!.length, 1);
    dir.deleteSync(recursive: true);
  });

  testWidgets('项目管理页包含 AI 生成入口', (tester) async {
    final dir = Directory.systemTemp.createTempSync('pm_ai_');
    final store = ProjectStore(directory: dir);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: ProjectManagerPage(store: store),
    ));
    for (int i = 0; i < 15; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('pm-ai')), findsOneWidget);
    dir.deleteSync(recursive: true);
  });
}
