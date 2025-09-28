import 'package:drag_and_drop/bloc/drag_drop_bloc.dart';
import 'package:drag_and_drop/cubit/drag_cubit.dart';
import 'package:drag_and_drop/models/item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class ChildItemWidget extends StatelessWidget {
  final Item item;
  final GlobalKey itemKey;

  const ChildItemWidget({
    super.key,
    required this.item,
    required this.itemKey,
  });

  @override
  Widget build(BuildContext context) {
    // Nếu item đã được sử dụng, hiển thị một widget tĩnh, không tương tác được.
    if (item.isUsed) {
      return _buildBox(context, key: itemKey, isDisabled: true);
    }

    // Nếu item chưa được sử dụng, render widget có đầy đủ chức năng Draggable và DragTarget.
    return DragTarget<Item>(
      onWillAcceptWithDetails: (details) {
        final draggedItem = details.data;
        // Chấp nhận khi:
        // 1. Kéo sang cột sau (áp dụng cho logic cũ nếu cần)
        // 2. Không phải là tự thả vào chính mình
        // 3. Cùng level (logic cũ)
        final canAccept =
            item.columnId > draggedItem.columnId &&
            item.id != draggedItem.id &&
            item.itemLevel == draggedItem.itemLevel;
        return canAccept;
      },
      onAcceptWithDetails: (details) {
        // Logic này của Cột Nguồn không dùng GroupItemsRequested nữa,
        // nhưng giữ lại có thể hữu ích nếu có logic khác.
        // Hiện tại, việc thả vào item con trong cột nguồn không có hiệu ứng.
        context.read<DragDropBloc>().add(
          GroupItemsRequested(draggedItem: details.data, targetItem: item),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isTargetForLink = candidateData.isNotEmpty;
        return Draggable<Item>(
          data: item,
          feedback: Material(
              color: Colors.transparent,
              child: Theme(
                  data: Theme.of(context),
                  child: _buildBox(context, isDragging: true))),
          childWhenDragging:
              Opacity(opacity: 0.5, child: _buildBox(context, key: itemKey)),
          onDragStarted: () => context.read<DragCubit>().startDragging(),
          onDragEnd: (_) => context.read<DragCubit>().endDragging(),
          onDraggableCanceled: (_, __) =>
              context.read<DragCubit>().endDragging(),
          child: _buildBox(
            context,
            isTargetForLink: isTargetForLink,
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
    bool isTargetForLink = false,
    bool isDisabled = false, // Thêm cờ để xác định trạng thái vô hiệu hóa
  }) {
    return Container(
      key: key,
      height: 30,
      width: 120, // Giữ lại width cố định cho item con trong Cột Nguồn
      margin: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        // Thay đổi màu nền dựa trên trạng thái isDisabled
        color: isDisabled
            ? Colors.grey.shade300
            : (isTargetForLink
                ? Colors.green.shade100
                : Colors.blue.shade100),
        borderRadius: BorderRadius.circular(4.0),
        border: isTargetForLink
            ? Border.all(color: Colors.green, width: 2)
            : null,
        boxShadow: isDragging
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 5,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          item.name,
          style: TextStyle(
            // Thay đổi màu chữ dựa trên trạng thái isDisabled
            color: isDisabled ? Colors.grey.shade600 : Colors.black,
            // Thêm hiệu ứng gạch ngang để rõ ràng hơn
            decoration:
                isDisabled ? TextDecoration.lineThrough : TextDecoration.none,
          ),
        ),
      ),
    );
  }
}