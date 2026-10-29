import 'package:flutter/material.dart';

import '../models/node_spec.dart';

/// 节点面板：按分类列出所有节点类型。
Future<void> showNodePalette(
  BuildContext context,
  void Function(NodeSpec spec) onPick,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF232327),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) {
      final maxH = MediaQuery.of(ctx).size.height * 0.72;
      return ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxH),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
              child: Row(
                children: [
                  const Text('添加节点',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                children: [
                  for (final cat in NodeCategory.values) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: categoryColor(cat),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            categoryLabel(cat),
                            style: const TextStyle(
                                fontSize: 11, color: Color(0xFF9A9AA4)),
                          ),
                        ],
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final spec in NodeRegistry.all.where(
                            (s) => s.category == cat && s.type != 'start'))
                          _chip(ctx, spec, onPick),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

Widget _chip(BuildContext ctx, NodeSpec spec, void Function(NodeSpec) onPick) {
  return InkWell(
    borderRadius: BorderRadius.circular(8),
    onTap: () {
      Navigator.pop(ctx);
      onPick(spec);
    },
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C31),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF3A3A41)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(spec.title,
              style: const TextStyle(fontSize: 12.5, color: Colors.white)),
          if (spec.subtitle.isNotEmpty || spec.fields.isNotEmpty)
            Text(
              spec.subtitle.isNotEmpty
                  ? spec.subtitle
                  : spec.fields.first.label,
              style: const TextStyle(fontSize: 9, color: Color(0xFF8A8A94)),
            ),
        ],
      ),
    ),
  );
}
