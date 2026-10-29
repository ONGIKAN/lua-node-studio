import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/graph.dart';

/// 简易本地工程存储：应用文档目录 / LuaNodeStudio/*.json
class ProjectStore {
  ProjectStore({Directory? directory}) : _overrideDir = directory;

  /// 测试时可指定目录，避免依赖 path_provider 插件。
  final Directory? _overrideDir;
  Directory? _cached;

  Future<Directory> _dir() async {
    if (_cached != null) return _cached!;
    final Directory dir;
    if (_overrideDir != null) {
      dir = _overrideDir;
    } else {
      final base = await getApplicationDocumentsDirectory();
      dir = Directory('${base.path}${Platform.pathSeparator}LuaNodeStudio');
    }
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

  // ------------------------------------------------------------- 项目管理

  static const String _metaFileName = '__projects.json';

  Future<File> _projectsMetaFile() async {
    final dir = await _dir();
    return File('${dir.path}${Platform.pathSeparator}$_metaFileName');
  }

  Future<Map<String, dynamic>> _readProjectMeta() async {
    try {
      final f = await _projectsMetaFile();
      if (!await f.exists()) return {};
      final raw = await f.readAsString();
      final map = jsonDecode(raw);
      return map is Map<String, dynamic> ? map : {};
    } catch (_) {
      return {};
    }
  }

  Future<void> _writeProjectMeta(Map<String, dynamic> meta) async {
    try {
      final f = await _projectsMetaFile();
      await f.writeAsString(jsonEncode(meta));
    } catch (_) {
      // 元数据写失败不影响工程本身的读写
    }
  }

  /// 列出所有用户工程（不含 `__` 开头的内部文件），按修改时间倒序。
  Future<List<ProjectInfo>> listProjects() async {
    final dir = await _dir();
    final meta = await _readProjectMeta();
    final infos = <ProjectInfo>[];
    await for (final e in dir.list()) {
      if (e is! File) continue;
      final fileName = e.path.split(Platform.pathSeparator).last;
      if (!fileName.endsWith('.json')) continue;
      final name = fileName.substring(0, fileName.length - 5);
      if (name.startsWith('__')) continue;
      DateTime modified;
      try {
        modified = (await e.stat()).modified;
      } catch (_) {
        modified = DateTime.fromMillisecondsSinceEpoch(0);
      }
      final metaEntry = meta[name];
      final displayName =
          (metaEntry is Map && metaEntry['name'] is String)
              ? metaEntry['name'] as String
              : name;
      final g = await load(name);
      infos.add(ProjectInfo(
        fileName: name,
        name: displayName,
        updatedAt: modified,
        nodeCount: g?.nodes.length ?? 0,
      ));
    }
    infos.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return infos;
  }

  /// 登记/更新一个用户工程在项目列表里的展示名与更新时间。
  Future<void> registerProject(String fileName, {required String name}) async {
    final meta = await _readProjectMeta();
    meta[fileName] = {
      'name': name,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    await _writeProjectMeta(meta);
  }

  /// 删除工程文件与它的元数据。
  Future<void> forgetProject(String fileName) async {
    await delete(fileName);
    final meta = await _readProjectMeta();
    meta.remove(fileName);
    await _writeProjectMeta(meta);
  }

  /// 重命名工程：同时改文件名、JSON 内的图名和元数据。
  Future<String?> renameProject(String fileName, String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) return null;
    final target = await uniqueFileName(trimmed);
    if (target == fileName) {
      // 只是改图名
      final g = await load(fileName);
      if (g != null) {
        g.name = trimmed;
        await save(fileName, g);
      }
      await registerProject(fileName, name: trimmed);
      return fileName;
    }
    final g = await load(fileName);
    if (g == null) return null;
    g.name = trimmed;
    await save(target, g);
    await delete(fileName);
    final meta = await _readProjectMeta();
    meta.remove(fileName);
    await _writeProjectMeta(meta);
    await registerProject(target, name: trimmed);
    return target;
  }

  /// 把一段 JSON 文本导入成工程，返回文件名；JSON 非法时抛出 [FormatException]。
  Future<String> importJson(String raw, {String? name}) async {
    final map = jsonDecode(raw);
    if (map is! Map<String, dynamic>) {
      throw const FormatException('工程文件应当是一个 JSON 对象');
    }
    final g = NodeGraph.fromJson(map);
    final fileName = await uniqueFileName(
        (name ?? g.name).trim().isEmpty ? '导入的工程' : (name ?? g.name).trim());
    if (g.name.trim().isEmpty) g.name = fileName;
    await save(fileName, g);
    await registerProject(fileName, name: g.name);
    return fileName;
  }

  /// 生成一个不冲突的安全文件名（已存在时追加 -2、-3…）。
  Future<String> uniqueFileName(String desired) async {
    final base = desired
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    final safe = base.isEmpty ? '未命名' : base;
    final dir = await _dir();
    var candidate = safe;
    var i = 2;
    while (await File('${dir.path}${Platform.pathSeparator}$candidate.json')
        .exists()) {
      candidate = '$safe-$i';
      i++;
    }
    return candidate;
  }

  /// 判断是否存在上次自动保存。
  Future<bool> hasAutosave() async {
    try {
      final f = await _file('__autosave');
      return await f.exists();
    } catch (_) {
      return false;
    }
  }

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

/// 项目列表里的一条用户工程。
class ProjectInfo {
  const ProjectInfo({
    required this.fileName,
    required this.name,
    required this.updatedAt,
    required this.nodeCount,
  });

  final String fileName;
  final String name;
  final DateTime updatedAt;
  final int nodeCount;
}
