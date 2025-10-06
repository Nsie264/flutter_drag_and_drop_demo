// lib/widgets/line_painter.dart

import 'dart:math';
import 'package:collection/collection.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

class LineAndArrowPainter extends CustomPainter {
  final List<Item> allItems;
  final Map<String, GlobalKey> itemKeys;
  final GlobalKey stackKey;
  final Set<String> highlightedItemIds;

  LineAndArrowPainter({
    required this.allItems,
    required this.itemKeys,
    required this.stackKey,
    this.highlightedItemIds = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    final stackBox = stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    // Định nghĩa 2 loại Paint
    final defaultPaint = Paint()
      ..color = Colors.black.withOpacity(0.6)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final highlightPaint = Paint()
      ..color = Colors.red.shade600
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
      
    // Tạo 2 danh sách công việc vẽ: một cho các line bình thường, một cho highlight
    final List<List<Offset>> normalLineTasks = [];
    final List<List<Offset>> highlightedLineTasks = [];

    // LƯỢT 1: PHÂN LOẠI VÀ TÍNH TOÁN TẤT CẢ CÁC MŨI TÊN
    for (final fromItem in allItems) {
      if (fromItem.nextItemId == null) continue;

      final toItem = allItems.firstWhereOrNull((i) => i.id == fromItem.nextItemId);
      if (toItem == null || fromItem.columnId <= 1 || toItem.columnId <= 1) {
        continue;
      }

      final fromKey = itemKeys[fromItem.id];
      final toKey = itemKeys[toItem.id];
      if (fromKey?.currentContext == null || toKey?.currentContext == null) {
        continue;
      }

      final fromBox = fromKey!.currentContext!.findRenderObject() as RenderBox;
      final toBox = toKey!.currentContext!.findRenderObject() as RenderBox;

      final globalStart = fromBox.localToGlobal(Offset(fromBox.size.width, fromBox.size.height / 2));
      final globalEnd = toBox.localToGlobal(Offset(0, toBox.size.height / 2));

      final startPoint = stackBox.globalToLocal(globalStart);
      final endPoint = stackBox.globalToLocal(globalEnd);

      final bool isArrowHighlighted =
          highlightedItemIds.contains(fromItem.id) &&
          highlightedItemIds.contains(toItem.id);
      
      if (isArrowHighlighted) {
        // Nếu highlight, không cắt line, thêm vào danh sách highlight
        highlightedLineTasks.add([startPoint, endPoint]);
      } else {
        // Nếu không, áp dụng logic cắt line và thêm vào danh sách bình thường
        List<Offset> segments = [startPoint, endPoint];
        for (final entry in itemKeys.entries) {
          final itemBox = entry.value.currentContext?.findRenderObject() as RenderBox?;
          if (itemBox == null) continue;

          // Bỏ qua việc tự cắt chính nó
          if(entry.key == fromItem.id || entry.key == toItem.id) continue;

          final topLeft = stackBox.globalToLocal(itemBox.localToGlobal(Offset.zero));
          final rect = Rect.fromLTWH(topLeft.dx, topLeft.dy, itemBox.size.width, itemBox.size.height);

          List<Offset> newSegments = [];
          for (int i = 0; i < segments.length; i += 2) {
            final seg = _clipLineWithRect(segments[i], segments[i + 1], rect);
            if (seg.isNotEmpty) {
              newSegments.addAll(seg);
            }
          }
          segments = newSegments;
        }
        if (segments.isNotEmpty) {
          normalLineTasks.add(segments);
        }
      }
    }

    // LƯỢT 2: VẼ CÁC LINE BÌNH THƯỜNG (BỊ CẮT)
    for (final segments in normalLineTasks) {
      for (int i = 0; i < segments.length; i += 2) {
        final segStart = segments[i];
        final segEnd = segments[i + 1];

        final linePath = Path()
          ..moveTo(segStart.dx, segStart.dy)
          ..lineTo(segEnd.dx, segEnd.dy);

        canvas.drawPath(
          dashPath(linePath, dashArray: CircularIntervalList<double>([10.0, 5.0])),
          defaultPaint,
        );

        if (i == segments.length - 2) {
          _drawArrowHead(canvas, defaultPaint, segStart, segEnd);
        }
      }
    }

    // LƯỢT 3: VẼ CÁC LINE HIGHLIGHT (LIỀN MẠCH VÀ ĐÈ LÊN TRÊN)
    for (final segments in highlightedLineTasks) {
        final segStart = segments[0];
        final segEnd = segments[1];

        final linePath = Path()
          ..moveTo(segStart.dx, segStart.dy)
          ..lineTo(segEnd.dx, segEnd.dy);

        canvas.drawPath(linePath, highlightPaint); // Dùng nét liền
        _drawArrowHead(canvas, highlightPaint, segStart, segEnd);
    }
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

  List<Offset> _clipLineWithRect(Offset p1, Offset p2, Rect rect) {
    if (rect.contains(p1) && rect.contains(p2)) {
      return [];
    }
    
    final intersections = <Offset>[];
    if (rect.contains(p1)) intersections.add(p1);
    
    for (final edge in [
      [rect.topLeft, rect.topRight], [rect.topRight, rect.bottomRight],
      [rect.bottomRight, rect.bottomLeft], [rect.bottomLeft, rect.topLeft]
    ]) {
      final ip = _lineIntersection(p1, p2, edge[0], edge[1]);
      if (ip != null) intersections.add(ip);
    }
    
    if (rect.contains(p2)) intersections.add(p2);

    if (intersections.length < 2) return [p1, p2];

    intersections.sort((a, b) => (a - p1).distance.compareTo((b - p1).distance));
    
    final List<Offset> result = [];
    Offset current = p1;
    
    for (final ip in intersections) {
      final mid = Offset((current.dx + ip.dx) / 2, (current.dy + ip.dy) / 2);
      if (!rect.contains(mid)) {
        result.addAll([current, ip]);
      }
      current = ip;
    }
    
    final mid = Offset((current.dx + p2.dx) / 2, (current.dy + p2.dy) / 2);
    if (!rect.contains(mid)) {
      result.addAll([current, p2]);
    }

    return result;
  }

  Offset? _lineIntersection(Offset p1, Offset p2, Offset p3, Offset p4) {
    final s1x = p2.dx - p1.dx;
    final s1y = p2.dy - p1.dy;
    final s2x = p4.dx - p3.dx;
    final s2y = p4.dy - p3.dy;
    final denom = (-s2x * s1y + s1x * s2y);
    if (denom.abs() < 0.0001) return null;
    final s = (-s1y * (p1.dx - p3.dx) + s1x * (p1.dy - p3.dy)) / denom;
    final t = (s2x * (p1.dy - p3.dy) - s2y * (p1.dx - p3.dx)) / denom;
    if (s >= 0 && s <= 1 && t >= 0 && t <= 1) {
      return Offset(p1.dx + (t * s1x), p1.dy + (t * s1y));
    }
    return null;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}