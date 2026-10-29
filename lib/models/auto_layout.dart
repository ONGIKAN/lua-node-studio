import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'graph.dart';
import 'node_spec.dart';

/// 一键整理布局：执行流竖着排成主列，数据节点靠左对齐到它的使用者。
///
/// 手机屏幕窄，横向铺开的图没法用；竖排之后顺着往下滑就能读完整个程序。
void applyAutoLayout(NodeGraph g) {
  if (g.nodes.isEmpty) return;

  const double colGap = 320;
  const double rowGap = 28;
  const double padTop = 40;
  const double padLeft = 40;

  // 1) 沿执行流广度优先遍历，得到语句节点的先后顺序
  final execOrder = <String>[];
  final seen = <String>{};
  final start = g.startNode ?? g.nodes.first;
  final queue = <String>[start.id];
  while (queue.isNotEmpty) {
    final id = queue.removeAt(0);
    if (!seen.add(id)) continue;
    final n = g.byId(id);
    if (n == null) continue;
    execOrder.add(id);
    for (final p in n.spec.outputs) {
      if (!p.type.isExec) continue;
      final nx = g.nextExec(n.id, p.id);
      if (nx != null && !seen.contains(nx)) queue.add(nx);
    }
  }
  // 不在执行流上的语句节点（孤立块）排到主列末尾
  for (final n in g.nodes) {
    if (!seen.contains(n.id) && n.spec.outputs.any((p) => p.type.isExec)) {
      execOrder.add(n.id);
      seen.add(n.id);
    }
  }

  final execIndex = <String, int>{
    for (var i = 0; i < execOrder.length; i++) execOrder[i]: i
  };

  // 2) 语句节点固定在最右列，数据节点逐层往左推
  final col = <String, int>{for (final id in execOrder) id: 100};

  var progress = true;
  while (progress) {
    progress = false;
    for (final n in g.nodes) {
      if (col.containsKey(n.id)) continue;
      final outs = g.links.where((l) => l.fromNode == n.id).toList();
      if (outs.isEmpty) continue;
      if (!outs.every((l) => col.containsKey(l.toNode))) continue;
      final minCol = outs.map((l) => col[l.toNode]!).reduce(math.min);
      col[n.id] = minCol - 1;
      progress = true;
    }
  }
  for (final n in g.nodes) {
    col.putIfAbsent(n.id, () => 98); // 没人用的孤立节点
  }

  // 3) 压缩空列，避免中间出现大空洞
  final used = col.values.toSet().toList()..sort();
  final remap = <int, int>{
    for (var i = 0; i < used.length; i++) used[i]: i
  };
  for (final n in g.nodes) {
    col[n.id] = remap[col[n.id]!]!;
  }
  final maxCol = remap.length - 1;

  // 4) 从右往左定 y：先摆消费者，再让生产者对齐消费者
  final yOf = <String, double>{};
  for (var c = maxCol; c >= 0; c--) {
    final list = g.nodes.where((n) => col[n.id] == c).toList();
    if (list.isEmpty) continue;

    double preferred(GraphNode n) {
      double? y;
      for (final l in g.links) {
        if (l.fromNode != n.id) continue;
        final cy = yOf[l.toNode];
        if (cy == null) continue;
        y = y == null ? cy : math.min(y, cy);
      }
      return y ?? double.infinity;
    }

    list.sort((a, b) {
      final ia = execIndex[a.id];
      final ib = execIndex[b.id];
      if (ia != null && ib != null) return ia.compareTo(ib);
      final pa = preferred(a);
      final pb = preferred(b);
      if (pa != pb) return pa.compareTo(pb);
      return a.pos.dy.compareTo(b.pos.dy);
    });

    var y = padTop;
    for (final n in list) {
      final want = preferred(n);
      if (want.isFinite) y = math.max(y, want);
      yOf[n.id] = y;
      n.pos = Offset(padLeft + c * colGap, y);
      y += n.size.height + rowGap;
    }
  }
}
