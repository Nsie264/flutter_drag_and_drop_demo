// lib/widgets/column_widget.dart

import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:drag_and_drop/widgets/group_container_widget.dart';
import 'package:drag_and_drop/widgets/workflow_item_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:collection/collection.dart';

// MODIFIED: _buildSourceItemTile được cập nhật để hiển thị Checkbox
Widget _buildSourceItemTile(
  BuildContext context,
  Item item, {
  required DragRole role,
  required bool isMultiSelectModeActive, // NEW: Nhận biết chế độ
}) {
  final bool isParentRole = role == DragRole.parent;
  final bool isEligible = !item.isUsed; // Chỉ item chưa dùng mới được chọn

  // Lấy state để biết item có đang được chọn hay không
  final selectedItemIds =
      context.watch<DragDropBloc>().state.selectedItemIds;
  final isSelected = selectedItemIds.contains(item.id);

  // Widget nội dung chính của item
  Widget itemContent = Container(
    height: isParentRole ? 45 : 35,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: item.isUsed
          ? Colors.grey.shade300
          : (isParentRole ? Colors.amber.shade100 : Colors.blue.shade100),
      borderRadius: BorderRadius.circular(4),
      // NEW: Thêm viền xanh nếu được chọn
      border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
    ),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        item.name,
        style: TextStyle(
          fontWeight: isParentRole ? FontWeight.bold : FontWeight.normal,
          color: item.isUsed ? Colors.grey.shade600 : Colors.black,
          decoration:
              item.isUsed ? TextDecoration.lineThrough : TextDecoration.none,
        ),
      ),
    ),
  );

  // Bọc nội dung trong một Row nếu ở chế độ chọn nhiều
  Widget finalLayout = isMultiSelectModeActive && isEligible && !isParentRole
      ? Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (bool? value) {
                if (value != null) {
                  context.read<DragDropBloc>().add(
                        ItemSelectionChanged(itemId: item.id, isSelected: value),
                      );
                }
              },
            ),
            Expanded(child: itemContent),
          ],
        )
      : itemContent; // Nếu không thì hiển thị như cũ

  // Chỉ cho phép kéo nếu item đủ điều kiện
  if (!isEligible) {
    return finalLayout;
  }

  return Draggable<Item>(
    // MODIFIED: Cập nhật data và feedback cho chế độ chọn nhiều
    data: (isMultiSelectModeActive && isSelected)
        ? item.copyWith(dragMode: DragMode.multiSelect)
        : item.copyWith(dragRole: role),
    feedback: (isMultiSelectModeActive && isSelected)
        ? Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.blue.shade200,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26, blurRadius: 4, offset: Offset(2, 2)),
                ],
              ),
              child: Text(
                '${selectedItemIds.length} items',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          )
        : Material( // Feedback cũ cho kéo đơn
            color: Colors.transparent,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 250 - 32),
              child: itemContent,
            ),
          ),
    childWhenDragging: Opacity(opacity: 0.5, child: finalLayout),
    child: finalLayout,
  );
}

class ColumnWidget extends StatelessWidget {
  final int columnId;
  final String title;
  final double width;
  final List<Item> items;
  final Map<String, GlobalKey> itemKeys;
  final int displayLevelStart;
  final ScrollController? scrollController;

  const ColumnWidget({
    super.key,
    required this.columnId,
    required this.title,
    required this.width,
    required this.items,
    required this.itemKeys,
    required this.displayLevelStart,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return DragTarget<Item>(
      onWillAcceptWithDetails: (details) {
        // MODIFIED: Logic onWillAccept đơn giản hóa cho multi-select
        // Logic phức tạp hơn sẽ được BLoC xử lý
        final item = details.data;
        if (item.dragMode == DragMode.multiSelect) {
          return columnId > item.columnId;
        }
        
        // Logic cũ cho kéo đơn và kéo nhóm
        bool isAlreadyInTarget = false;
        if (item.columnId == 1 && item.dragRole == DragRole.parent) {
          final sourceItems =
              context.read<DragDropBloc>().state.sourceColumn.items;
          final childrenToMove = sourceItems
              .where((child) => child.parentId == item.id && !child.isUsed);
          final originalIdsToMove = childrenToMove.map((c) => c.originalId).toSet();
          isAlreadyInTarget =
              items.any((i) => originalIdsToMove.contains(i.originalId));
        } else {
          isAlreadyInTarget = items.any((i) => i.originalId == item.originalId);
        }
        return columnId > item.columnId && !isAlreadyInTarget;
      },
      onAcceptWithDetails: (details) {
        final draggedItem = details.data;
        
        // MODIFIED: Phân luồng logic dựa trên dragMode
        switch (draggedItem.dragMode) {
          case DragMode.multiSelect:
            context.read<DragDropBloc>().add(
                  MultiSelectionDropped(
                    representativeItem: draggedItem,
                    targetColumnId: columnId,
                    targetItem: null, // Thả vào nền cột
                  ),
                );
            break;
          case DragMode.group:
            context.read<DragDropBloc>().add(
                  GroupDropped(
                    representativeItem: draggedItem,
                    targetColumnId: columnId,
                  ),
                );
            break;
          case DragMode.single:
          default:
            context.read<DragDropBloc>().add(
                  ItemDropped(item: draggedItem, targetColumnId: columnId),
                );
            break;
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isTarget = candidateData.isNotEmpty;
        
        // NEW: Lấy state của chế độ chọn nhiều
        final multiSelectState = context.watch<DragDropBloc>().state;
        final isMultiSelectModeActive = multiSelectState.multiSelectActiveColumnId == columnId;

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
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    // NEW: Nút bật/tắt chế độ chọn nhiều
                    IconButton(
                      icon: Icon(
                        Icons.checklist_rtl,
                        color: isMultiSelectModeActive ? Theme.of(context).primaryColor : Colors.grey,
                      ),
                      onPressed: () {
                        context.read<DragDropBloc>().add(ToggleMultiSelectMode(columnId: columnId));
                      },
                      tooltip: 'Chế độ chọn nhiều',
                      splashRadius: 20,
                    ),
                    if (columnId > 1)
                      IconButton(
                        icon: const Icon(Icons.delete_outline,
                            color: Colors.redAccent),
                        onPressed: () {
                          context
                              .read<DragDropBloc>()
                              .add(RemoveColumn(columnId: columnId));
                        },
                        tooltip: 'Xóa cột',
                        splashRadius: 20,
                      )
                  ],
                ),
              ),
              const Divider(height: 1),
              if (columnId == 1)
                Expanded(child: _buildSourceColumnContent(context, isMultiSelectModeActive))
              else
                _buildWorkflowColumnContent(context, isMultiSelectModeActive),
            ],
          ),
        );
      },
    );
  }

  // MODIFIED: Truyền isMultiSelectModeActive vào
  Widget _buildSourceColumnContent(BuildContext context, bool isMultiSelectModeActive) {
    // ... logic sắp xếp và lọc không đổi
    final sortedItems = List<Item>.from(items);
    sortedItems.sort((a, b) {
      if (a.isUsed && !b.isUsed) return 1;
      if (!a.isUsed && b.isUsed) return -1;
      return a.originalId.compareTo(b.originalId);
    });
    final visibleItems = sortedItems
        .where(
          (item) =>
              item.itemLevel >= displayLevelStart &&
              item.itemLevel <= displayLevelStart + 1,
        )
        .toList();
    final visibleItemsById = {for (var item in visibleItems) item.id: item};
    final List<Item> rootItemsToRender = [];
    for (final item in visibleItems) {
      if (item.itemLevel == displayLevelStart ||
          (item.parentId == null ||
              !visibleItemsById.containsKey(item.parentId))) {
        rootItemsToRender.add(item);
      }
    }

    return ListView.builder(
      controller: scrollController,
      itemCount: rootItemsToRender.length,
      itemBuilder: (context, index) {
        final rootItem = rootItemsToRender[index];
        if (rootItem.itemLevel == displayLevelStart) {
          final childrenInView =
              visibleItems.where((child) => child.parentId == rootItem.id).toList();

          if (childrenInView.isEmpty) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              // MODIFIED: Truyền isMultiSelectModeActive
              child: _buildSourceItemTile(
                context,
                rootItem,
                role: DragRole.parent,
                isMultiSelectModeActive: isMultiSelectModeActive,
              ),
            );
          }

          return ExpansionTile(
            key: PageStorageKey(rootItem.id),
            tilePadding: EdgeInsets.zero,
            // MODIFIED: Truyền isMultiSelectModeActive
            title: _buildSourceItemTile(
              context,
              rootItem,
              role: DragRole.parent,
              isMultiSelectModeActive: isMultiSelectModeActive,
            ),
            initiallyExpanded: false,
            childrenPadding: const EdgeInsets.only(left: 16),
            children: childrenInView.map((childItem) {
              // MODIFIED: Truyền isMultiSelectModeActive
              return _buildSourceItemTile(
                context,
                childItem,
                role: DragRole.child,
                isMultiSelectModeActive: isMultiSelectModeActive,
              );
            }).toList(),
          );
        } else {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            // MODIFIED: Truyền isMultiSelectModeActive
            child: _buildSourceItemTile(
              context,
              rootItem,
              role: DragRole.child,
              isMultiSelectModeActive: isMultiSelectModeActive,
            ),
          );
        }
      },
    );
  }

  // MODIFIED: Truyền isMultiSelectModeActive vào
  Widget _buildWorkflowColumnContent(BuildContext context, bool isMultiSelectModeActive) {
    if (items.isEmpty) {
      return const Center(
        child: Text('Kéo item vào đây', style: TextStyle(color: Colors.grey)),
      );
    }
    // ... logic nhóm không đổi
    final masterItems = context.read<DragDropBloc>().state.masterItems;
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
    final groupedChildren = groupBy<Item, String>(
      childrenItems,
      (item) => item.potentialParentOriginalId!,
    );
    List<Widget> widgetsToRender = [];

    // MODIFIED: Truyền isMultiSelectModeActive cho từng WorkflowItemWidget
    widgetsToRender.addAll(
      orphanItems.map(
        (item) => WorkflowItemWidget(
          key: ValueKey(item.id),
          item: item,
          itemKey: itemKeys[item.id]!,
          isMultiSelectModeActive: isMultiSelectModeActive,
        ),
      ),
    );
    widgetsToRender.addAll(
      placeholders.map((item) {
        final isComplete = context.read<DragDropBloc>().isGroupComplete(
              item,
              masterItems,
            );
        return WorkflowItemWidget(
          key: ValueKey(item.id),
          item: item,
          itemKey: itemKeys[item.id]!,
          isComplete: isComplete,
          isMultiSelectModeActive: isMultiSelectModeActive,
        );
      }),
    );
    groupedChildren.forEach((parentId, children) {
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
            isMultiSelectModeActive: isMultiSelectModeActive, // NEW
          ),
        );
      }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgetsToRender,
    );
  }
}