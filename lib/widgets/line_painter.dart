import 'dart:math';
import 'package:drag_and_drop/models/item.dart';
import 'package:flutter/material.dart';
import 'package:arrow_path/arrow_path.dart';

class LineAndArrowPainter extends CustomPainter {
  final List<Item> allItems; // Nhận vào danh sách tất cả item
  final Map<String, GlobalKey> itemKeys;
  final GlobalKey stackKey;

  LineAndArrowPainter({
    required this.allItems,
    required this.itemKeys,
    required this.stackKey,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final stackBox = stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    // Duyệt qua tất cả các item để tìm các kết nối
    for (final fromItem in allItems) {
      if (fromItem.nextItemId != null) {
        final fromKey = itemKeys[fromItem.id];
        final toKey = itemKeys[fromItem.nextItemId!];

        if (fromKey?.currentContext != null && toKey?.currentContext != null) {
          final fromBox = fromKey!.currentContext!.findRenderObject() as RenderBox;
          final toBox = toKey!.currentContext!.findRenderObject() as RenderBox;

          final startPoint = stackBox.globalToLocal(
            fromBox.localToGlobal(Offset(fromBox.size.width, fromBox.size.height / 2))
          );
          final endPoint = stackBox.globalToLocal(
            toBox.localToGlobal(Offset(0, toBox.size.height / 2))
          );
          
          Path path = Path();
          // Thêm một khoảng đệm nhỏ để mũi tên không chạm vào item
          path.moveTo(startPoint.dx + 5, startPoint.dy);
          path.lineTo(endPoint.dx - 5, endPoint.dy);

          path = ArrowPath.make(path: path, tipLength: 12, tipAngle: pi * 0.2);
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant LineAndArrowPainter oldDelegate) {
    // Luôn vẽ lại khi cuộn hoặc state thay đổi
    return true;
  }
}