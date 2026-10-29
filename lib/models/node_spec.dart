import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

/// 端口数据类型。exec 表示"执行流"，其余为数据流。
enum PortType { exec, number, string, boolean, any }

extension PortTypeX on PortType {
  bool get isExec => this == PortType.exec;

  Color get color {
    switch (this) {
      case PortType.exec:
        return const Color(0xFFE6E6E6);
      case PortType.number:
        return const Color(0xFF6FC3F7);
      case PortType.string:
        return const Color(0xFFFFB86C);
      case PortType.boolean:
        return const Color(0xFF9BE36D);
      case PortType.any:
        return const Color(0xFFC792EA);
    }
  }

  String get label {
    switch (this) {
      case PortType.exec:
        return L10n.t('执行', 'Exec');
      case PortType.number:
        return L10n.t('数字', 'Number');
      case PortType.string:
        return L10n.t('文本', 'Text');
      case PortType.boolean:
        return L10n.t('布尔', 'Boolean');
      case PortType.any:
        return L10n.t('任意', 'Any');
    }
  }
}

/// Lua 保留字。变量名/函数参数不能与它们重名。
const Set<String> luaKeywords = {
  'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function',
  'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return', 'then',
  'true', 'until', 'while',
};

final RegExp _identPattern = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');

/// 解析「函数参数」文本：支持中英文逗号、顿号、空格分隔。
///
/// 只保留合法且不重复的 Lua 标识符，因此节点上的参数端口不会出现非法名字。
List<String> parseParamNames(String raw) {
  final out = <String>[];
  for (final part in raw.split(RegExp(r'[,，、\\s]+'))) {
    final v = part.trim();
    if (v.isEmpty) continue;
    if (!_identPattern.hasMatch(v) || luaKeywords.contains(v)) continue;
    if (out.contains(v)) continue;
    out.add(v);
  }
  return out;
}

enum FieldKind { text, number, select }

class PortSpec {
  final String id;
  final String label;
  final PortType type;

  /// 未连线时使用的默认 Lua 表达式（原样输出）。
  final String? defaultLiteral;

  const PortSpec(this.id, this.label, this.type, {this.defaultLiteral});
}

class NodeField {
  final String id;
  final String label;
  final FieldKind kind;
  final List<String> options;
  final String defaultValue;
  final String hint;

  const NodeField.text(this.id, this.label,
      {this.defaultValue = '', this.hint = ''})
      : kind = FieldKind.text,
        options = const [];

  const NodeField.number(this.id, this.label,
      {this.defaultValue = '0', this.hint = '0'})
      : kind = FieldKind.number,
        options = const [];

  const NodeField.select(this.id, this.label, this.options,
      {String? defaultValue})
      : kind = FieldKind.select,
        defaultValue = defaultValue ?? '',
        hint = '';
}

enum NodeCategory { flow, data, math, control, function }

class NodeSpec {
  final String type;
  final String title;
  final String subtitle;
  final NodeCategory category;
  final List<PortSpec> inputs;
  final List<PortSpec> outputs;
  final List<NodeField> fields;

  const NodeSpec({
    required this.type,
    required this.title,
    this.subtitle = '',
    required this.category,
    this.inputs = const [],
    this.outputs = const [],
    this.fields = const [],
  });

  PortSpec? inputById(String id) {
    for (final p in inputs) {
      if (p.id == id) return p;
    }
    return null;
  }

  PortSpec? outputById(String id) {
    for (final p in outputs) {
      if (p.id == id) return p;
    }
    return null;
  }
}

Color categoryColor(NodeCategory c) {
  switch (c) {
    case NodeCategory.flow:
      return const Color(0xFF2F6B4F);
    case NodeCategory.data:
      return const Color(0xFF2C5170);
    case NodeCategory.math:
      return const Color(0xFF6E4F2A);
    case NodeCategory.control:
      return const Color(0xFF5B3A66);
    case NodeCategory.function:
      return const Color(0xFF4A4757);
  }
}

String categoryLabel(NodeCategory c) {
  switch (c) {
    case NodeCategory.flow:
      return L10n.t('流程', 'Flow');
    case NodeCategory.data:
      return L10n.t('数据', 'Data');
    case NodeCategory.math:
      return L10n.t('运算', 'Math');
    case NodeCategory.control:
      return L10n.t('控制', 'Control');
    case NodeCategory.function:
      return L10n.t('函数', 'Function');
  }
}

/// 节点类型注册表。
///
/// 注册表按语言各生成一份并缓存：中文界面用原始文案，英文界面用英文文案。
/// 切换语言后 [byType] 会取到另一份表，因此节点标题、端口名、字段名都会跟着变。
class NodeRegistry {
  static final Map<String, Map<String, NodeSpec>> _byLanguage = {};

  /// 当前语言的节点表。
  static Map<String, NodeSpec> get byType => _byLanguage.putIfAbsent(
        L10n.language,
        () => _build(L10n.language),
      );

  static NodeSpec of(String type) => byType[type] ?? byType['comment']!;

  static List<NodeSpec> get all => byType.values.toList();

  static Map<String, NodeSpec> _build(String language) {
    final en = language == AppLanguage.en;
    String t(String zh, String english) => en ? english : zh;

    return {
      'start': NodeSpec(
        type: 'start',
        title: t('开始', 'Start'),
        subtitle: t('程序入口', 'program entry'),
        category: NodeCategory.flow,
        outputs: [PortSpec('out', t('执行', 'exec'), PortType.exec)],
      ),
      'print': NodeSpec(
        type: 'print',
        title: t('打印', 'Print'),
        subtitle: 'print(...)',
        category: NodeCategory.flow,
        inputs: [
          PortSpec('in', '', PortType.exec),
          PortSpec('value', t('值', 'value'), PortType.any,
              defaultLiteral: '"Hello"'),
        ],
        outputs: [PortSpec('out', '', PortType.exec)],
      ),
      'assign': NodeSpec(
        type: 'assign',
        title: t('变量赋值', 'Assign'),
        subtitle: 'name = value',
        category: NodeCategory.data,
        inputs: [
          PortSpec('in', '', PortType.exec),
          PortSpec('value', t('值', 'value'), PortType.any,
              defaultLiteral: '0'),
        ],
        outputs: [PortSpec('out', '', PortType.exec)],
        fields: [
          NodeField.text('name', t('变量名', 'variable'),
              defaultValue: 'x'),
        ],
      ),
      'var': NodeSpec(
        type: 'var',
        title: t('读取变量', 'Read variable'),
        category: NodeCategory.data,
        outputs: [PortSpec('value', t('值', 'value'), PortType.any)],
        fields: [
          NodeField.text('name', t('变量名', 'variable'),
              defaultValue: 'x'),
        ],
      ),
      'number': NodeSpec(
        type: 'number',
        title: t('数字', 'Number'),
        category: NodeCategory.data,
        outputs: [PortSpec('value', t('值', 'value'), PortType.number)],
        fields: [
          NodeField.number('value', t('数值', 'value'),
              defaultValue: '0', hint: t('数字', 'number')),
        ],
      ),
      'text': NodeSpec(
        type: 'text',
        title: t('文本', 'Text'),
        category: NodeCategory.data,
        outputs: [PortSpec('value', t('值', 'value'), PortType.string)],
        fields: [
          NodeField.text('value', t('内容', 'content'), defaultValue: 'hello'),
        ],
      ),
      'bool': NodeSpec(
        type: 'bool',
        title: t('布尔', 'Boolean'),
        category: NodeCategory.data,
        outputs: [PortSpec('value', t('值', 'value'), PortType.boolean)],
        fields: [
          NodeField.select('value', t('值', 'value'), ['true', 'false'],
              defaultValue: 'true')
        ],
      ),
      'math': NodeSpec(
        type: 'math',
        title: t('算术运算', 'Arithmetic'),
        category: NodeCategory.math,
        inputs: [
          PortSpec('a', 'A', PortType.any, defaultLiteral: '0'),
          PortSpec('b', 'B', PortType.any, defaultLiteral: '0'),
        ],
        outputs: [PortSpec('result', t('结果', 'result'), PortType.any)],
        fields: [
          NodeField.select('op', t('运算符', 'operator'),
              ['+', '-', '*', '/', '%', '^', '..'],
              defaultValue: '+')
        ],
      ),
      'compare': NodeSpec(
        type: 'compare',
        title: t('比较', 'Compare'),
        category: NodeCategory.math,
        inputs: [
          PortSpec('a', 'A', PortType.any, defaultLiteral: '0'),
          PortSpec('b', 'B', PortType.any, defaultLiteral: '0'),
        ],
        outputs: [
          PortSpec('result', t('结果', 'result'), PortType.boolean)
        ],
        fields: [
          NodeField.select('op', t('运算符', 'operator'),
              ['==', '~=', '<', '>', '<=', '>='],
              defaultValue: '==')
        ],
      ),
      'logic': NodeSpec(
        type: 'logic',
        title: t('逻辑', 'Logic'),
        category: NodeCategory.math,
        inputs: [
          PortSpec('a', 'A', PortType.boolean, defaultLiteral: 'true'),
          PortSpec('b', 'B', PortType.boolean, defaultLiteral: 'false'),
        ],
        outputs: [
          PortSpec('result', t('结果', 'result'), PortType.boolean)
        ],
        fields: [
          NodeField.select('op', t('运算符', 'operator'),
              ['and', 'or', 'not'],
              defaultValue: 'and')
        ],
      ),
      'if': NodeSpec(
        type: 'if',
        title: t('条件分支', 'If'),
        subtitle: 'if / else',
        category: NodeCategory.control,
        inputs: [
          PortSpec('in', '', PortType.exec),
          PortSpec('cond', t('条件', 'condition'), PortType.boolean,
              defaultLiteral: 'true'),
        ],
        outputs: [
          PortSpec('then', t('真', 'true'), PortType.exec),
          PortSpec('else', t('假', 'false'), PortType.exec),
        ],
      ),
      'for': NodeSpec(
        type: 'for',
        title: t('for 循环', 'For loop'),
        category: NodeCategory.control,
        inputs: [
          PortSpec('in', '', PortType.exec),
          PortSpec('from', t('起始', 'start'), PortType.number,
              defaultLiteral: '1'),
          PortSpec('to', t('终止', 'end'), PortType.number,
              defaultLiteral: '10'),
          PortSpec('step', t('步长', 'step'), PortType.number,
              defaultLiteral: '1'),
        ],
        outputs: [
          PortSpec('body', t('循环体', 'body'), PortType.exec),
          PortSpec('done', t('之后', 'next'), PortType.exec),
        ],
        fields: [
          NodeField.text('var', t('循环变量', 'loop variable'),
              defaultValue: 'i'),
        ],
      ),
      'while': NodeSpec(
        type: 'while',
        title: t('while 循环', 'While loop'),
        category: NodeCategory.control,
        inputs: [
          PortSpec('in', '', PortType.exec),
          PortSpec('cond', t('条件', 'condition'), PortType.boolean,
              defaultLiteral: 'true'),
        ],
        outputs: [
          PortSpec('body', t('循环体', 'body'), PortType.exec),
          PortSpec('done', t('之后', 'next'), PortType.exec),
        ],
      ),
      'func': NodeSpec(
        type: 'func',
        title: t('定义函数', 'Define function'),
        category: NodeCategory.function,
        inputs: [PortSpec('in', '', PortType.exec)],
        outputs: [
          PortSpec('body', t('函数体', 'body'), PortType.exec),
          PortSpec('done', t('之后', 'next'), PortType.exec),
        ],
        fields: [
          NodeField.text('name', t('函数名', 'name'),
              defaultValue: 'myFunc'),
          NodeField.text('params', t('参数', 'params'),
              defaultValue: '',
              hint: t('逗号分隔，例如 a, b', 'comma separated, e.g. a, b')),
        ],
      ),
      'call': NodeSpec(
        type: 'call',
        title: t('调用函数', 'Call function'),
        subtitle: 'name(args)',
        category: NodeCategory.function,
        inputs: [
          PortSpec('in', '', PortType.exec),
          PortSpec('arg1', t('参数1', 'arg 1'), PortType.any,
              defaultLiteral: ''),
          PortSpec('arg2', t('参数2', 'arg 2'), PortType.any,
              defaultLiteral: ''),
          PortSpec('arg3', t('参数3', 'arg 3'), PortType.any,
              defaultLiteral: ''),
        ],
        outputs: [
          PortSpec('out', '', PortType.exec),
          PortSpec('ret', t('返回值', 'return'), PortType.any),
        ],
        fields: [
          NodeField.text('name', t('函数名', 'name'),
              defaultValue: 'myFunc'),
        ],
      ),
      'stop': NodeSpec(
        type: 'stop',
        title: t('结束', 'Return'),
        subtitle: 'return',
        category: NodeCategory.flow,
        inputs: [
          PortSpec('in', '', PortType.exec),
          PortSpec('value', t('返回值', 'value'), PortType.any,
              defaultLiteral: ''),
        ],
      ),
      'comment': NodeSpec(
        type: 'comment',
        title: t('注释', 'Comment'),
        category: NodeCategory.data,
        fields: [
          NodeField.text('text', t('内容', 'text'),
              defaultValue: t('说明', 'note'), hint: t('注释', 'comment')),
        ],
      ),
    };
  }
}
