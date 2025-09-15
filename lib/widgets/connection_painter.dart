// lib/widgets/connection_painter.dart

import 'dart:math';
import 'package:drag_and_drop/models/connection.dart';
import 'package:flutter/material.dart';
// *** THAY ĐỔI 1: Import thư viện mới ***
import 'package:arrow_path/arrow_path.dart';

class ConnectionPainter extends CustomPainter {
  final List<Connection> connections;
  final Map<String, Offset> itemPositions;
  final Offset? dragLineStart;
  final Offset? dragLineEnd;

  ConnectionPainter({
    required this.connections,
    required this.itemPositions,
    this.dragLineStart,
    this.dragLineEnd,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black54
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round; // Làm cho đầu đường kẻ tròn trịa hơn

    // Vẽ các kết nối đã xác nhận
    for (var connection in connections) {
      final start = itemPositions[connection.fromItemId];
      final end = itemPositions[connection.toItemId];
      if (start != null && end != null) {
        Path path = Path();
        path.moveTo(start.dx, start.dy);

        // Sử dụng đường cong cubic Bézier
        path.cubicTo(
            start.dx + 60, start.dy, // Control point 1
            end.dx - 60, end.dy,     // Control point 2
            end.dx, end.dy);         // End point

        
        path = ArrowPath.make(path: path, tipLength: 12, tipAngle: pi * 0.2);

        canvas.drawPath(path, paint);
      }
    }

    // Vẽ đường kéo-để-kết-nối tạm thời (không thay đổi)
    if (dragLineStart != null && dragLineEnd != null) {

      final tempPaint = Paint()
        ..color = Colors.blue
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(dragLineStart!, dragLineEnd!, tempPaint);
    }
  }

  @override
  bool shouldRepaint(covariant ConnectionPainter oldDelegate) {
    return oldDelegate.connections != connections ||
           oldDelegate.itemPositions != itemPositions ||
           oldDelegate.dragLineStart != dragLineStart ||
           oldDelegate.dragLineEnd != dragLineEnd;
  }
}