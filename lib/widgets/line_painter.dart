// lib/widgets/line_painter.dart

import 'dart:math';
import 'package:drag_and_drop/models/item.dart';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

class LineAndArrowPainter extends CustomPainter {
  final List<Item> allItems;
  final Map<String, GlobalKey> itemKeys;
  final GlobalKey stackKey;

  LineAndArrowPainter({
    required this.allItems,
    required this.itemKeys,
    required this.stackKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stackBox = stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    final paint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    debugPrint("\n=== Repainting LineAndArrowPainter ===");

    for (final fromItem in allItems) {
      if (fromItem.nextItemId == null) continue;

      final toItem = allItems.firstWhere((i) => i.id == fromItem.nextItemId);
      if (fromItem.columnId <= 1 || toItem.columnId <= 1) {
        continue;
      }

      final fromKey = itemKeys[fromItem.id];
      final toKey = itemKeys[toItem.id];
      if (fromKey?.currentContext == null || toKey?.currentContext == null) {
        continue;
      }

      final fromBox = fromKey!.currentContext!.findRenderObject() as RenderBox;
      final toBox = toKey!.currentContext!.findRenderObject() as RenderBox;

      final globalStart = fromBox.localToGlobal(
        Offset(fromBox.size.width, fromBox.size.height / 2),
      );
      final globalEnd = toBox.localToGlobal(Offset(0, toBox.size.height / 2));

      final startPoint = stackBox.globalToLocal(globalStart);
      final endPoint = stackBox.globalToLocal(globalEnd);

      // ================================
      // CẮT LINE QUA TẤT CẢ ITEM
      // ================================
      List<Offset> segments = [startPoint, endPoint];

      for (final entry in itemKeys.entries) {
        final itemBox =
            entry.value.currentContext?.findRenderObject() as RenderBox?;
        if (itemBox == null) continue;

        final topLeft = stackBox.globalToLocal(
          itemBox.localToGlobal(Offset.zero),
        );
        final rect = Rect.fromLTWH(
          topLeft.dx,
          topLeft.dy,
          itemBox.size.width,
          itemBox.size.height,
        );

        List<Offset> newSegments = [];
        for (int i = 0; i < segments.length; i += 2) {
          final seg = _clipLineWithRect(segments[i], segments[i + 1], rect);
          if (seg.isNotEmpty) {
            newSegments.addAll(seg);
          } else {}
        }
        segments = newSegments;
      }

      // ================================
      // VẼ TỪNG ĐOẠN SAU KHI CẮT
      // ================================
      for (int i = 0; i < segments.length; i += 2) {
        final segStart = segments[i];
        final segEnd = segments[i + 1];

        final linePath = Path()
          ..moveTo(segStart.dx, segStart.dy)
          ..lineTo(segEnd.dx, segEnd.dy);

        canvas.drawPath(
          dashPath(
            linePath,
            dashArray: CircularIntervalList<double>([10.0, 5.0]),
          ),
          paint,
        );

        // Vẽ arrow head ở đoạn cuối cùng
        if (i == segments.length - 2) {
          _drawArrowHead(canvas, paint, segStart, segEnd);
        }
      }
    }
  }

  // ========================================
  // HÀM CẮT LINE BỞI RECT
  // ========================================
  List<Offset> _clipLineWithRect(Offset p1, Offset p2, Rect rect) {
    // Nếu không giao → giữ nguyên
    if (!rect.overlaps(Rect.fromPoints(p1, p2))) {
      return [p1, p2];
    }

    // Nếu cả đoạn nằm trong rect → bỏ
    if (rect.contains(p1) && rect.contains(p2)) {
      return [];
    }

    // Các cạnh rect
    final rectEdges = [
      [rect.topLeft, rect.topRight],
      [rect.topRight, rect.bottomRight],
      [rect.bottomRight, rect.bottomLeft],
      [rect.bottomLeft, rect.topLeft],
    ];

    // Tìm giao điểm
    List<Offset> intersections = [];
    for (var edge in rectEdges) {
      final ip = _lineIntersection(p1, p2, edge[0], edge[1]);
      if (ip != null) intersections.add(ip);
    }

    // Nếu không có giao điểm → giữ nguyên
    if (intersections.isEmpty) return [p1, p2];

    intersections.sort(
      (a, b) => (a - p1).distance.compareTo((b - p1).distance),
    );

    // Luôn bắt đầu từ p1 → p2, nhưng bỏ đi đoạn nằm trong rect
    List<Offset> result = [];
    Offset current = p1;

    for (var ip in intersections) {
      // kiểm tra midpoint đoạn (current, ip)
      final mid = Offset((current.dx + ip.dx) / 2, (current.dy + ip.dy) / 2);

      if (!rect.contains(mid)) {
        result.add(current);
        result.add(ip);
      }
      current = ip;
    }

    // Đoạn cuối (current → p2)
    final mid = Offset((current.dx + p2.dx) / 2, (current.dy + p2.dy) / 2);
    if (!rect.contains(mid)) {
      result.add(current);
      result.add(p2);
    }

    return result;
  }

  // Hàm tính giao điểm giữa 2 đoạn
  Offset? _lineIntersection(Offset p1, Offset p2, Offset p3, Offset p4) {
    final s1x = p2.dx - p1.dx;
    final s1y = p2.dy - p1.dy;
    final s2x = p4.dx - p3.dx;
    final s2y = p4.dy - p3.dy;

    final denom = (-s2x * s1y + s1x * s2y);
    if (denom == 0) return null; // song song

    final s = (-s1y * (p1.dx - p3.dx) + s1x * (p1.dy - p3.dy)) / denom;
    final t = (s2x * (p1.dy - p3.dy) - s2y * (p1.dx - p3.dx)) / denom;

    if (s >= 0 && s <= 1 && t >= 0 && t <= 1) {
      return Offset(p1.dx + (t * s1x), p1.dy + (t * s1y));
    }
    return null;
  }

  void _drawArrowHead(Canvas canvas, Paint paint, Offset start, Offset end) {
    const arrowSize = 12.0;
    const arrowAngle = pi * 0.2;
    final angle = atan2(end.dy - start.dy, end.dx - start.dx);

    final arrowHeadPath = Path();
    arrowHeadPath.moveTo(
      end.dx - arrowSize * cos(angle - arrowAngle),
      end.dy - arrowSize * sin(angle - arrowAngle),
    );
    arrowHeadPath.lineTo(end.dx, end.dy);
    arrowHeadPath.moveTo(
      end.dx - arrowSize * cos(angle + arrowAngle),
      end.dy - arrowSize * sin(angle + arrowAngle),
    );
    arrowHeadPath.lineTo(end.dx, end.dy);

    canvas.drawPath(arrowHeadPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
