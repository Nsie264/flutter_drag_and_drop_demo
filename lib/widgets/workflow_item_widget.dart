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
        final canAccept = item.columnId > draggedItem.columnId &&
            item.originalId != draggedItem.originalId &&
            item.potentialParentOriginalId == draggedItem.potentialParentOriginalId;
        
        final canDropOnPlaceholder = item.isGroupPlaceholder &&
            item.originalId == draggedItem.potentialParentOriginalId;

        return canAccept || canDropOnPlaceholder;
      },
      onAcceptWithDetails: (details) {
        context.read<DragDropBloc>().add(
          MergeItemsRequested(
            draggedItem: details.data,
            targetItem: item,
          ),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isTargetForMerge = candidateData.isNotEmpty;
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
          childWhenDragging: Opacity(opacity: 0.5, child: _buildBox(context, key: itemKey)),
          onDragStarted: () => context.read<DragCubit>().startDragging(),
          onDragEnd: (_) => context.read<DragCubit>().endDragging(),
          onDraggableCanceled: (_, __) => context.read<DragCubit>().endDragging(),
          child: _buildBox(
            context,
            isTargetForMerge: isTargetForMerge,
            key: itemKey,
          ),
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

  // === SỬA ĐỔI _buildRegularItemBox ===
  Widget _buildRegularItemBox(BuildContext context, Key? key, bool isDragging, bool isTargetForMerge) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      decoration: BoxDecoration(
        color: isTargetForMerge ? Colors.lightBlue.shade50 : Colors.blue.shade100,
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(
          color: isTargetForMerge ? Colors.blue.shade400 : Colors.blue.shade200,
          width: isTargetForMerge ? 2 : 1,
        ),
        boxShadow: isDragging ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : [],
      ),
      // Dùng Stack để có thể đặt nút xóa đè lên
      child: Stack(
        clipBehavior: Clip.none, // Cho phép IconButton tràn ra ngoài
        alignment: Alignment.center,
        children: [
          // Nội dung item
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0), // Thêm padding để không bị che
                  child: Text(item.name, overflow: TextOverflow.ellipsis),
                )
              ),
              Text(
                'Cấp ${item.itemLevel}',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          // Nút xóa
          Positioned(
            top: -14,
            right: -14,
            child: IconButton(
              icon: Icon(Icons.close_rounded, size: 18, color: Colors.red.shade400),
              onPressed: () {
                context.read<DragDropBloc>().add(RemoveWorkflowItem(itemToRemove: item));
              },
              splashRadius: 18,
              tooltip: 'Xóa item',
            ),
          ),
        ],
      ),
    );
  }

  // === SỬA ĐỔI _buildPlaceholderBox ===
  Widget _buildPlaceholderBox(BuildContext context, Key? key, bool isDragging, bool isTargetForMerge) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isTargetForMerge ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          color: isComplete ? 
                 (isTargetForMerge ? Colors.green : Colors.grey.shade400) : 
                 (isTargetForMerge ? Colors.orange.shade700 : Colors.orange.shade400),
          width: isComplete ? 1 : 2,
        ),
         boxShadow: isDragging ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ] : [],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Nội dung placeholder
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 20), // Tạo không gian cho nút xóa
                child: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Đã liên kết: ${item.linkedChildrenOriginalIds.length} mục',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              )
            ],
          ),
          // Nút xóa
          Positioned(
            top: -24,
            right: -24,
            child: IconButton(
              icon: Icon(Icons.close_rounded, size: 20, color: Colors.red.shade400),
              onPressed: () {
                context.read<DragDropBloc>().add(RemoveWorkflowItem(itemToRemove: item));
              },
              splashRadius: 20,
              tooltip: 'Xóa nhóm',
            ),
          ),
        ],
      ),
    );
  }
}