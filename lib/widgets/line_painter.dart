// lib/widgets/line_painter.dart

import 'dart:math';
import 'package:drag_and_drop/models/connection.dart';
import 'package:flutter/material.dart';
import 'package:arrow_path/arrow_path.dart';

class LineAndArrowPainter extends CustomPainter {
  final List<Connection> connections;
  final Map<String, GlobalKey> itemKeys;
  final GlobalKey stackKey;
  final Offset? dragLineStart;
  final Offset? dragLineEnd;
  final Offset clipOffset;

  LineAndArrowPainter({
    required this.connections,
    required this.itemKeys,
    required this.stackKey,
    this.dragLineStart,
    this.dragLineEnd,
    this.clipOffset = Offset.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Dịch chuyển canvas ngược lại để hệ tọa độ khớp với Stack gốc
    canvas.translate(-clipOffset.dx, -clipOffset.dy);

    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final stackBox = stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) {
      canvas.restore();
      return;
    }

    // Vẽ các kết nối đã xác nhận
    for (var connection in connections) {
      final fromKey = itemKeys[connection.fromItemId];
      final toKey = itemKeys[connection.toItemId];

      if (fromKey?.currentContext != null && toKey?.currentContext != null) {
        final fromBox = fromKey!.currentContext!.findRenderObject() as RenderBox;
        final toBox = toKey!.currentContext!.findRenderObject() as RenderBox;

        final globalFromOffset = fromBox.localToGlobal(Offset.zero);
        final globalToOffset = toBox.localToGlobal(Offset.zero);
        
        final localFromOffset = stackBox.globalToLocal(globalFromOffset);
        final localToOffset = stackBox.globalToLocal(globalToOffset);

        final startPoint = Offset(localFromOffset.dx + fromBox.size.width, localFromOffset.dy + fromBox.size.height / 2);
        final endPoint = Offset(localToOffset.dx, localToOffset.dy + toBox.size.height / 2);
        
        Path path = Path();
        path.moveTo(startPoint.dx + 5, startPoint.dy);
        path.lineTo(endPoint.dx - 5, endPoint.dy);

        path = ArrowPath.make(path: path, tipLength: 12, tipAngle: pi * 0.2);
        
        canvas.drawPath(path, paint);
      }
    }
    
    // Vẽ đường kéo-để-kết-nối tạm thời
    if (dragLineStart != null && dragLineEnd != null) {
      final tempPaint = Paint()
        ..color = Colors.blue.withOpacity(0.7)
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(dragLineStart!, dragLineEnd!, tempPaint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant LineAndArrowPainter oldDelegate) {
    // Luôn vẽ lại khi được kích hoạt bởi setState từ việc cuộn
    return true; 
  }
}