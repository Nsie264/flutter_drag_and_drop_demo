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
    final paint = Paint()
      ..color = Colors.black.withValues(alpha: 0.2)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final stackBox = stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    for (final fromItem in allItems) {
      if (fromItem.nextItemId != null) {
        final Item toItem = allItems.firstWhere(
          (i) => i.id == fromItem.nextItemId,
        );

        if (fromItem.columnId <= 1 || toItem.columnId <= 1) {
          continue;
        }

        final fromKey = itemKeys[fromItem.id];
        final toKey = itemKeys[toItem.id];

        if (fromKey?.currentContext != null && toKey?.currentContext != null) {
          final fromBox =
              fromKey!.currentContext!.findRenderObject() as RenderBox;
          final toBox = toKey!.currentContext!.findRenderObject() as RenderBox;

          final globalStart = fromBox.localToGlobal(
            Offset(fromBox.size.width, fromBox.size.height / 2),
          );
          final globalEnd = toBox.localToGlobal(
            Offset(0, toBox.size.height / 2),
          );

          // Chỉ cần chuyển đổi sang tọa độ cục bộ của khu vực vẽ.
          // Khi cuộn, globalStart/globalEnd thay đổi, và setState sẽ trigger
          // việc tính toán lại startPoint/endPoint mới này.
          final startPoint = stackBox.globalToLocal(globalStart);
          final endPoint = stackBox.globalToLocal(globalEnd);

          final linePath = Path()
            ..moveTo(startPoint.dx + 5, startPoint.dy)
            ..lineTo(endPoint.dx, endPoint.dy);

          canvas.drawPath(
            dashPath(
              linePath,
              dashArray: CircularIntervalList<double>([10.0, 5.0]),
            ),
            paint,
          );

          // BƯỚC 2: VẼ ĐẦU MŨI TÊN (LIỀN MẠCH) MỘT CÁCH RIÊNG BIỆT
          const arrowSize = 12.0;
          const arrowAngle = pi * 0.2; // ~36 độ

          // Tính toán góc của đường thẳng để xoay đầu mũi tên cho đúng
          final angle = atan2(
            endPoint.dy - startPoint.dy,
            endPoint.dx - startPoint.dx,
          );

          // Tạo một Path MỚI chỉ chứa đầu mũi tên
          final arrowHeadPath = Path();

          // Điểm 1 của đầu mũi tên
          arrowHeadPath.moveTo(
            endPoint.dx - arrowSize * cos(angle - arrowAngle),
            endPoint.dy - arrowSize * sin(angle - arrowAngle),
          );
          // Điểm giữa (đỉnh)
          arrowHeadPath.lineTo(endPoint.dx, endPoint.dy);
          // Điểm 2 của đầu mũi tên
          arrowHeadPath.lineTo(
            endPoint.dx - arrowSize * cos(angle + arrowAngle),
            endPoint.dy - arrowSize * sin(angle + arrowAngle),
          );

          // Vẽ đầu mũi tên bằng paint gốc (nét liền)
          canvas.drawPath(arrowHeadPath, paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
