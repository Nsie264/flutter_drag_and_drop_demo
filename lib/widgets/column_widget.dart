// lib/widgets/column_widget.dart

import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:drag_and_drop/widgets/item_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ColumnWidget extends StatelessWidget {
  final int columnId;
  final String title;
  final double width;
  final List<Item> items;
  final Map<String, GlobalKey> itemKeys;
  final Function(String itemId) onConnectionDragStarted;
  final Function(DragUpdateDetails) onConnectionDragUpdated;
  final VoidCallback onConnectionDragEnded;

  const ColumnWidget({
    super.key,
    required this.columnId,
    required this.title,
    required this.width,
    required this.items,
    required this.itemKeys,
    required this.onConnectionDragStarted,
    required this.onConnectionDragUpdated,
    required this.onConnectionDragEnded,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Item>(
      onWillAcceptWithDetails: (details) {
        final item = details.data;
        final canAccept = columnId > item.columnId;
        debugPrint('[Column $columnId] onWillAccept item ${item.name}: $canAccept');
        return canAccept;
      },
      onAcceptWithDetails: (details) {
        final item = details.data;
        debugPrint('[Column $columnId] ACCEPTED item ${item.name}');
        context.read<DragDropBloc>().add(ItemDropped(item: item, targetColumnId: columnId));
      },
      onLeave: (item) {
        debugPrint('[Column $columnId] Item ${item?.name} LEAVED');
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;
        return Container(
          // Chiều rộng cố định cho mỗi cột
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
              // Header của cột chứa Title và nút Xóa
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    // Chỉ hiển thị nút xóa cho các cột không phải cột nguồn
                    if (columnId > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () {
                          // Thêm dialog xác nhận để tránh xóa nhầm
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Xác nhận xóa'),
                              content: Text('Bạn có chắc chắn muốn xóa "$title"? Tất cả các item trong cột sẽ được trả về Nguồn.'),
                              actions: [
                                TextButton(
                                  child: const Text('Hủy'),
                                  onPressed: () => Navigator.of(ctx).pop(),
                                ),
                                TextButton(
                                  child: const Text('Xóa', style: TextStyle(color: Colors.red)),
                                  onPressed: () {
                                    context.read<DragDropBloc>().add(RemoveColumn(columnId: columnId));
                                    Navigator.of(ctx).pop();
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                        splashRadius: 20,
                      )
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  clipBehavior: Clip.none, // Quan trọng để nút nối không bị cắt
                  children: items.map((item) {
                    final itemKey = itemKeys[item.id]!;
                    return ItemWidget(
                      item: item,
                      itemKey: itemKey,
                      onConnectionDragStarted: onConnectionDragStarted,
                      onConnectionDragUpdated: onConnectionDragUpdated,
                      onConnectionDragEnded: onConnectionDragEnded,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}