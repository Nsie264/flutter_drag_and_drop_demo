import 'dart:math';
import 'package:arrow_path/arrow_path.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:flutter/material.dart';

class LineAndArrowPainter extends CustomPainter {
  final List<Item> allItems;
  final Map<String, GlobalKey> itemKeys;
  final GlobalKey stackKey;
  // BỎ scrollController vì không cần tính toán thủ công nữa
  // final ScrollController scrollController;

  LineAndArrowPainter({
    required this.allItems,
    required this.itemKeys,
    required this.stackKey,
    // Bỏ scrollController
    // required this.scrollController,
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
    
    // BỎ scrollOffset

    for (final fromItem in allItems) {
      if (fromItem.nextItemId != null) {
        final Item? toItem = allItems.firstWhere(
          (i) => i.id == fromItem.nextItemId,
        );

        if (toItem == null) continue;

        if (fromItem.columnId <= 1 || toItem.columnId <= 1) {
          continue;
        }

        final fromKey = itemKeys[fromItem.id];
        final toKey = itemKeys[toItem.id];

        if (fromKey?.currentContext != null && toKey?.currentContext != null) {
          final fromBox = fromKey!.currentContext!.findRenderObject() as RenderBox;
          final toBox = toKey!.currentContext!.findRenderObject() as RenderBox;

          final globalStart = fromBox.localToGlobal(Offset(fromBox.size.width, fromBox.size.height / 2));
          final globalEnd = toBox.localToGlobal(Offset(0, toBox.size.height / 2));
          
          // Chỉ cần chuyển đổi sang tọa độ cục bộ của khu vực vẽ.
          // Khi cuộn, globalStart/globalEnd thay đổi, và setState sẽ trigger
          // việc tính toán lại startPoint/endPoint mới này.
          final startPoint = stackBox.globalToLocal(globalStart);
          final endPoint = stackBox.globalToLocal(globalEnd);

          // BỎ CÁC DÒNG CỘNG THÊM scrollOffset
          
          Path path = Path();
          path.moveTo(startPoint.dx + 5, startPoint.dy);
          path.lineTo(endPoint.dx - 5, endPoint.dy);

          path = ArrowPath.make(path: path, tipLength: 12, tipAngle: pi * 0.2);
          canvas.drawPath(path, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}