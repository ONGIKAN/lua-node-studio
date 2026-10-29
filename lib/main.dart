import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'l10n/l10n.dart';
import 'l10n/language_store.dart';
import 'ui/project_manager_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF1D1D21),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF141416),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  // 恢复上次选择的界面语言；读取失败时保持中文。
  await LanguageStore.load();
  runApp(const LuaNodeApp());
}

class LuaNodeApp extends StatefulWidget {
  const LuaNodeApp({super.key, this.home});

  /// 测试或二次开发时可以指定首页；默认进入项目管理页。
  final Widget? home;

  @override
  State<LuaNodeApp> createState() => _LuaNodeAppState();
}

class _LuaNodeAppState extends State<LuaNodeApp> {
  @override
  void initState() {
    super.initState();
    L10n.listenable.addListener(_onLanguageChanged);
  }

  void _onLanguageChanged() => setState(() {});

  @override
  void dispose() {
    L10n.listenable.removeListener(_onLanguageChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: L10n.t('Lua 节点工作室', 'Lua Node Studio'),
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B7DD8),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF161619),
        dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF26262B)),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF2E2E34),
          contentTextStyle: TextStyle(fontSize: 12, color: Color(0xFFE8E8EE)),
        ),
        textTheme: base.textTheme.apply(
          bodyColor: const Color(0xFFE8E8EE),
          displayColor: const Color(0xFFE8E8EE),
        ),
      ),
      home: widget.home ?? const ProjectManagerPage(),
    );
  }
}
