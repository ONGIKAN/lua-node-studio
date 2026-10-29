import 'package:flutter/foundation.dart';

import '../storage/project_store.dart';
import 'l10n.dart';

/// 语言选择的本地持久化。
///
/// 设置文件和工程文件放在同一个应用目录里（文件名以 `__` 开头，
/// 因此不会出现在「打开工程」的列表里）。测试环境没有 path_provider
/// 插件时会静默失败，不影响程序运行。
class LanguageStore {
  LanguageStore._();

  static const String _key = 'language';

  /// 读取上次选择的语言；读取失败时保持默认中文。
  static Future<void> load() async {
    try {
      final saved = await ProjectStore().loadSetting(_key);
      if (saved != null && AppLanguage.all.contains(saved)) {
        L10n.setLanguage(saved);
      }
    } catch (e) {
      debugPrint('读取语言设置失败：$e');
    }
  }

  /// 切换语言并写入本地设置。
  static Future<void> apply(String code) async {
    L10n.setLanguage(code);
    try {
      await ProjectStore().saveSetting(_key, code);
    } catch (e) {
      debugPrint('保存语言设置失败：$e');
    }
  }
}
