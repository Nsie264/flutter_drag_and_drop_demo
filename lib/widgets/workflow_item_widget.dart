// lib/widgets/workflow_item_widget.dart

import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/cubit/drag_cubit.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class WorkflowItemWidget extends StatelessWidget {
  final Item item;
  final GlobalKey itemKey;
  final bool isComplete; // Thêm cờ để nhận biết trạng thái hoàn chỉnh từ cha
  static const double columnWidth = 200.0;

  const WorkflowItemWidget({
    super.key,
    required this.item,
    required this.itemKey,
    this.isComplete = true, // Mặc định là hoàn chỉnh
  });

  @override
  Widget build(BuildContext context) {
    // Đây là DragTarget để nhận item khác thả vào (logic gộp nhóm mới)
    return DragTarget<Item>(
      onWillAcceptWithDetails: (details) {
        final draggedItem = details.data;
        // Logic chấp nhận mới:
        // 1. Phải kéo sang cột sau.
        // 2. Không được thả vào chính mình.
        // 3. Phải có cùng cha gốc (potentialParentOriginalId).
        final canAccept =
            item.columnId > draggedItem.columnId &&
            item.originalId != draggedItem.originalId &&
            item.potentialParentOriginalId ==
                draggedItem.potentialParentOriginalId;

        // Hoặc là thả một item con vào cha đại diện của nó
        final canDropOnPlaceholder =
            item.isGroupPlaceholder &&
            item.originalId == draggedItem.potentialParentOriginalId;

        return canAccept || canDropOnPlaceholder;
      },
      onAcceptWithDetails: (details) {
        // Gửi event mới để xử lý việc gộp nhóm
        context.read<DragDropBloc>().add(
          MergeItemsRequested(draggedItem: details.data, targetItem: item),
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
              // Bọc widget feedback trong một SizedBox có chiều rộng cố định
              child: SizedBox(
                width: columnWidth - 16, // Trừ đi padding của cột (8*2)
                child: _buildBox(context, isDragging: true),
              ),
            ),
          ),
          childWhenDragging: Opacity(
            opacity: 0.5,
            child: _buildBox(context, key: itemKey),
          ),
          onDragStarted: () => context.read<DragCubit>().startDragging(),
          onDragEnd: (_) => context.read<DragCubit>().endDragging(),
          onDraggableCanceled: (_, __) =>
              context.read<DragCubit>().endDragging(),
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
    // Logic hiển thị dựa trên loại item (placeholder hay item thường)
    if (item.isGroupPlaceholder) {
      return _buildPlaceholderBox(context, key, isDragging, isTargetForMerge);
    } else {
      return _buildRegularItemBox(context, key, isDragging, isTargetForMerge);
    }
  }

  // Widget cho item thường
  Widget _buildRegularItemBox(
    BuildContext context,
    Key? key,
    bool isDragging,
    bool isTargetForMerge,
  ) {
    return Container(
      key: key,
      height: 40,
      width: double.infinity,
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
          Expanded(child: Text(item.name, overflow: TextOverflow.ellipsis)),
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

  // Widget cho "Cha đại diện"
  Widget _buildPlaceholderBox(
    BuildContext context,
    Key? key,
    bool isDragging,
    bool isTargetForMerge,
  ) {
    return Container(
      key: key,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: isTargetForMerge ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(8.0),
        border: Border.all(
          // Viền cam nếu chưa hoàn chỉnh, ngược lại là viền xanh
          color: isComplete
              ? (isTargetForMerge ? Colors.green : Colors.grey.shade400)
              : (isTargetForMerge
                    ? Colors.orange.shade700
                    : Colors.orange.shade400),
          width: isComplete ? 1 : 2,
          style: isComplete ? BorderStyle.solid : BorderStyle.solid,
        ),
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.name,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
