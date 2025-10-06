// lib/widgets/workflow_item_widget.dart

import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/cubit/drag_cubit.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WorkflowItemWidget extends StatelessWidget {
  final Item item;
  final GlobalKey itemKey;
  final bool isComplete;
  final bool isMultiSelectModeActive; // NEW: Nhận biết chế độ từ parent

  static const double columnWidth = 200.0;

  const WorkflowItemWidget({
    super.key,
    required this.item,
    required this.itemKey,
    this.isComplete = true,
    required this.isMultiSelectModeActive, // NEW
  });

  @override
  Widget build(BuildContext context) {
    final bool isDraggable = item.nextItemId == null;
    final highlightedItemIds = context
        .watch<DragDropBloc>()
        .state
        .highlightedItemIds;
    final bool isHighlighted = highlightedItemIds.contains(item.id);

    // NEW: Lấy state để biết item có được chọn hay không
    final multiSelectState = context.watch<DragDropBloc>().state;
    final isSelected = multiSelectState.selectedItemIds.contains(item.id);

    // Widget nội dung chính, được bao bọc bởi DragTarget
    Widget mainContent = DragTarget<Item>(
      onWillAcceptWithDetails: (details) {
        // ... logic onWillAccept giữ nguyên ...
        final draggedItem = details.data;
        // NEW: Thêm logic cho multiSelect
        if (draggedItem.dragMode == DragMode.multiSelect) {
          // Chỉ chấp nhận nếu thả vào cột khác và là nhóm đồng nhất
          final selectedIds = context
              .read<DragDropBloc>()
              .state
              .selectedItemIds;
          if (selectedIds.contains(item.id))
            return false; // Không thể thả vào chính nó

          // Logic kiểm tra đồng nhất có thể được thực hiện trong BLoC, ở đây chỉ cần kiểm tra cơ bản
          return item.columnId > draggedItem.columnId;
        }

        final targetItem = item;
        if (draggedItem.columnId <= 1 ||
            targetItem.columnId <= draggedItem.columnId)
          return false;
        final draggedParentOriginalId = draggedItem.potentialParentOriginalId;
        if (draggedParentOriginalId == null) return false;
        final bool canAcceptSibling =
            !targetItem.isGroupPlaceholder &&
            targetItem.originalId != draggedItem.originalId &&
            targetItem.potentialParentOriginalId == draggedParentOriginalId;
        final bool canDropOnParentPlaceholder =
            targetItem.isGroupPlaceholder &&
            targetItem.originalId == draggedParentOriginalId;
        final bool canUpgradeToPlaceholder =
            !targetItem.isGroupPlaceholder &&
            targetItem.originalId == draggedParentOriginalId;
        return canAcceptSibling ||
            canDropOnParentPlaceholder ||
            canUpgradeToPlaceholder;
      },
      onAcceptWithDetails: (details) {
        final draggedItem = details.data;

        // MODIFIED: Phân luồng logic dựa trên dragMode
        switch (draggedItem.dragMode) {
          case DragMode.multiSelect:
            context.read<DragDropBloc>().add(
              MultiSelectionDropped(
                representativeItem: draggedItem,
                targetColumnId: item.columnId,
                targetItem: item, // Thả vào item này
              ),
            );
            break;
          case DragMode.group:
            context.read<DragDropBloc>().add(
              MergeGroupRequested(
                representativeItem: draggedItem,
                targetItem: item,
              ),
            );
            break;
          case DragMode.single:
          default:
            final targetItem = item;
            final bool isUpgradeRequest =
                !targetItem.isGroupPlaceholder &&
                targetItem.originalId == draggedItem.potentialParentOriginalId;
            if (isUpgradeRequest) {
              context.read<DragDropBloc>().add(
                UpgradeToPlaceholderRequested(
                  childItem: draggedItem,
                  parentTargetItem: targetItem,
                ),
              );
            } else {
              context.read<DragDropBloc>().add(
                MergeItemsRequested(
                  draggedItem: draggedItem,
                  targetItem: targetItem,
                ),
              );
            }
            break;
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isTargetForMerge = candidateData.isNotEmpty;

        // NEW: Widget item box
        Widget itemBox = _buildBox(
          context,
          isTargetForMerge: isTargetForMerge,
          key: itemKey,
          isLinked: !isDraggable,
          isSelected: isSelected,
          isHighlighted: isHighlighted,
        );

        // NEW: Bọc trong Row để thêm Checkbox
        Widget itemWithCheckbox = (isMultiSelectModeActive && isDraggable)
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (bool? value) {
                      if (value != null) {
                        context.read<DragDropBloc>().add(
                          ItemSelectionChanged(
                            itemId: item.id,
                            isSelected: value,
                          ),
                        );
                      }
                    },
                  ),
                  Expanded(child: itemBox),
                ],
              )
            : itemBox; // Nếu không thì hiển thị box như cũ

        return Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(width: columnWidth - 16, child: itemWithCheckbox),
            Positioned(
              top: item.isGroupPlaceholder ? -6 : -8,
              right: item.isGroupPlaceholder ? -10 : -12,
              child: IconButton(
                icon: Icon(
                  Icons.close_rounded,
                  size: item.isGroupPlaceholder ? 20 : 18,
                  color: Colors.red.shade300,
                ),
                onPressed: () {
                  context.read<DragDropBloc>().add(
                    RemoveWorkflowItem(itemToRemove: item),
                  );
                },
                splashRadius: item.isGroupPlaceholder ? 10 : 5,
                tooltip: item.isGroupPlaceholder ? 'Xóa tổ' : 'Xóa chi tiết',
              ),
            ),
          ],
        );
      },
    );

    Widget interactiveWrapper = GestureDetector(
      onDoubleTap:
          (item.columnId > 1) // Chỉ cho phép double click ở cột workflow
          ? () {
              context.read<DragDropBloc>().add(
                HighlightChainRequested(itemId: item.id),
              );
            }
          : null,
      child: isDraggable
          ? Draggable<Item>(
              data: (isMultiSelectModeActive && isSelected)
                  ? item.copyWith(dragMode: DragMode.multiSelect)
                  : item,
              feedback: (isMultiSelectModeActive && isSelected)
                  ? Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade200,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(2, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '${multiSelectState.selectedItemIds.length} items',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: Theme(
                        data: Theme.of(context),
                        child: SizedBox(
                          width: columnWidth - 16,
                          child: _buildBox(
                            context,
                            isDragging: true,
                            isSelected: false,
                            isHighlighted: false,
                          ),
                        ),
                      ),
                    ),
              childWhenDragging: Opacity(opacity: 0.5, child: mainContent),
              onDragStarted: () => context.read<DragCubit>().startDragging(),
              onDragEnd: (_) => context.read<DragCubit>().endDragging(),
              onDraggableCanceled: (_, __) =>
                  context.read<DragCubit>().endDragging(),
              child: mainContent,
            )
          : mainContent,
    );

    return interactiveWrapper;
  }

  // MODIFIED: Thêm tham số isSelected
  Widget _buildBox(
    BuildContext context, {
    Key? key,
    bool isDragging = false,
    bool isTargetForMerge = false,
    bool isLinked = false,
    required bool isSelected,
    bool isHighlighted = false,
  }) {
    if (item.isGroupPlaceholder) {
      return _buildPlaceholderBox(
        context,
        key,
        isDragging,
        isTargetForMerge,
        isLinked,
        isSelected,
        isHighlighted,
      );
    } else {
      return _buildRegularItemBox(
        context,
        key,
        isDragging,
        isTargetForMerge,
        isLinked,
        isSelected,
        isHighlighted,
      );
    }
  }

  // MODIFIED: Thêm tham số isSelected và áp dụng style
  Widget _buildRegularItemBox(
    BuildContext context,
    Key? key,
    bool isDragging,
    bool isTargetForMerge,
    bool isLinked,
    bool isSelected,
    bool isHighlighted,
  ) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: isLinked
            ? Colors.blue.shade50
            : (isTargetForMerge
                  ? Colors.lightBlue.shade50
                  : Colors.blue.shade100),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          // NEW: Thay đổi border khi được chọn
          color: isSelected
              ? Colors.blue.shade700
              : (isTargetForMerge
                    ? Colors.blue.shade400
                    : Colors.blue.shade200),
          width: isSelected ? 2 : (isTargetForMerge ? 2 : 1),
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10.0),
              child: Text(
                item.name,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isLinked ? Colors.black54 : Colors.black,
                ),
              ),
            ),
          ),
          if (!isLinked)
            Text(
              'Cấp ${item.itemLevel}',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade700,
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  // MODIFIED: Thêm tham số isSelected và áp dụng style
  Widget _buildPlaceholderBox(
    BuildContext context,
    Key? key,
    bool isDragging,
    bool isTargetForMerge,
    bool isLinked,
    bool isSelected,
    bool isHighlighted,
  ) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isLinked
            ? Colors.grey.shade200
            : (isTargetForMerge ? Colors.green.shade50 : Colors.white),
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          // NEW: Thay đổi border khi được chọn
          color: isSelected
              ? Colors.blue.shade700
              : (isComplete
                    ? (isTargetForMerge ? Colors.green : Colors.grey.shade400)
                    : (isTargetForMerge
                          ? Colors.orange.shade700
                          : Colors.orange.shade400)),
          width: isSelected ? 2 : (isComplete ? 1 : 2),
        ),
        boxShadow: isHighlighted
            ? [
                BoxShadow(
                  color: Colors.red.withOpacity(0.5),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ]
            : (isDragging
                  ? [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : []),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 20),
                  child: Text(
                    item.name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isLinked ? Colors.black54 : Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Đã liên kết: ${item.linkedChildrenOriginalIds.length} mục',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
