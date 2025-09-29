import 'package:excel/excel.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:flutter/foundation.dart'; // Import để sử dụng debugPrint

class ExcelDataParser {
  List<Item> parseItemsFromExcel(List<int> fileBytes) {
    debugPrint('\n\n\x1B[35m--- BẮT ĐẦU PHÂN TÍCH FILE EXCEL ---\x1B[0m');
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
      debugPrint('  Dữ liệu thô: "$level1Name" | "$level2Name" | "$level3Name" | "$level4Name"');

      if (level1Name.isEmpty) {
        debugPrint('  -> Bỏ qua dòng trống.');
        continue;
      }

      // --- Xử lý Level 1 ---
      String l1IdPart;
      if (!level1Tracker.containsKey(level1Name)) {
        level1Counter++;
        l1IdPart = _formatId(level1Counter);
        level1Tracker[level1Name] = _HierarchyNode(idPart: l1IdPart);
        final newItem = Item(
          id: '',
          originalId: '$l1IdPart-00-00-000',
          name: level1Name,
          columnId: 0,
        );
        masterItems.add(newItem);
        debugPrint('  \x1B[32m-> Tạo MỚI Level 1:\x1B[0m "${newItem.name}" (originalId: ${newItem.originalId})');
      } else {
        l1IdPart = level1Tracker[level1Name]!.idPart;
        debugPrint('  -> Sử dụng Level 1 đã có: "$level1Name" (ID part: $l1IdPart)');
      }
      final l1Node = level1Tracker[level1Name]!;

      // --- Xử lý Level 2 ---
      String l2IdPart = '00';
      _HierarchyNode l2Node;
      if (level2Name.isNotEmpty && level2Name != 'ô trống') {
        if (!l1Node.children.containsKey(level2Name)) {
          l1Node.counter++;
          l2IdPart = _formatId(l1Node.counter);
          l1Node.children[level2Name] = _HierarchyNode(idPart: l2IdPart);
          final newItem = Item(
            id: '',
            originalId: '$l1IdPart-$l2IdPart-00-000',
            name: level2Name,
            columnId: 0,
          );
          masterItems.add(newItem);
          debugPrint('  \x1B[32m-> Tạo MỚI Level 2:\x1B[0m "${newItem.name}" (originalId: ${newItem.originalId})');
        } else {
          l2IdPart = l1Node.children[level2Name]!.idPart;
          debugPrint('  -> Sử dụng Level 2 đã có: "$level2Name" (ID part: $l2IdPart)');
        }
        l2Node = l1Node.children[level2Name]!;
      } else {
        debugPrint('  -> Level 2 trống, ID part sẽ là "00".');
        l2Node = _HierarchyNode(idPart: '00'); // Node giả để xử lý tiếp
      }

      // --- Xử lý Level 3 ---
      String l3IdPart = '00';
      _HierarchyNode l3Node;
      if (level3Name.isNotEmpty && level3Name != 'ô trống') {
        if (!l2Node.children.containsKey(level3Name)) {
          l2Node.counter++;
          l3IdPart = _formatId(l2Node.counter);
          l2Node.children[level3Name] = _HierarchyNode(idPart: l3IdPart);
          final newItem = Item(
            id: '',
            originalId: '$l1IdPart-$l2IdPart-$l3IdPart-000',
            name: level3Name,
            columnId: 0,
          );
          masterItems.add(newItem);
          debugPrint('  \x1B[32m-> Tạo MỚI Level 3:\x1B[0m "${newItem.name}" (originalId: ${newItem.originalId})');
        } else {
          l3IdPart = l2Node.children[level3Name]!.idPart;
          debugPrint('  -> Sử dụng Level 3 đã có: "$level3Name" (ID part: $l3IdPart)');
        }
        l3Node = l2Node.children[level3Name]!;
      } else {
        debugPrint('  -> Level 3 trống, ID part sẽ là "00".');
        l3Node = _HierarchyNode(idPart: '00'); // Node giả
      }
      
      // --- Xử lý Level 4 ---
      if (level4Name.isNotEmpty && level4Name != 'ô trống') {
        if (!l3Node.children.containsKey(level4Name)) {
          l3Node.counter++;
          final l4IdPart = l3Node.counter.toString().padLeft(3, '0'); 
          l3Node.children[level4Name] = _HierarchyNode(idPart: l4IdPart);
          final newItem = Item(
            id: '',
            originalId: '$l1IdPart-$l2IdPart-$l3IdPart-$l4IdPart',
            name: level4Name,
            columnId: 0,
          );
          masterItems.add(newItem);
          debugPrint('  \x1B[32m-> Tạo MỚI Level 4:\x1B[0m "${newItem.name}" (originalId: ${newItem.originalId})');
        } else {
          // Level 4 thường là duy nhất trên mỗi dòng, nên ít khi chạy vào đây
          debugPrint('  -> Sử dụng Level 4 đã có: "$level4Name"');
        }
      } else {
        debugPrint('  -> Level 4 trống, không tạo item.');
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