// lib/widgets/column_widget.dart

import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:drag_and_drop/widgets/child_item_widget.dart';
import 'package:drag_and_drop/widgets/group_container_widget.dart';
import 'package:drag_and_drop/widgets/parent_item_widget.dart';
import 'package:drag_and_drop/widgets/workflow_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart'; // Thêm import này

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
    return DragTarget<Item>(
      onWillAcceptWithDetails: (details) {
        final item = details.data;
        // Logic chấp nhận khi thả vào nền cột:
        // Chỉ chấp nhận khi item chưa tồn tại trong cột (dựa trên originalId)
        final isAlreadyInTarget = items.any(
          (i) => i.originalId == item.originalId,
        );
        // Và phải là kéo sang cột sau
        return columnId > item.columnId && !isAlreadyInTarget;
      },
      onAcceptWithDetails: (details) {
        context.read<DragDropBloc>().add(
          ItemDropped(item: details.data, targetColumnId: columnId),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;
        return Container(
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (columnId > 1)
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () {
                          // TODO: Implement remove column logic
                        },
                        splashRadius: 20,
                      ),
                  ],
                ),
              ),
              Expanded(
                // PHÂN LUỒNG LOGIC RENDER
                child: columnId == 1
                    ? _buildSourceColumnContent(context)
                    : _buildWorkflowColumnContent(context),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Logic render cho Cột Nguồn (giữ nguyên logic cũ)
  Widget _buildSourceColumnContent(BuildContext context) {
    final sortedItems = List<Item>.from(items);
    sortedItems.sort((a, b) {
      if (a.isUsed && !b.isUsed) return 1; // a đã dùng, đẩy xuống
      if (!a.isUsed && b.isUsed) return -1; // b đã dùng, đẩy xuống (giữ a)
      return a.originalId.compareTo(b.originalId); // Giữ thứ tự ban đầu cho các item cùng trạng thái
    });

    final visibleItems = sortedItems // Dùng danh sách đã sắp xếp
        .where((item) =>
            item.itemLevel >= displayLevelStart &&
            item.itemLevel <= displayLevelStart + 1)
        .toList();

    final visibleItemsById = {for (var item in visibleItems) item.id: item};

    final List<Item> rootItemsToRender = [];
    for (final item in visibleItems) {
      if (item.itemLevel == displayLevelStart ||
          (item.itemLevel == displayLevelStart + 1 &&
              (item.parentId == null ||
                  !visibleItemsById.containsKey(item.parentId)))) {
        rootItemsToRender.add(item);
      }
    }

    return ListView.builder(
      itemCount: rootItemsToRender.length,
      itemBuilder: (context, index) {
        final rootItem = rootItemsToRender[index];

        // KHI ITEM LÀ PARENTWIDGET TRONG GÓC NHÌN
        if (rootItem.itemLevel == displayLevelStart) {
          // children là các con hiển thị trong góc nhìn hiện tại
          final children =
              visibleItems.where((child) => child.parentId == rootItem.id).toList();

          // === LOGIC MỚI: KIỂM TRA ĐỂ VÔ HIỆU HÓA CHA ===
          // Tìm tất cả con cháu của cha này trong TOÀN BỘ CỘT NGUỒN
          final allDescendantsInSource = context.read<DragDropBloc>().findAllInstanceDescendants(rootItem.id, items);

          // Cha bị vô hiệu hóa khi:
          // 1. Bản thân nó đã được đánh dấu isUsed (áp dụng cho cha không có con như "Tạo Yêu cầu").
          // HOẶC
          // 2. Nó có con, và TẤT CẢ các con đó đều đã isUsed.
          final bool isDisabledByChildren = allDescendantsInSource.isNotEmpty && allDescendantsInSource.every((d) => d.isUsed);
          final bool isParentEffectivelyDisabled = rootItem.isUsed || isDisabledByChildren;
          
          
          return ParentItemWidget(
            parentItem: rootItem,
            childItems: children,
            itemKeys: itemKeys,
            // Cha sẽ không thể kéo được nếu nó bị vô hiệu hóa
            isDraggable: !isParentEffectivelyDisabled, 
          );
        } else { // KHI ITEM LÀ CHILDWIDGET TRONG GÓC NHÌN
          return ChildItemWidget(
            item: rootItem,
            itemKey: itemKeys[rootItem.id]!,
            // ChildWidget luôn có thể kéo được (nếu nó chưa isUsed),
            // trạng thái isDraggable của nó được xử lý bên trong chính nó
          );
        }
      },
    );
  }

  /// Logic render MỚI cho các cột làm việc
  Widget _buildWorkflowColumnContent(BuildContext context) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Kéo item vào đây', style: TextStyle(color: Colors.grey)),
      );
    }

    final masterItems = context.read<DragDropBloc>().state.masterItems;

    // 1. Tách các item ra: placeholder, item con có cha, và item không có cha (mồ côi)
    final placeholders = items.where((i) => i.isGroupPlaceholder).toList();
    final childrenItems = items
        .where(
          (i) => !i.isGroupPlaceholder && i.potentialParentOriginalId != null,
        )
        .toList();
    final orphanItems = items
        .where(
          (i) => !i.isGroupPlaceholder && i.potentialParentOriginalId == null,
        )
        .toList();

    // 2. Nhóm các item con theo cha của chúng
    final groupedChildren = groupBy<Item, String>(
      childrenItems,
      (item) => item.potentialParentOriginalId!,
    );

    // 3. Xây dựng danh sách các widget sẽ được render
    List<Widget> widgetsToRender = [];

    // Thêm các item mồ côi (thường là level 1)
    widgetsToRender.addAll(
      orphanItems.map(
        (item) => WorkflowItemWidget(
          key: ValueKey(item.id),
          item: item,
          itemKey: itemKeys[item.id]!,
        ),
      ),
    );

    // Thêm các "cha đại diện" (placeholder)
    widgetsToRender.addAll(
      placeholders.map((item) {
        // === THAY ĐỔI Ở ĐÂY ===
        // Lấy hàm kiểm tra từ BLoC
        final isComplete = context.read<DragDropBloc>().isGroupComplete(
          item,
          masterItems,
        );
        return WorkflowItemWidget(
          key: ValueKey(item.id),
          item: item,
          itemKey: itemKeys[item.id]!,
          isComplete: isComplete, // Truyền trạng thái đúng xuống widget
        );
        // ======================
      }),
    );

    // Thêm các nhóm ảo
    groupedChildren.forEach((parentId, children) {
      // Tìm thông tin của cha từ master list
      final parentInfo = masterItems.firstWhereOrNull(
        (m) => m.originalId == parentId,
      );
      if (parentInfo != null) {
        widgetsToRender.add(
          GroupContainerWidget(
            key: ValueKey(parentId),
            parentInfo: parentInfo,
            childItems: children,
            itemKeys: itemKeys,
          ),
        );
      }
    });

    return ListView(children: widgetsToRender);
  }
}
