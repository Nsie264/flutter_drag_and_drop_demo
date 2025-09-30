import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/cubit/drag_cubit.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WorkflowItemWidget extends StatelessWidget {
  final Item item;
  final GlobalKey itemKey;
  final bool isComplete;

  static const double columnWidth = 200.0;

  const WorkflowItemWidget({
    super.key,
    required this.item,
    required this.itemKey,
    this.isComplete = true,
  });

  @override
  Widget build(BuildContext context) {
    // Xác định xem item có thể kéo được không
    final bool isDraggable = item.nextItemId == null;

    // Widget nội dung chính, được bao bọc bởi DragTarget
    Widget mainContent = DragTarget<Item>(
      // =================================================================
      // === SỬ DỤNG LOGIC onWillAcceptWithDetails CHÍNH XÁC CỦA BẠN ===
      // =================================================================
      onWillAcceptWithDetails: (details) {
        final draggedItem = details.data;
        final targetItem = item;

        // Chặn các hành động không hợp lệ ngay từ đầu
        if (draggedItem.columnId <= 1 ||
            targetItem.columnId <= draggedItem.columnId) {
          return false;
        }

        // Xác định parent originalId của item/group đang được kéo
        final draggedParentOriginalId = draggedItem.potentialParentOriginalId;
        if (draggedParentOriginalId == null) return false;

        // Kịch bản 1: Thả vào "anh em"
        final bool canAcceptSibling =
            !targetItem.isGroupPlaceholder &&
            targetItem.originalId != draggedItem.originalId &&
            targetItem.potentialParentOriginalId == draggedParentOriginalId;

        // Kịch bản 2: Thả vào CHA ĐẠI DIỆN (placeholder)
        final bool canDropOnParentPlaceholder =
            targetItem.isGroupPlaceholder &&
            targetItem.originalId == draggedParentOriginalId;

        // Kịch bản 3: Thả vào CHA (dạng thường) để nâng cấp
        final bool canUpgradeToPlaceholder =
            !targetItem.isGroupPlaceholder &&
            targetItem.originalId == draggedParentOriginalId;

        return canAcceptSibling ||
            canDropOnParentPlaceholder ||
            canUpgradeToPlaceholder;
      },

      onAcceptWithDetails: (details) {
        final draggedItem = details.data;
        final targetItem = item;

        // PHÂN LUỒNG LOGIC TẠI ĐÂY
        if (draggedItem.dragMode == DragMode.group) {
          // Gửi event gộp nhóm
          context.read<DragDropBloc>().add(
            MergeGroupRequested(
              representativeItem: draggedItem,
              targetItem: targetItem,
            ),
          );
        } else {
          // Logic cũ cho item đơn
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
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isTargetForMerge = candidateData.isNotEmpty;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox( 
              width: columnWidth - 16,
              child: _buildBox(
                context,
                isTargetForMerge: isTargetForMerge,
                key: itemKey,
                isLinked: !isDraggable, 
              ),
            ),
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
                tooltip: item.isGroupPlaceholder ? 'Xóa nhóm' : 'Xóa item',
              ),
            ),
          ],
        );
      },
    );

    // Chỉ bọc bằng Draggable nếu isDraggable là true 
    if (isDraggable) {
      return Draggable<Item>(
        data: item,
        feedback: Material(
          color: Colors.transparent,
          child: Theme(
            data: Theme.of(context),
            child: SizedBox(
              width: columnWidth - 16,
              child: _buildBox(context, isDragging: true),
            ),
          ),
        ),
        childWhenDragging: Opacity(
          opacity: 0.5,
          child: mainContent, // Hiển thị nội dung chính khi đang kéo
        ),
        onDragStarted: () => context.read<DragCubit>().startDragging(),
        onDragEnd: (_) => context.read<DragCubit>().endDragging(),
        onDraggableCanceled: (_, __) => context.read<DragCubit>().endDragging(),
        child: mainContent, // Nội dung hiển thị bình thường
      );
    } else {
      // Nếu không thể kéo, chỉ trả về nội dung chính (vẫn có DragTarget)
      return mainContent;
    }
  }
  
  Widget _buildBox(
    BuildContext context, {
    Key? key,
    bool isDragging = false,
    bool isTargetForMerge = false,
    bool isLinked = false, 
  }) {
    if (item.isGroupPlaceholder) {
      return _buildPlaceholderBox(context, key, isDragging, isTargetForMerge, isLinked);
    } else {
      return _buildRegularItemBox(context, key, isDragging, isTargetForMerge, isLinked);
    }
  }

  Widget _buildRegularItemBox(
    BuildContext context,
    Key? key,
    bool isDragging,
    bool isTargetForMerge,
    bool isLinked,
  ) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: isLinked 
            ? Colors.blue.shade50 
            : (isTargetForMerge ? Colors.lightBlue.shade50 : Colors.blue.shade100),
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: isTargetForMerge ? Colors.blue.shade400 : Colors.blue.shade200,
          width: isTargetForMerge ? 2 : 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha:  0.2),
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

  Widget _buildPlaceholderBox(
    BuildContext context,
    Key? key,
    bool isDragging,
    bool isTargetForMerge,
    bool isLinked,
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
          color: isComplete
              ? (isTargetForMerge ? Colors.green : Colors.grey.shade400)
              : (isTargetForMerge
                    ? Colors.orange.shade700
                    : Colors.orange.shade400),
          width: isComplete ? 1 : 2,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha:  0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
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
                      decoration: isLinked ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                  ),
                ),
              ),
              if(isLinked)
                const Icon(Icons.link, size: 18, color: Colors.black54),
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