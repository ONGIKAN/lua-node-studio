import 'dart:async';
import 'dart:isolate';

import 'package:lua_dardo_plus/lua.dart';

import '../l10n/l10n.dart';

class LuaRunResult {
  final bool success;
  final String output;
  final String? error;
  final bool timedOut;

  const LuaRunResult({
    required this.success,
    required this.output,
    this.error,
    this.timedOut = false,
  });

  static const empty = LuaRunResult(success: true, output: '');
}

/// Lua 执行后端抽象层。
///
/// 当前实现：[DartLuaEngine]（纯 Dart 实现的 Lua 5.3 虚拟机）。
/// 如果以后要换成 Rust + mlua/LuaJIT，只需新增一个实现类并替换工厂即可，
/// UI 与代码生成层不需要改动。
abstract class LuaEngine {
  String get name;
  String get version;
  Future<LuaRunResult> run(String code, {Duration timeout});
}

class DartLuaEngine implements LuaEngine {
  const DartLuaEngine();

  @override
  String get name => 'LuaDardo';

  @override
  String get version => L10n.t('Lua 5.3 (纯 Dart)', 'Lua 5.3 (pure Dart)');

  @override
  Future<LuaRunResult> run(String code,
      {Duration timeout = const Duration(seconds: 8)}) async {
    final port = ReceivePort();
    final isolate = await Isolate.spawn(
        _runIsolate, <Object>[port.sendPort, code, L10n.language]);
    final completer = Completer<List<String>>();
    final sub = port.listen((msg) {
      if (msg is List && !completer.isCompleted) {
        completer.complete(msg.cast<String>());
      }
    });

    List<String> result;
    try {
      result = await completer.future.timeout(
        timeout,
        onTimeout: () => <String>[
          'timeout',
          '',
          L10n.t('执行超时（${timeout.inSeconds} 秒），已强制中止',
              'Execution timed out (${timeout.inSeconds}s); aborted'),
        ],
      );
    } finally {
      isolate.kill(priority: Isolate.immediate);
      await sub.cancel();
      port.close();
    }

    final status = result[0];
    final output = _cap(result[1]);
    switch (status) {
      case 'ok':
        return LuaRunResult(success: true, output: output);
      case 'timeout':
        return LuaRunResult(
            success: false, output: output, error: result[2], timedOut: true);
      default:
        return LuaRunResult(success: false, output: output, error: result[2]);
    }
  }

  static String _cap(String s) => s.length > 200000
      ? '${s.substring(0, 200000)}\n'
          '${L10n.t('...（输出过长已截断）', '... (output truncated)')}'
      : s;

  static void _runIsolate(List<Object> args) {
    final send = args[0] as SendPort;
    final code = args[1] as String;
    // isolate 看不到主 isolate 的静态状态，先把语言带进来
    if (args.length > 2) L10n.setLanguage(args[2] as String);
    final buffer = StringBuffer();

    try {
      PlatformServices.instance.printCallback = (s) => buffer.write(s);

      final state = LuaState.newState();
      state.openLibs();

      final status = state.loadString(code);
      if (status != ThreadStatus.luaOk) {
        final msg = state.getTop() > 0
            ? (state.toStr(-1) ?? L10n.t('语法错误', 'Syntax error'))
            : L10n.t('语法错误', 'Syntax error');
        send.send(<String>['error', buffer.toString(), _clean(msg)]);
        return;
      }

      final callStatus = state.pCall(0, 0, 0);
      if (callStatus != ThreadStatus.luaOk) {
        final msg = state.getTop() > 0
            ? (state.toStr(-1) ?? L10n.t('运行错误', 'Runtime error'))
            : L10n.t('运行错误', 'Runtime error');
        send.send(<String>['error', buffer.toString(), _clean(msg)]);
        return;
      }

      send.send(<String>['ok', buffer.toString(), '']);
    } catch (e) {
      send.send(<String>['error', buffer.toString(), e.toString()]);
    }
  }

  static String _clean(String s) {
    var out = s;
    if (out.startsWith('[string "')) {
      // LuaDardo 会在前面加上 chunk 名，这里稍微整理一下
      final idx = out.indexOf('"]:');
      if (idx > 0) out = out.substring(idx + 3);
    }
    return out.trim();
  }
}
