import 'package:drag_and_drop/models/item.dart';

class ColumnHelper {
  // Gợi ý hàm helper
static Map<Item, List<Item>> structureItemsForDisplay(List<Item> flatItemsInColumn) {
  final Map<Item, List<Item>> structuredMap = {};
  final List<Item> allItems = List.from(flatItemsInColumn);

  // Tìm tất cả các item cha (không có parentId hoặc parent của nó không trong cột này)
  final parents = allItems.where((item) => item.parentId == null).toList();
  
  for (final parent in parents) {
    // Tìm tất cả con của parent này
    final children = allItems.where((child) => child.parentId == parent.id).toList();
    structuredMap[parent] = children;
  }

  return structuredMap;
}
}