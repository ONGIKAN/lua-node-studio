import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/graph.dart';

/// 简易本地工程存储：应用文档目录 / LuaNodeStudio/*.json
class ProjectStore {
  Directory? _cached;

  Future<Directory> _dir() async {
    if (_cached != null) return _cached!;
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory('${base.path}${Platform.pathSeparator}LuaNodeStudio');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _cached = dir;
    return dir;
  }

  Future<File> _file(String name) async {
    final dir = await _dir();
    final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return File('${dir.path}${Platform.pathSeparator}$safe.json');
  }

  Future<void> save(String name, NodeGraph graph) async {
    final f = await _file(name);
    await f.writeAsString(jsonEncode(graph.toJson()));
  }

  Future<NodeGraph?> load(String name) async {
    try {
      final f = await _file(name);
      if (!await f.exists()) return null;
      final raw = await f.readAsString();
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return NodeGraph.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  Future<List<String>> list() async {
    final dir = await _dir();
    final files = await dir
        .list()
        .where((e) => e is File && e.path.endsWith('.json'))
        .toList();
    final names = files
        .map((e) => e.path.split(Platform.pathSeparator).last.replaceAll('.json', ''))
        .where((n) => !n.startsWith('__'))
        .toList()
      ..sort();
    return names;
  }

  Future<void> delete(String name) async {
    final f = await _file(name);
    if (await f.exists()) await f.delete();
  }

  Future<String> directoryPath() async => (await _dir()).path;

  // ------------------------------------------------------------- 设置项

  /// 设置保存在 `__settings.json`，文件名以 `__` 开头，不会出现在工程列表里。
  Future<File> _settingsFile() async {
    final dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}__settings.json');
  }

  Future<Map<String, dynamic>> _readSettings() async {
    try {
      final f = await _settingsFile();
      if (!await f.exists()) return {};
      final raw = await f.readAsString();
      final map = jsonDecode(raw);
      return map is Map<String, dynamic> ? map : {};
    } catch (_) {
      return {};
    }
  }

  Future<String?> loadSetting(String key) async {
    final map = await _readSettings();
    final v = map[key];
    return v is String ? v : null;
  }

  Future<void> saveSetting(String key, String value) async {
    final map = await _readSettings();
    map[key] = value;
    try {
      final f = await _settingsFile();
      await f.writeAsString(jsonEncode(map));
    } catch (_) {
      // 写设置失败不影响主流程
    }
  }
}
