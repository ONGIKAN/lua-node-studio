import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/editor_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color(0xFF1D1D21),
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF141416),
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  runApp(const LuaNodeApp());
}

class LuaNodeApp extends StatelessWidget {
  const LuaNodeApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'Lua 节点工作室',
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
      home: const EditorPage(),
    );
  }
}
