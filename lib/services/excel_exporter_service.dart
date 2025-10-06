import 'package:drag_and_drop/models/column_data.dart';
import 'package:excel/excel.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart'; // For kIsWeb

class ExcelExporterService {
  Future<void> exportWorkflow(List<ColumnData> columns) async {
    try {
      // 1. Tạo một workbook Excel mới
      final excel = Excel.createExcel();
      Sheet sheet = excel.sheets.values.first;

      // 2. Thêm dòng tiêu đề
      final List<String> headerStrings = [
        'ID',
        'Tổ - Trạm',
        'ID gốc',
        'Tên',
        'Số lượng',
        'Nhân công tiếp theo',
      ];
      final List<CellValue> headers = headerStrings
          .map((h) => TextCellValue(h))
          .toList();
      sheet.appendRow(headers);

      for (int i = 0; i < headerStrings.length; i++) {
        sheet.setColumnAutoFit(i);
      }
      // 3. Lặp qua các cột làm việc và các item để thêm dữ liệu
      for (final column in columns) {
        // Chỉ xuất dữ liệu từ các cột workflow
        if (column.id <= 1) continue;

        for (final item in column.items) {
          final List<CellValue> rowData = [
            TextCellValue(item.id),
            TextCellValue(column.title),
            TextCellValue(item.originalId),
            TextCellValue(item.name),
            IntCellValue(item.quantity),
            item.nextItemId != null
                ? TextCellValue(item.nextItemId!)
                : TextCellValue(''),
          ];
          sheet.appendRow(rowData);
        }
      }

      // 4. Encode file và chuẩn bị để lưu
      final fileBytes = excel.save();
      if (fileBytes != null) {
        // 5. Mở hộp thoại lưu file
        await FileSaver.instance.saveFile(
          name: 'POM_${DateTime.now().toIso8601String()}',
          bytes: Uint8List.fromList(fileBytes),
          fileExtension: 'xlsx',
          mimeType: MimeType.microsoftExcel,
        );
      }
    } catch (e) {
      debugPrint('Lỗi khi xuất file Excel: $e');
      // Có thể hiển thị SnackBar lỗi ở đây nếu cần
      rethrow;
    }
  }
}
