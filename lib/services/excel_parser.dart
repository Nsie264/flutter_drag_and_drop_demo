import 'package:excel/excel.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:flutter/foundation.dart'; // Import để sử dụng debugPrint

class ExcelDataParser {
  static const String _EMPTY_NODE_KEY = '__EMPTY__';

  List<Item> parseItemsFromExcel(List<int> fileBytes) {
    debugPrint('\n\n\x1B[35m--- BẮT ĐẦU PHÂN TÍCH FILE EXCEL (FIXED) ---\x1B[0m');
    final List<Item> masterItems = [];
    final excel = Excel.decodeBytes(fileBytes);
    final sheet = excel.tables[excel.tables.keys.first]!;

    final Map<String, _HierarchyNode> level1Tracker = {};
    int level1Counter = 0;

    int rowIndex = 0;
    for (final row in sheet.rows.skip(1)) {
      rowIndex++;
      debugPrint('\n\x1B[33m[Đọc dòng ${rowIndex + 1}]\x1B[0m');
      
      final level1Name = _getCellValue(row[0]);
      final level2Name = _getCellValue(row[1]);
      final level3Name = _getCellValue(row[2]);
      final level4Name = _getCellValue(row[3]);
      final quantity = int.tryParse(_getCellValue(row[4])) ?? 1;
      debugPrint('  Dữ liệu thô: "$level1Name" | "$level2Name" | "$level3Name" | "$level4Name" | "$quantity"');

      if (level1Name.isEmpty) continue;

      // --- Xử lý Level 1 (Không đổi) ---
      if (!level1Tracker.containsKey(level1Name)) {
        level1Counter++;
        level1Tracker[level1Name] = _HierarchyNode(idPart: _formatId(level1Counter));
        masterItems.add(Item(id: '', originalId: '${level1Tracker[level1Name]!.idPart}-00-00-000', name: level1Name, columnId: 0, quantity: quantity));
        debugPrint('  \x1B[32m-> Tạo MỚI Level 1:\x1B[0m "$level1Name" (ID part: ${level1Tracker[level1Name]!.idPart})');
      }
      final l1Node = level1Tracker[level1Name]!;
      final l1IdPart = l1Node.idPart;

      // --- Xử lý Level 2 (Đã sửa lỗi) ---
      String l2IdPart;
      _HierarchyNode l2Node;
      if (level2Name.isNotEmpty && level2Name != 'ô trống') {
        l2IdPart = l1Node.children.putIfAbsent(level2Name, () {
          l1Node.counter++;
          final newIdPart = _formatId(l1Node.counter);
          masterItems.add(Item(id: '', originalId: '$l1IdPart-$newIdPart-00-000', name: level2Name, columnId: 0, quantity: quantity));
          debugPrint('  \x1B[32m-> Tạo MỚI Level 2:\x1B[0m "$level2Name" (ID part: $newIdPart)');
          return _HierarchyNode(idPart: newIdPart);
        }).idPart;
        l2Node = l1Node.children[level2Name]!;
      } else {
        // Sử dụng node đại diện bền vững
        l2IdPart = '00';
        l2Node = l1Node.children.putIfAbsent(_EMPTY_NODE_KEY, () {
           debugPrint('  \x1B[32m-> Tạo MỚI Node đại diện cho Level 2 trống\x1B[0m');
           return _HierarchyNode(idPart: l2IdPart);
        });
      }

      // --- Xử lý Level 3 (Đã sửa lỗi) ---
      String l3IdPart;
      _HierarchyNode l3Node;
      if (level3Name.isNotEmpty && level3Name != 'ô trống') {
        l3IdPart = l2Node.children.putIfAbsent(level3Name, () {
          l2Node.counter++;
          final newIdPart = _formatId(l2Node.counter);
          masterItems.add(Item(id: '', originalId: '$l1IdPart-$l2IdPart-$newIdPart-000', name: level3Name, columnId: 0, quantity: quantity));
          debugPrint('  \x1B[32m-> Tạo MỚI Level 3:\x1B[0m "$level3Name" (ID part: $newIdPart)');
          return _HierarchyNode(idPart: newIdPart);
        }).idPart;
        l3Node = l2Node.children[level3Name]!;
      } else {
        l3IdPart = '00';
        l3Node = l2Node.children.putIfAbsent(_EMPTY_NODE_KEY, () {
           debugPrint('  \x1B[32m-> Tạo MỚI Node đại diện cho Level 3 trống\x1B[0m');
           return _HierarchyNode(idPart: l3IdPart);
        });
      }
      
      // --- Xử lý Level 4 (Không đổi, sẽ tự động đúng) ---
      if (level4Name.isNotEmpty && level4Name != 'ô trống') {
        l3Node.children.putIfAbsent(level4Name, () {
          l3Node.counter++;
          final l4IdPart = l3Node.counter.toString().padLeft(3, '0');
          masterItems.add(Item(id: '', originalId: '$l1IdPart-$l2IdPart-$l3IdPart-$l4IdPart', name: level4Name, columnId: 0, quantity: quantity));
          debugPrint('  \x1B[32m-> Tạo MỚI Level 4:\x1B[0m "$level4Name" (originalId: $l1IdPart-$l2IdPart-$l3IdPart-$l4IdPart)');
          return _HierarchyNode(idPart: l4IdPart);
        });
      }
    }

    debugPrint('\n\x1B[35m--- KẾT THÚC PHÂN TÍCH ---');
    debugPrint('Tổng số item được tạo: ${masterItems.length}');
    debugPrint('--- Danh sách item cuối cùng (masterItems) ---');
    for (final item in masterItems) {
      debugPrint('  - "${item.name}" (originalId: ${item.originalId})');
    }
    debugPrint('============================================\x1B[0m\n\n');
    
    return masterItems;
  }

  String _getCellValue(Data? cell) {
    return cell?.value?.toString().trim() ?? '';
  }

  String _formatId(int number) {
    return number.toString().padLeft(2, '0');
  }
}

class _HierarchyNode {
  final String idPart;
  int counter = 0;
  final Map<String, _HierarchyNode> children = {};

  _HierarchyNode({required this.idPart});
}