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
    return DragTarget<Item>(
      onWillAcceptWithDetails: (details) {
        final draggedItem = details.data;
        final canAccept =
            item.columnId > draggedItem.columnId &&
            item.originalId != draggedItem.originalId &&
            item.potentialParentOriginalId ==
                draggedItem.potentialParentOriginalId;

        final canDropOnPlaceholder =
            item.isGroupPlaceholder &&
            item.originalId == draggedItem.potentialParentOriginalId;

        return (canAccept || canDropOnPlaceholder) && draggedItem.columnId > 1;
      },
      onAcceptWithDetails: (details) {
        context.read<DragDropBloc>().add(
          MergeItemsRequested(draggedItem: details.data, targetItem: item),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isTargetForMerge = candidateData.isNotEmpty;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // === DRAGGABLE PHẦN ITEM ===
            Draggable<Item>(
              data: item,
              feedback: Material(
                color: Colors.transparent,
                child: Theme(
                  data: Theme.of(context),
                  child: SizedBox(
                    width: columnWidth - 16, // chỉ giới hạn feedback
                    child: _buildBox(context, isDragging: true),
                  ),
                ),
              ),
              childWhenDragging: Opacity(
                opacity: 0.5,
                child: SizedBox(
                  width: columnWidth - 16,
                  child: _buildBox(context, key: itemKey),
                ),
              ),
              onDragStarted: () => context.read<DragCubit>().startDragging(),
              onDragEnd: (_) => context.read<DragCubit>().endDragging(),
              onDraggableCanceled: (_, __) =>
                  context.read<DragCubit>().endDragging(),
              child: SizedBox(
                width: columnWidth - 16,
                child: _buildBox(
                  context,
                  isTargetForMerge: isTargetForMerge,
                  key: itemKey,
                ),
              ),
            ),

            // === NÚT XOÁ ĐẶT NGOÀI DRAGGABLE ===
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
  }

  Widget _buildBox(
    BuildContext context, {
    Key? key,
    bool isDragging = false,
    bool isTargetForMerge = false,
  }) {
    if (item.isGroupPlaceholder) {
      return _buildPlaceholderBox(context, key, isDragging, isTargetForMerge);
    } else {
      return _buildRegularItemBox(context, key, isDragging, isTargetForMerge);
    }
  }

  // === ITEM THƯỜNG ===
  Widget _buildRegularItemBox(
    BuildContext context,
    Key? key,
    bool isDragging,
    bool isTargetForMerge,
  ) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: isTargetForMerge
            ? Colors.lightBlue.shade50
            : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: isTargetForMerge ? Colors.blue.shade400 : Colors.blue.shade200,
          width: isTargetForMerge ? 2 : 1,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
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
              child: Text(item.name, overflow: TextOverflow.ellipsis),
            ),
          ),
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

  // === PLACEHOLDER GROUP ===
  Widget _buildPlaceholderBox(
    BuildContext context,
    Key? key,
    bool isDragging,
    bool isTargetForMerge,
  ) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isTargetForMerge ? Colors.green.shade50 : Colors.white,
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
                  color: Colors.black.withValues(alpha: 0.2),
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
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              item.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
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
