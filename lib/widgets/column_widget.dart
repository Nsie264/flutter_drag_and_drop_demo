// lib/widgets/column_widget.dart

import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:drag_and_drop/widgets/child_item_widget.dart';
import 'package:drag_and_drop/widgets/group_container_widget.dart';
import 'package:drag_and_drop/widgets/parent_item_widget.dart';
import 'package:drag_and_drop/widgets/source_expansion_item.dart';
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

  Widget _buildSourceItemTile(
    BuildContext context,
    Item item, {
    bool isParent = false,
  }) {
    return Draggable<Item>(
      data: item,
      // Chặn kéo nếu item đã dùng hoặc là cha đã hết con (logic từ ParentItemWidget cũ)
      // Lưu ý: logic này sẽ được quyết định bên ngoài trước khi gọi hàm này
      feedback: Material(
        color: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 250 - 32,
          ), // Chiều rộng cột nguồn trừ padding
          child: Container(
            height: isParent ? 45 : 35,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: item.isUsed
                  ? Colors.grey.shade300
                  : (isParent ? Colors.amber.shade100 : Colors.blue.shade100),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                item.name,
                style: TextStyle(
                  fontWeight: isParent ? FontWeight.bold : FontWeight.normal,
                  color: item.isUsed ? Colors.grey.shade600 : Colors.black,
                  decoration: item.isUsed
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
            ),
          ),
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.5,
        child: Container(
          height: isParent ? 45 : 35,
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: item.isUsed
                ? Colors.grey.shade300
                : (isParent ? Colors.amber.shade100 : Colors.blue.shade100),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              item.name,
              style: TextStyle(
                fontWeight: isParent ? FontWeight.bold : FontWeight.normal,
                color: item.isUsed ? Colors.grey.shade600 : Colors.black,
                decoration: item.isUsed
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
      child: Container(
        height: isParent ? 45 : 35,
        margin: const EdgeInsets.symmetric(vertical: 2.0),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: item.isUsed
              ? Colors.grey.shade300
              : (isParent ? Colors.amber.shade100 : Colors.blue.shade100),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            item.name,
            style: TextStyle(
              fontWeight: isParent ? FontWeight.bold : FontWeight.normal,
              color: item.isUsed ? Colors.grey.shade600 : Colors.black,
              decoration: item.isUsed
                  ? TextDecoration.lineThrough
                  : TextDecoration.none,
            ),
          ),
        ),
      ),
    );
  }

  /// Logic render cho Cột Nguồn (giữ nguyên logic cũ)
  Widget _buildSourceColumnContent(BuildContext context) {
    // 1. Sắp xếp để item đã dùng xuống dưới
    final sortedItems = List<Item>.from(items);
    sortedItems.sort((a, b) {
      if (a.isUsed && !b.isUsed) return 1;
      if (!a.isUsed && b.isUsed) return -1;
      return a.originalId.compareTo(b.originalId);
    });

    // 2. Lọc ra các item cha của "Góc nhìn" hiện tại
    final parentItemsInView = sortedItems
        .where((item) => item.itemLevel == displayLevelStart)
        .toList();

    return ListView.builder(
      itemCount: parentItemsInView.length,
      itemBuilder: (context, index) {
        final parentItem = parentItemsInView[index];

        // 3. Với mỗi item cha, tìm các con trực tiếp của nó trong góc nhìn
        final childrenInView = sortedItems
            .where((child) =>
                child.parentId == parentItem.id &&
                child.itemLevel == displayLevelStart + 1)
            .toList();

        // 4. Quyết định xem có nên cho kéo item cha hay không
        final allDescendantsInSource = context.read<DragDropBloc>().findAllInstanceDescendants(parentItem.id, items);
        final bool isDisabledByChildren = allDescendantsInSource.isNotEmpty && allDescendantsInSource.every((d) => d.isUsed);
        final bool isParentEffectivelyDisabled = parentItem.isUsed || isDisabledByChildren;

        // 5. Render: Nếu không có con thì render tile thường, có con thì render ExpansionTile
        if (childrenInView.isEmpty) {
          // Vẫn bọc trong một widget để giữ khoảng cách đều
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: _buildSourceItemTile(context, parentItem, isParent: true),
          );
        }

        return ExpansionTile(
          key: PageStorageKey(parentItem.id), // Giữ trạng thái mở/đóng
          tilePadding: EdgeInsets.zero,
          // Bọc title trong IgnorePointer nếu không cho kéo, để Draggable không bắt sự kiện
          title: isParentEffectivelyDisabled
              ? _buildSourceItemTile(context, parentItem, isParent: true)
              : _buildSourceItemTile(context, parentItem, isParent: true),
          initiallyExpanded: false,
          childrenPadding: const EdgeInsets.only(left: 16),
          children: childrenInView.map((childItem) {
            return _buildSourceItemTile(context, childItem, isParent: false);
          }).toList(),
        );
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
