// lib/widgets/column_widget.dart
import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:drag_and_drop/widgets/child_item_widget.dart';
import 'package:drag_and_drop/widgets/parent_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ColumnWidget extends StatelessWidget {
  final int columnId;
  final String title;
  final double width;
  final List<Item> items;
  final Map<String, GlobalKey> itemKeys;
  final int displayLevelStart;

  const ColumnWidget({
    super.key,
    required this.columnId,
    required this.title,
    required this.width,
    required this.items,
    required this.itemKeys,
    required this.displayLevelStart,
  });

  @override
  Widget build(BuildContext context) {
    // --- LOGIC HIỂN THỊ MỚI - XỬ LÝ CẢ CON MỒ CÔI ---

    // 1. Lọc ra tất cả các item sẽ hiển thị trong góc nhìn này
    final visibleItems = items.where((item) => 
        item.itemLevel >= displayLevelStart && item.itemLevel <= displayLevelStart + 1
    ).toList();
    
    // 2. Tạo một map để tra cứu item bằng ID trong số các item hiển thị
    final visibleItemsById = {for (var item in visibleItems) item.id: item};
    
    // 3. Xác định các item gốc cần render ở cấp cao nhất của ListView
    final List<Item> rootItemsToRender = [];
    for (final item in visibleItems) {
      // Một item là "gốc" nếu:
      // a. Nó là cha trong góc nhìn (level == displayLevelStart)
      // b. Nó là con trong góc nhìn (level == displayLevelStart + 1) NHƯNG cha của nó không có trong cột này.
      if (item.itemLevel == displayLevelStart || 
         (item.itemLevel == displayLevelStart + 1 && (item.parentId == null || !visibleItemsById.containsKey(item.parentId)))) {
        rootItemsToRender.add(item);
      }
    }

    return DragTarget<Item>(
      // ... DragTarget không đổi ...
      onWillAcceptWithDetails: (details) {
        final item = details.data;
        final isAlreadyInTarget = items.any((i) => i.originalId == item.originalId);
        return columnId > item.columnId && !isAlreadyInTarget;
      },
      onAcceptWithDetails: (details) {
        context.read<DragDropBloc>().add(ItemDropped(
          item: details.data, 
          targetColumnId: columnId
        ));
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;
        return Container(
          // ... decoration không đổi ...
          width: width,
          margin: const EdgeInsets.all(8.0),
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: isTarget ? Colors.lightGreen.shade100 : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(8.0),
            border: Border.all(
              color: isTarget ? Colors.green : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ... header không đổi ...
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (columnId > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () {},
                        splashRadius: 20,
                      )
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  // 4. Duyệt qua danh sách các item gốc đã xác định
                  itemCount: rootItemsToRender.length,
                  itemBuilder: (context, index) {
                    final rootItem = rootItemsToRender[index];

                    // 5. Kiểm tra xem item gốc này là cha hay con mồ côi
                    if (rootItem.itemLevel == displayLevelStart) { // Đây là một "cha trong góc nhìn"
                      // Tìm con của nó
                      final children = visibleItems.where((child) => 
                        child.parentId == rootItem.id
                      ).toList();

                      return ParentItemWidget(
                        parentItem: rootItem,
                        childItems: children,
                        itemKeys: itemKeys,
                      );
                    } else { // Đây là một "con mồ côi trong góc nhìn"
                      return ChildItemWidget(
                        item: rootItem,
                        itemKey: itemKeys[rootItem.id]!,
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}