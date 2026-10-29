import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/graph.dart';
import '../storage/project_store.dart';
import '../ui/editor_page.dart';
import 'ai_client.dart';
import 'ai_config.dart';
import 'graph_blueprint.dart';

/// 自定义 AI API 入口 + 对话生成节点图。
///
/// - 首次使用先在这里填 API 地址 / Key / 模型（OpenAI 兼容接口，本地模型可留空 Key）
/// - 配置成功后直接对话，AI 返回节点图 JSON，自动校验并可直接加载到画布
class AiChatPage extends StatefulWidget {
  const AiChatPage({
    super.key,
    required this.store,
    this.initialConfig,
    this.transport,
  });

  final ProjectStore store;

  /// 测试可注入；为空时自动从本地设置读取。
  final AiConfig? initialConfig;

  /// 测试可注入假的网络层。
  final AiTransport? transport;

  @override
  State<AiChatPage> createState() => _AiChatPageState();
}

enum _EntryKind { user, assistant, error }

class _ChatEntry {
  _ChatEntry.user(this.text)
      : kind = _EntryKind.user,
        result = null,
        raw = '';

  _ChatEntry.assistant(this.text, this.raw, this.result)
      : kind = _EntryKind.assistant;

  _ChatEntry.error(this.text)
      : kind = _EntryKind.error,
        result = null,
        raw = '';

  final _EntryKind kind;
  final String text;
  final String raw;
  final BlueprintResult? result;
}

class _AiChatPageState extends State<AiChatPage> {
  late final AiConfigStore _configStore = AiConfigStore(widget.store);
  late final AiClient _client = AiClient(transport: widget.transport);

  AiConfig _config = AiConfig.empty;
  bool _loadingConfig = true;
  bool _editingConfig = false;
  bool _saved = false;
  bool _sending = false;
  bool _testing = false;
  String? _configError;
  String? _testMessage;
  bool _testOk = false;

  final List<_ChatEntry> _entries = [];
  final TextEditingController _input = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final TextEditingController _baseUrl = TextEditingController();
  final TextEditingController _apiKey = TextEditingController();
  final TextEditingController _model = TextEditingController();

  bool get _ready => _saved && _config.isConfigured;

  @override
  void initState() {
    super.initState();
    if (widget.initialConfig != null) {
      _config = widget.initialConfig!;
      _saved = true;
      _fillConfigFields(_config);
      _loadingConfig = false;
      _editingConfig = !_ready;
    } else {
      _loadConfig();
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _baseUrl.dispose();
    _apiKey.dispose();
    _model.dispose();
    super.dispose();
  }

  void _fillConfigFields(AiConfig config) {
    _baseUrl.text = config.baseUrl;
    _apiKey.text = config.apiKey;
    _model.text = config.model;
  }

  Future<void> _loadConfig() async {
    try {
      final config = await _configStore.load();
      final saved = await _configStore.loadConfigured();
      if (!mounted) return;
      setState(() {
        _config = config;
        _saved = saved;
        _fillConfigFields(config);
        _loadingConfig = false;
        _editingConfig = !_ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingConfig = false;
        _editingConfig = true;
        _configError = L10n.t('读取 AI 设置失败：$e', 'Failed to load AI settings: $e');
      });
    }
  }

  Future<void> _saveConfig() async {
    final baseUrl = _baseUrl.text.trim();
    final model = _model.text.trim();
    if (baseUrl.isEmpty) {
      setState(() =>
          _configError = L10n.t('请填写 API 地址', 'Please enter the API base URL'));
      return;
    }
    if (model.isEmpty) {
      setState(() =>
          _configError = L10n.t('请填写模型名', 'Please enter the model name'));
      return;
    }
    if (!baseUrl.startsWith('http://') && !baseUrl.startsWith('https://')) {
      setState(() => _configError = L10n.t(
          'API 地址需要以 http:// 或 https:// 开头',
          'The API base URL must start with http:// or https://'));
      return;
    }
    final config = AiConfig(
      baseUrl: baseUrl,
      apiKey: _apiKey.text.trim(),
      model: model,
    );
    setState(() {
      _configError = null;
      _testing = true;
      _testMessage = null;
    });
    try {
      await _configStore.save(config);
      final reply = await _client.chat(
        config,
        [
          const AiMessage('user', 'Reply with the single word: ok'),
        ],
        timeout: const Duration(seconds: 40),
      );
      if (!mounted) return;
      final ok = reply.trim().isNotEmpty;
      if (ok) {
        await _configStore.markConfigured();
        if (!mounted) return;
      }
      setState(() {
        _config = config;
        _testing = false;
        _testOk = ok;
        _testMessage = _testOk
            ? L10n.t('连接成功，可以开始对话了', 'Connected. You can start chatting now')
            : L10n.t('连接成功但没有返回内容', 'Connected, but the reply was empty');
        if (_testOk) {
          _saved = true;
          _editingConfig = false;
        }
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testOk = false;
        _testMessage = L10n.t('连接失败：${e.message}', 'Connection failed: ${e.message}');
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testing = false;
        _testOk = false;
        _testMessage = L10n.t('连接失败：$e', 'Connection failed: $e');
      });
    }
  }

  Future<void> _send([String? preset]) async {
    if (_sending) return;
    if (!_ready) {
      // 没有配置 AI API 时不允许调用模型，先引导去完成设置。
      setState(() => _editingConfig = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.t(
              '请先设置 AI API，才能使用 AI 生成功能',
              'Set up the AI API before using AI generation')),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    final text = (preset ?? _input.text).trim();
    if (text.isEmpty) return;
    _input.clear();
    setState(() {
      _entries.add(_ChatEntry.user(text));
      _sending = true;
    });
    _scrollToBottom();
    try {
      final messages = <AiMessage>[
        AiMessage('system', GraphBlueprint.systemPrompt()),
        for (final e in _entries.where((e) => e.kind == _EntryKind.user).toList()
          ..removeLast())
          AiMessage('user', e.text),
        AiMessage('user', text),
      ];
      final reply = await _client.chat(_config, messages);
      if (!mounted) return;
      final result = GraphBlueprint.parse(reply);
      setState(() {
        _sending = false;
        if (result.ok) {
          _entries.add(_ChatEntry.assistant(
            L10n.t('已生成节点图：${result.graph!.name}',
                'Generated a graph: ${result.graph!.name}'),
            reply,
            result,
          ));
        } else {
          _entries.add(_ChatEntry.error(result.error ?? '解析失败'));
        }
      });
    } on AiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _entries.add(_ChatEntry.error(
            L10n.t('AI 请求失败：${e.message}', 'AI request failed: ${e.message}')));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _entries.add(_ChatEntry.error(L10n.t('AI 请求失败：$e', 'AI request failed: $e')));
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openGraph(NodeGraph graph) async {
    final fileName = await widget.store.uniqueFileName(graph.name);
    await widget.store.save(fileName, graph);
    await widget.store.registerProject(fileName, name: graph.name);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => EditorPage(initialFileName: fileName),
    ));
    if (mounted) setState(() {});
  }

  // ------------------------------------------------------------------ 界面

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF161619),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1D1D21),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L10n.t('AI 生成节点图', 'AI graph generator'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            if (_ready)
              Text(_config.model,
                  style:
                      const TextStyle(fontSize: 10, color: Color(0xFF8A8A94))),
            if (!_ready)
              Text(
                L10n.t('未设置 AI API', 'AI API not configured'),
                style:
                    const TextStyle(fontSize: 10, color: Color(0xFFFFC178)),
              ),
          ],
        ),
        actions: [
          IconButton(
            key: const ValueKey('ai-settings'),
            tooltip: L10n.t('AI 设置', 'AI settings'),
            onPressed: () => setState(() {
              _fillConfigFields(_config);
              _editingConfig = true;
              _configError = null;
              _testMessage = null;
            }),
            icon: const Icon(Icons.tune_rounded, size: 20),
          ),
          if (_entries.isNotEmpty)
            IconButton(
              tooltip: L10n.t('清空对话', 'Clear chat'),
              onPressed: () => setState(_entries.clear),
              icon: const Icon(Icons.delete_sweep_outlined, size: 20),
            ),
        ],
      ),
      body: _loadingConfig
          ? const Center(
              child: SizedBox(
                  width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)))
          : Column(
              children: [
                if (_editingConfig)
                  Expanded(child: _configPanel())
                else ...[
                  Expanded(child: _chatList()),
                  _composer(),
                ],
              ],
            ),
    );
  }

  Widget _configPanel() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
      children: [
        if (!_ready) ...[
          Container(
            key: const ValueKey('ai-not-configured'),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2118),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6B4E2A)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 17, color: Color(0xFFFFC178)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      L10n.t('还没有设置 AI API',
                          'AI API is not configured yet'),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                Text(
                  L10n.t(
                      '先完成下面的配置并测试连接，才能使用 AI 对话生成节点图。',
                      'Complete the setup below and test the connection before using AI graph generation.'),
                  style: const TextStyle(
                      fontSize: 11.5, height: 1.5, color: Color(0xFFE2C9A0)),
                ),
                const SizedBox(height: 8),
                for (final step in [
                  L10n.t('① 填写接口地址和模型名',
                      '1. Enter the API base URL and model'),
                  L10n.t('② 填写 API Key（本地模型可留空）',
                      '2. Enter the API key (optional for local models)'),
                  L10n.t('③ 点「保存并测试连接」，成功后自动进入对话',
                      '3. Tap "Save and test connection" to start chatting'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 3),
                    child: Text(step,
                        style: const TextStyle(
                            fontSize: 11,
                            height: 1.45,
                            color: Color(0xFFCDB99B))),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1D2430),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF2C3A4E)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Icon(Icons.auto_awesome,
                    size: 17, color: Color(0xFF7AB8FF)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    L10n.t('自定义 AI API', 'Custom AI API'),
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                L10n.t(
                    '支持 OpenAI 兼容的接口（OpenAI、DeepSeek、通义、Kimi、Ollama 等）。设置只保存在本机，不会上传；API Key 只用于向这个地址发起请求。',
                    'Works with OpenAI-compatible endpoints (OpenAI, DeepSeek, Qwen, Kimi, Ollama, ...). Settings stay on this device and the API key is only sent to the endpoint you enter.'),
                style: const TextStyle(
                    fontSize: 11.5, height: 1.5, color: Color(0xFF9FB0C8)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('ai-base-url'),
          controller: _baseUrl,
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            labelText: L10n.t('API 地址', 'API base URL'),
            hintText: 'https://api.openai.com/v1',
            helperText: L10n.t('以 /v1 结尾，或直接填完整的 /chat/completions 地址',
                'Ends with /v1, or paste the full /chat/completions URL'),
            helperStyle: const TextStyle(fontSize: 10.5),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('ai-api-key'),
          controller: _apiKey,
          obscureText: true,
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            labelText: L10n.t('API Key', 'API key'),
            hintText: L10n.t('本地模型可以留空', 'Leave empty for local models'),
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('ai-model'),
          controller: _model,
          style: const TextStyle(fontSize: 12.5),
          decoration: InputDecoration(
            labelText: L10n.t('模型名', 'Model'),
            hintText: 'gpt-4o-mini / deepseek-chat / qwen-plus ...',
            isDense: true,
            border: const OutlineInputBorder(),
          ),
        ),
        if (_configError != null) ...[
          const SizedBox(height: 10),
          Text(_configError!,
              style: const TextStyle(fontSize: 11.5, color: Color(0xFFE58A8A))),
        ],
        if (_testMessage != null) ...[
          const SizedBox(height: 10),
          Text(
            _testMessage!,
            style: TextStyle(
                fontSize: 11.5,
                color: _testOk
                    ? const Color(0xFF6FE08A)
                    : const Color(0xFFE58A8A)),
          ),
        ],
        const SizedBox(height: 16),
        Wrap(spacing: 10, runSpacing: 8, children: [
          FilledButton.icon(
            key: const ValueKey('ai-save'),
            onPressed: _testing ? null : _saveConfig,
            icon: _testing
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.check_rounded, size: 18),
            label: Text(_testing
                ? L10n.t('测试连接中…', 'Testing...')
                : L10n.t('保存并测试连接', 'Save and test connection')),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3F8F62),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
            ),
          ),
          if (_ready)
            OutlinedButton.icon(
              onPressed: () => setState(() => _editingConfig = false),
              icon: const Icon(Icons.chat_bubble_outline, size: 16),
              label: Text(L10n.t('返回对话', 'Back to chat')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFB6C4DE),
                side: const BorderSide(color: Color(0xFF3A3A46)),
                minimumSize: const Size(0, 40),
              ),
            ),
        ]),
        const SizedBox(height: 18),
        Text(
          L10n.t(
              '示例地址：\nOpenAI   https://api.openai.com/v1\nDeepSeek   https://api.deepseek.com/v1\nOllama   http://localhost:11434/v1',
              'Examples:\nOpenAI   https://api.openai.com/v1\nDeepSeek   https://api.deepseek.com/v1\nOllama   http://localhost:11434/v1'),
          style: const TextStyle(
              fontSize: 10.5, height: 1.6, color: Color(0xFF6E7E96)),
        ),
      ],
    );
  }

  Widget _chatList() {
    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
      children: [
        if (_entries.isEmpty)
          _welcomeCard()
        else
          for (final e in _entries)
            switch (e.kind) {
              _EntryKind.user => _userBubble(e.text),
              _EntryKind.error => _errorBubble(e.text),
              _EntryKind.assistant => _assistantEntry(e),
            },
        if (_sending)
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Row(children: [
              const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 10),
              Text(L10n.t('正在生成节点图…', 'Generating the graph…'),
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9A9AA4))),
            ]),
          ),
      ],
    );
  }

  Widget _welcomeCard() {
    if (!_ready) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF2A2118),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF6B4E2A)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                L10n.t('先设置 AI API，才能开始对话',
                    'Set up the AI API to start chatting'),
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              L10n.t(
                  '填好接口地址、API Key 和模型名，保存并测试连接成功后，就可以让 AI 根据描述生成节点图了。',
                  'Fill in the base URL, API key and model, then save and test the connection to let the AI build node graphs from your description.'),
              style: const TextStyle(
                  fontSize: 11.5, height: 1.5, color: Color(0xFFE2C9A0)),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              key: const ValueKey('ai-go-config'),
              onPressed: () => setState(() => _editingConfig = true),
              icon: const Icon(Icons.settings_outlined, size: 16),
              label: Text(L10n.t('去设置 AI API', 'Set up AI API')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3F8F62),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 36),
              ),
            ),
          ],
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B20),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2E2E38)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L10n.t('描述你想要的程序，AI 帮你搭节点图',
                  'Describe a program, the AI builds the node graph'),
              style:
                  const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(
            L10n.t(
                '生成的图会先经过校验，然后可以直接在画布中打开、修改、运行。',
                'The generated graph is validated first, then opens in the canvas where you can edit and run it.'),
            style: const TextStyle(
                fontSize: 11.5, height: 1.5, color: Color(0xFF9A9AA4)),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final example in [
              L10n.t('写一个 1 到 10 求和的程序', 'Sum the numbers from 1 to 10'),
              L10n.t('计算 5 的阶乘并打印', 'Compute 5 factorial and print it'),
              L10n.t('判断 97 是不是素数', 'Check whether 97 is a prime'),
            ])
              ActionChip(
                label: Text(example,
                    style: const TextStyle(fontSize: 11)),
                backgroundColor: const Color(0xFF22222A),
                side: const BorderSide(color: Color(0xFF34343E)),
                onPressed: () => _send(example),
              ),
          ]),
        ],
      ),
    );
  }

  Widget _userBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 4, left: 40),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF28503A),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(4),
          ),
          border: Border.all(color: const Color(0xFF356B4C)),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12.5, height: 1.45)),
      ),
    );
  }

  Widget _errorBubble(String text) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 10, right: 24),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFF2C1E1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF5A2E2E)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 15, color: Color(0xFFE58A8A)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12, height: 1.45, color: Color(0xFFE5A8A8))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _assistantEntry(_ChatEntry entry) {
    final result = entry.result;
    if (result == null || !result.ok) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(top: 10, right: 24),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF1F1F25),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF32323C)),
          ),
          child: Text(entry.text,
              style: const TextStyle(fontSize: 12.5, height: 1.45)),
        ),
      );
    }
    final graph = result.graph!;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(top: 12, right: 10, bottom: 4),
        padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2A20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2F5A40)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.account_tree_rounded,
                  size: 16, color: Color(0xFF6FE08A)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  graph.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ]),
            const SizedBox(height: 4),
            Text(GraphBlueprint.describe(graph),
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF9FB8A8))),
            if (result.warnings.isNotEmpty) ...[
              const SizedBox(height: 8),
              for (final w in result.warnings.take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('· ',
                          style: TextStyle(
                              fontSize: 10.5, color: Color(0xFFFFC178))),
                      Expanded(
                        child: Text(w,
                            style: const TextStyle(
                                fontSize: 10.5,
                                height: 1.4,
                                color: Color(0xFFFFC178))),
                      ),
                    ],
                  ),
                ),
            ],
            const SizedBox(height: 10),
            Wrap(spacing: 8, children: [
              FilledButton.icon(
                key: const ValueKey('ai-open-graph'),
                onPressed: () => _openGraph(graph),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(L10n.t('打开到画布', 'Open in canvas')),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF3F8F62),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
              TextButton(
                onPressed: () => _send(L10n.t('再生成一版，换个写法',
                    'Generate another version')),
                child: Text(L10n.t('再来一版', 'Regenerate'),
                    style: const TextStyle(fontSize: 11.5)),
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 10, 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFF2A2A32))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('ai-input'),
              controller: _input,
              readOnly: !_ready,
              onTap: () {
                if (!_ready) setState(() => _editingConfig = true);
              },
              minLines: 1,
              maxLines: 4,
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: _ready
                    ? L10n.t('描述你想要的程序，例如「1 到 100 求和」…',
                        'Describe the program you want, e.g. "sum 1 to 100"')
                    : L10n.t('请先设置 AI API 才能使用 AI 功能',
                        'Set up the AI API first to use AI features'),
                hintStyle: const TextStyle(fontSize: 11.5),
                filled: true,
                fillColor: const Color(0xFF1D1D23),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF34343E)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF34343E)),
                ),
              ),
              onSubmitted: (_) => _send(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const ValueKey('ai-send'),
            tooltip: _ready
                ? L10n.t('发送', 'Send')
                : L10n.t('请先设置 AI API', 'Set up the AI API first'),
            onPressed: _sending ? null : () => _send(),
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF3F8F62),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFF2A2A32),
            ),
            icon: const Icon(Icons.arrow_upward_rounded, size: 19),
          ),
        ],
      ),
    );
  }
}
