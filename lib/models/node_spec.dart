import 'package:flutter/material.dart';

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
        return '执行';
      case PortType.number:
        return '数字';
      case PortType.string:
        return '文本';
      case PortType.boolean:
        return '布尔';
      case PortType.any:
        return '任意';
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
  for (final part in raw.split(RegExp(r'[,，、\s]+'))) {
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
      {this.defaultValue = '0', this.hint = '数字'})
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
      return '流程';
    case NodeCategory.data:
      return '数据';
    case NodeCategory.math:
      return '运算';
    case NodeCategory.control:
      return '控制';
    case NodeCategory.function:
      return '函数';
  }
}

/// 节点类型注册表。
class NodeRegistry {
  static final Map<String, NodeSpec> byType = {
    'start': const NodeSpec(
      type: 'start',
      title: '开始',
      subtitle: '程序入口',
      category: NodeCategory.flow,
      outputs: [PortSpec('out', '执行', PortType.exec)],
    ),
    'print': const NodeSpec(
      type: 'print',
      title: '打印',
      subtitle: 'print(...)',
      category: NodeCategory.flow,
      inputs: [
        PortSpec('in', '', PortType.exec),
        PortSpec('value', '值', PortType.any, defaultLiteral: '"Hello"'),
      ],
      outputs: [PortSpec('out', '', PortType.exec)],
    ),
    'assign': const NodeSpec(
      type: 'assign',
      title: '变量赋值',
      subtitle: 'name = value',
      category: NodeCategory.data,
      inputs: [
        PortSpec('in', '', PortType.exec),
        PortSpec('value', '值', PortType.any, defaultLiteral: '0'),
      ],
      outputs: [PortSpec('out', '', PortType.exec)],
      fields: [NodeField.text('name', '变量名', defaultValue: 'x')],
    ),
    'var': const NodeSpec(
      type: 'var',
      title: '读取变量',
      category: NodeCategory.data,
      outputs: [PortSpec('value', '值', PortType.any)],
      fields: [NodeField.text('name', '变量名', defaultValue: 'x')],
    ),
    'number': const NodeSpec(
      type: 'number',
      title: '数字',
      category: NodeCategory.data,
      outputs: [PortSpec('value', '值', PortType.number)],
      fields: [NodeField.number('value', '数值', defaultValue: '0')],
    ),
    'text': const NodeSpec(
      type: 'text',
      title: '文本',
      category: NodeCategory.data,
      outputs: [PortSpec('value', '值', PortType.string)],
      fields: [NodeField.text('value', '内容', defaultValue: 'hello')],
    ),
    'bool': const NodeSpec(
      type: 'bool',
      title: '布尔',
      category: NodeCategory.data,
      outputs: [PortSpec('value', '值', PortType.boolean)],
      fields: [
        NodeField.select('value', '值', ['true', 'false'], defaultValue: 'true')
      ],
    ),
    'math': const NodeSpec(
      type: 'math',
      title: '算术运算',
      category: NodeCategory.math,
      inputs: [
        PortSpec('a', 'A', PortType.any, defaultLiteral: '0'),
        PortSpec('b', 'B', PortType.any, defaultLiteral: '0'),
      ],
      outputs: [PortSpec('result', '结果', PortType.any)],
      fields: [
        NodeField.select('op', '运算符', ['+', '-', '*', '/', '%', '^', '..'],
            defaultValue: '+')
      ],
    ),
    'compare': const NodeSpec(
      type: 'compare',
      title: '比较',
      category: NodeCategory.math,
      inputs: [
        PortSpec('a', 'A', PortType.any, defaultLiteral: '0'),
        PortSpec('b', 'B', PortType.any, defaultLiteral: '0'),
      ],
      outputs: [PortSpec('result', '结果', PortType.boolean)],
      fields: [
        NodeField.select(
            'op', '运算符', ['==', '~=', '<', '>', '<=', '>='], defaultValue: '==')
      ],
    ),
    'logic': const NodeSpec(
      type: 'logic',
      title: '逻辑',
      category: NodeCategory.math,
      inputs: [
        PortSpec('a', 'A', PortType.boolean, defaultLiteral: 'true'),
        PortSpec('b', 'B', PortType.boolean, defaultLiteral: 'false'),
      ],
      outputs: [PortSpec('result', '结果', PortType.boolean)],
      fields: [
        NodeField.select('op', '运算符', ['and', 'or', 'not'], defaultValue: 'and')
      ],
    ),
    'if': const NodeSpec(
      type: 'if',
      title: '条件分支',
      subtitle: 'if / else',
      category: NodeCategory.control,
      inputs: [
        PortSpec('in', '', PortType.exec),
        PortSpec('cond', '条件', PortType.boolean, defaultLiteral: 'true'),
      ],
      outputs: [
        PortSpec('then', '真', PortType.exec),
        PortSpec('else', '假', PortType.exec),
      ],
    ),
    'for': const NodeSpec(
      type: 'for',
      title: 'for 循环',
      category: NodeCategory.control,
      inputs: [
        PortSpec('in', '', PortType.exec),
        PortSpec('from', '起始', PortType.number, defaultLiteral: '1'),
        PortSpec('to', '终止', PortType.number, defaultLiteral: '10'),
        PortSpec('step', '步长', PortType.number, defaultLiteral: '1'),
      ],
      outputs: [
        PortSpec('body', '循环体', PortType.exec),
        PortSpec('done', '之后', PortType.exec),
      ],
      fields: [NodeField.text('var', '循环变量', defaultValue: 'i')],
    ),
    'while': const NodeSpec(
      type: 'while',
      title: 'while 循环',
      category: NodeCategory.control,
      inputs: [
        PortSpec('in', '', PortType.exec),
        PortSpec('cond', '条件', PortType.boolean, defaultLiteral: 'true'),
      ],
      outputs: [
        PortSpec('body', '循环体', PortType.exec),
        PortSpec('done', '之后', PortType.exec),
      ],
    ),
    'func': const NodeSpec(
      type: 'func',
      title: '定义函数',
      category: NodeCategory.function,
      inputs: [PortSpec('in', '', PortType.exec)],
      outputs: [
        PortSpec('body', '函数体', PortType.exec),
        PortSpec('done', '之后', PortType.exec),
      ],
      fields: [
        NodeField.text('name', '函数名', defaultValue: 'myFunc'),
        NodeField.text('params', '参数',
            defaultValue: '', hint: '逗号分隔，例如 a, b'),
      ],
    ),
    'call': const NodeSpec(
      type: 'call',
      title: '调用函数',
      subtitle: 'name(args)',
      category: NodeCategory.function,
      inputs: [
        PortSpec('in', '', PortType.exec),
        PortSpec('arg1', '参数1', PortType.any, defaultLiteral: ''),
        PortSpec('arg2', '参数2', PortType.any, defaultLiteral: ''),
        PortSpec('arg3', '参数3', PortType.any, defaultLiteral: ''),
      ],
      outputs: [
        PortSpec('out', '', PortType.exec),
        PortSpec('ret', '返回值', PortType.any),
      ],
      fields: [NodeField.text('name', '函数名', defaultValue: 'myFunc')],
    ),
    'stop': const NodeSpec(
      type: 'stop',
      title: '结束',
      subtitle: 'return',
      category: NodeCategory.flow,
      inputs: [
        PortSpec('in', '', PortType.exec),
        PortSpec('value', '返回值', PortType.any, defaultLiteral: ''),
      ],
    ),
    'comment': const NodeSpec(
      type: 'comment',
      title: '注释',
      category: NodeCategory.data,
      fields: [NodeField.text('text', '内容', defaultValue: '说明', hint: '注释')],
    ),
  };

  static NodeSpec of(String type) =>
      byType[type] ?? byType['comment']!;

  static List<NodeSpec> get all => byType.values.toList();
}
