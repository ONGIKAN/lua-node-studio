import 'package:flutter/foundation.dart';

/// 内置支持的语言代码。
class AppLanguage {
  static const String zh = 'zh';
  static const String en = 'en';
  static const List<String> all = [zh, en];

  /// 语言本身的名字（用它自己的语言书写，方便在英文界面里也能认出来）。
  static String label(String code) =>
      code == AppLanguage.en ? 'English' : '中文';
}

/// 全局语言状态 + 就地翻译助手。
///
/// 程序默认中文；用户在顶栏菜单里切换语言后会写入本地设置，下次启动沿用。
/// 界面文案统一用 [t] 就地写成「中文 / English」两份，节点注册表则按语言返回
/// 对应的标题、端口名和字段名。
class L10n {
  L10n._();

  static final ValueNotifier<String> notifier =
      ValueNotifier<String>(AppLanguage.zh);

  static String get language => notifier.value;

  static bool get isEnglish => language == AppLanguage.en;

  /// 语言切换后需要重建的界面注册这个 [Listenable] 即可。
  static Listenable get listenable => notifier;

  static void setLanguage(String code) {
    if (!AppLanguage.all.contains(code)) return;
    if (notifier.value == code) return;
    notifier.value = code;
  }

  static void toggle() =>
      setLanguage(isEnglish ? AppLanguage.zh : AppLanguage.en);

  /// 就地翻译：`L10n.t('节点', 'Nodes')`。
  static String t(String zh, String en) => isEnglish ? en : zh;
}
