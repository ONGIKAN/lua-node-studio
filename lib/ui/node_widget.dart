import 'package:flutter/material.dart';

import '../models/graph.dart';
import '../models/node_spec.dart';

const Color kNodeBg = Color(0xFF2A2A2E);
const Color kNodeBgAlt = Color(0xFF232327);
const Color kNodeBorder = Color(0xFF3C3C42);
const Color kAccent = Color(0xFF7AB8FF);
const Color kPortLabel = Color(0xFFB6B6BE);
const Color kFieldLabel = Color(0xFF8B8B95);
const Color kValueText = Color(0xFFE6E6EC);
const Color kChipBg = Color(0xFF1B1B1F);
const Color kLinkHint = Color(0xFF6FE08A);

/// 单个节点，只负责画面和节点内小控件（字段 / 取值）的点击。
///
/// 拖节点、拉连线、选中这些"大动作"全部交给画布按几何位置统一判定：
/// 端口 44dp 的热区一定会互相重叠，如果每个端口各挂一个 GestureDetector，
/// Flutter 会按绘制顺序取最后命中的那个，点「起始」就会连到「步长」。
/// 所以必须是全局最近端口优先。
class NodeWidget extends StatelessWidget {
  final GraphNode node;
  final bool selected;
  final double scale;
  final bool linkMode;

  final GraphLink? Function(String portId, bool isOutput) linkOf;

  const NodeWidget({
    super.key,
    required this.node,
    required this.selected,
    required this.scale,
    required this.linkMode,
    required this.linkOf,
  });

  NodeSpec get spec => node.spec;

  @override
  Widget build(BuildContext context) {
    final size = NodeLayout.sizeOf(spec);
    final p = NodeLayout.padOf(scale);
    final rows = spec.inputs.length > spec.outputs.length
        ? spec.inputs.length
        : spec.outputs.length;

    return SizedBox(
      width: size.width + p.dx * 2,
      height: size.height + p.dy * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: p.dx,
            top: p.dy,
            width: size.width,
            height: size.height,
            child: Container(
              decoration: BoxDecoration(
                color: kNodeBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? kAccent : kNodeBorder,
                  width: selected ? 1.8 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: selected
                        ? const Color(0x882F6BA8)
                        : const Color(0x66000000),
                    blurRadius: selected ? 16 : 10,
                    offset: const Offset(0, 3),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(),
                  if (rows > 0)
                    SizedBox(
                      height: rows * NodeLayout.rowH,
                      child: Column(
                        children: [
                          for (var i = 0; i < rows; i++) _portRow(i),
                        ],
                      ),
                    ),
                  if (spec.fields.isNotEmpty)
                    Padding(
                      padding: EdgeInsets.only(top: rows > 0 ? 8 : 4),
                      child: Column(
                        children: [
                          for (final f in spec.fields) _field(f),
                        ],
                      ),
                    ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          // 端口只负责画（不吃事件），命中判定在画布层统一做
          for (var i = 0; i < spec.inputs.length; i++)
            _socketDot(spec.inputs[i], NodeLayout.rowCenterY(i), false),
          for (var i = 0; i < spec.outputs.length; i++)
            _socketDot(spec.outputs[i], NodeLayout.rowCenterY(i), true),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      height: NodeLayout.headerH,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: categoryColor(spec.category),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              spec.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
          if (spec.subtitle.isNotEmpty)
            Text(
              spec.subtitle,
              style: const TextStyle(fontSize: 9, color: Colors.white54),
            ),
        ],
      ),
    );
  }

  Widget _portRow(int i) {
    final inPort = i < spec.inputs.length ? spec.inputs[i] : null;
    final outPort = i < spec.outputs.length ? spec.outputs[i] : null;
    final hasChip = inPort != null && !inPort.type.isExec;

    return SizedBox(
      height: NodeLayout.rowH,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            if (inPort != null && inPort.label.isNotEmpty)
              Text(inPort.label,
                  style: const TextStyle(fontSize: 10.5, color: kPortLabel)),
            if (hasChip)
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _literalChip(inPort),
                ),
              )
            else
              const Spacer(),
            if (outPort != null && outPort.label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  outPort.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 10.5, color: kPortLabel),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _literalChip(PortSpec port) {
    final connected = linkOf(port.id, false) != null;
    final text = node.literal(port.id);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        constraints: const BoxConstraints(minWidth: 54, maxWidth: 122),
        decoration: BoxDecoration(
          color: connected ? const Color(0xFF1B2A38) : kChipBg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
              color: connected
                  ? const Color(0xFF2F5A80)
                  : const Color(0xFF3A3A40)),
        ),
        child: Text(
          connected ? '已连线' : (text.isEmpty ? '空' : text),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10,
            height: 1.3,
            fontFamily: 'monospace',
            color: connected ? const Color(0xFF6FA8D6) : kValueText,
          ),
        ),
      );
  }

  Widget _field(NodeField f) {
    return SizedBox(
      height: NodeLayout.fieldH,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: kNodeBgAlt,
              borderRadius: BorderRadius.circular(5),
              border: Border.all(color: const Color(0xFF37373D)),
            ),
            child: Row(
              children: [
                Text(f.label,
                    style: const TextStyle(fontSize: 9.5, color: kFieldLabel)),
                const Spacer(),
                Flexible(
                  child: Text(
                    node.field(f.id),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: kValueText,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 3),
                  child: Icon(
                    f.kind == FieldKind.select
                        ? Icons.arrow_drop_down
                        : Icons.edit_outlined,
                    size: f.kind == FieldKind.select ? 14 : 11,
                    color: kFieldLabel,
                  ),
                ),
              ],
            ),
          ),
      ),
    );
  }

  Widget _socketDot(PortSpec port, double y, bool isOutput) {
    final connected = linkOf(port.id, isOutput) != null;
    final color = port.type.color;
    final visual = port.type.isExec ? 13.0 : 12.0;
    // 视觉尺寸反比补偿：缩小时端口不会被压成针尖
    final vs = (visual / scale).clamp(visual, 20.0);
    final p = NodeLayout.padOf(scale);

    return Positioned(
      left: (isOutput ? NodeLayout.width : 0) + p.dx - vs / 2,
      top: p.dy + y - vs / 2,
      width: vs,
      height: vs,
      child: IgnorePointer(
        key: ValueKey('port_${node.id}_${port.id}_${isOutput ? 'out' : 'in'}'),
        child: Transform.rotate(
          angle: port.type.isExec ? 0.7853981634 : 0,
          child: Container(
            decoration: BoxDecoration(
              color: connected ? color : const Color(0xFF1E1E22),
              borderRadius: BorderRadius.circular(port.type.isExec ? 3 : vs / 2),
              border: Border.all(
                color: linkMode ? kLinkHint : color,
                width: linkMode ? 2.4 : 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
