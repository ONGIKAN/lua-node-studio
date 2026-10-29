import 'dart:convert';

import '../storage/project_store.dart';

/// AI 对话中的一条历史记录（用于离开页面后恢复）。
class AiSessionEntry {
  const AiSessionEntry({required this.kind, required this.text, this.raw = ''});

  /// user / assistant / error
  final String kind;
  final String text;

  /// assistant 条的原始模型回复，用来重新解析出生成的节点图。
  final String raw;

  Map<String, dynamic> toJson() => {'kind': kind, 'text': text, 'raw': raw};

  static AiSessionEntry? fromJson(Object? value) {
    if (value is! Map) return null;
    final kind = value['kind'];
    final text = value['text'];
    if (kind is! String || text is! String) return null;
    final raw = value['raw'];
    return AiSessionEntry(
      kind: kind,
      text: text,
      raw: raw is String ? raw : '',
    );
  }
}

/// 一次保存下来的 AI 对话：历史消息 + 输入框草稿。
class AiSessionData {
  const AiSessionData({this.entries = const [], this.draft = ''});

  final List<AiSessionEntry> entries;
  final String draft;

  static const AiSessionData empty = AiSessionData();
}

/// 把 AI 对话（含已经生成的节点图）保存在本机设置里。
///
/// 用户中途返回、甚至关掉应用再打开，都能继续上次的对话，不必重新生成。
class AiSessionStore {
  AiSessionStore(this.store);

  final ProjectStore store;

  static const String _key = 'ai.session';
  static const int _maxEntries = 60;

  Future<AiSessionData> load() async {
    final raw = await store.loadSetting(_key);
    if (raw == null || raw.trim().isEmpty) return AiSessionData.empty;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return AiSessionData.empty;
      final list = decoded['entries'];
      final entries = <AiSessionEntry>[];
      if (list is List) {
        for (final item in list) {
          final entry = AiSessionEntry.fromJson(item);
          if (entry != null) entries.add(entry);
        }
      }
      final draft = decoded['draft'];
      return AiSessionData(
        entries: entries.length > _maxEntries
            ? entries.sublist(entries.length - _maxEntries)
            : entries,
        draft: draft is String ? draft : '',
      );
    } catch (_) {
      return AiSessionData.empty;
    }
  }

  Future<void> save(AiSessionData data) async {
    final entries = data.entries.length > _maxEntries
        ? data.entries.sublist(data.entries.length - _maxEntries)
        : data.entries;
    await store.saveSetting(
      _key,
      jsonEncode({
        'entries': [for (final e in entries) e.toJson()],
        'draft': data.draft,
      }),
    );
  }

  Future<void> clear() => store.saveSetting(_key, '');
}
