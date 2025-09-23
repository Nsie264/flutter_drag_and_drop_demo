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

  const ColumnWidget({
    super.key,
    required this.columnId,
    required this.title,
    required this.width,
    required this.items,
    required this.itemKeys,
  });

  // Giữ lại hàm helper này vì nó xác định đúng các item gốc của cột
  Map<Item, List<Item>> _structureItems(List<Item> flatItems) {
    final Map<Item, List<Item>> structuredMap = {};
    final Map<String, Item> itemsById = {for (var item in flatItems) item.id: item};
    
    // Tìm các item gốc (item cha hoặc item con mồ côi)
    for (final item in flatItems) {
      if (item.parentId == null || !itemsById.containsKey(item.parentId)) {
        structuredMap[item] = [];
      }
    }

    // Gán các item con vào cha của chúng (nếu cha có trong cột)
    for (final item in flatItems) {
      if (item.parentId != null && itemsById.containsKey(item.parentId)) {
         final parentKey = structuredMap.keys.firstWhere((p) => p.id == item.parentId, orElse: () => const Item(id: 'NOT_FOUND', originalId: '', name: '', columnId: -1));
         if (parentKey.id != 'NOT_FOUND') {
           structuredMap[parentKey]!.add(item);
           // Xóa con khỏi danh sách gốc để nó không bị render 2 lần
           structuredMap.remove(item);
         }
      }
    }
    return structuredMap;
  }

  @override
  Widget build(BuildContext context) {
    final structuredItems = _structureItems(items);
    final rootItems = structuredItems.keys.toList(); // Đây là các item gốc cần render

    return DragTarget<Item>(
      // ... DragTarget không đổi
      onWillAcceptWithDetails: (details) {
        final item = details.data;
        return columnId > item.columnId;
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
          // ... decoration không đổi
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
              // ... header không đổi
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
                  itemCount: rootItems.length,
                  itemBuilder: (context, index) {
                    final item = rootItems[index];
                    final children = structuredItems[item] ?? [];
                    
                    // *** QUY TẮC RENDER MỚI ***
                    // Nếu item gốc này có level > 1, nó là một đứa con mồ côi -> render nó như ChildItemWidget
                    if(item.itemLevel > 1){
                      return ChildItemWidget(
                        item: item, 
                        itemKey: itemKeys[item.id]!
                      );
                    }
                    
                    // Nếu không, nó là một item cha thực sự -> render nó như ParentItemWidget
                    return ParentItemWidget(
                      parentItem: item,
                      childItems: children,
                      itemKeys: itemKeys,
                    );
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